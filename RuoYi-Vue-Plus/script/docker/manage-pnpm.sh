#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKEND_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_DIR="$(cd -- "${BACKEND_DIR}/.." && pwd)"
readonly FRONTEND_DIR="${PROJECT_DIR}/plus-ui"
readonly COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
readonly DATA_DIR="${SCRIPT_DIR}/docker-data"
readonly BACKUP_DIR="${SCRIPT_DIR}/backups"
readonly REQUIRED_IMAGES=(
    "bellsoft/liberica-openjdk-rocky:17.0.16-cds"
    "mysql:8.0.42"
    "redis:7.2.8"
    "pgsty/minio:RELEASE.2026-02-14T12-00-00Z"
    "nginx:1.23.4"
)

log() {
    printf '\n\033[1;32m==> %s\033[0m\n' "$*"
}

warn() {
    printf '\033[1;33mWarning: %s\033[0m\n' "$*" >&2
}

die() {
    printf '\033[1;31mError: %s\033[0m\n' "$*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    printf '\033[1;31mError: command failed at line %s (exit code %s).\033[0m\n' "${BASH_LINENO[0]}" "${exit_code}" >&2
    exit "${exit_code}"
}
trap on_error ERR

usage() {
    cat <<'EOF'
Usage: ./manage.sh <command>

Commands:
  start   Incrementally build the frontend/backend images and start all services
  stop    Stop and remove project containers while preserving docker-data
  status  Show container status and service URLs
  dev-start    Start MySQL, Redis, and MinIO for local development
  dev-stop     Stop development infrastructure while preserving containers/data
  dev-restart  Restart MySQL, Redis, and MinIO and wait until healthy
  dev-status   Show MySQL, Redis, and MinIO container status
  clean   Remove build artifacts/dependencies, rebuild everything, and start
  backup  Back up MySQL as SQL and all docker-data as a tar.gz archive
  restore-db <file>    Restore MySQL from a backup .sql.gz file
  restore-data <file>  Restore all persistent data from a backup .tar.gz file
  clean-cache          Stop services and remove project build caches and logs
  clean-all [--yes]    Stop services and remove caches plus all persistent data
  help    Show this help
EOF
}

load_node() {
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        return
    fi

    export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
    if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
        # shellcheck source=/dev/null
        source "${NVM_DIR}/nvm.sh"
        nvm use default --silent >/dev/null 2>&1 || nvm use node --silent >/dev/null 2>&1 || true
    fi

    command -v node >/dev/null 2>&1 || die "Node.js was not found. Install Node >= 20.19 in WSL or configure nvm's default alias."
    command -v npm >/dev/null 2>&1 || die "npm was not found in WSL."
    command -v pnpm >/dev/null 2>&1 || die "pnpm was not found in WSL. Install it with: npm install -g pnpm."
    node -e 'const [major, minor] = process.versions.node.split(".").map(Number); if (major < 20 || (major === 20 && minor < 19)) process.exit(1)' \
        || die "Node.js >= 20.19 is required; found $(node --version)."
}

check_docker() {
    command -v docker >/dev/null 2>&1 || die "Docker was not found in WSL. Enable Docker Desktop > Settings > Resources > WSL Integration for this distribution."
    docker info >/dev/null 2>&1 || die "Docker is not reachable from WSL. Start Docker Desktop and enable WSL Integration for this distribution."
    docker compose version >/dev/null 2>&1 || die "Docker Compose v2 ('docker compose') is required."
}

check_build_tools() {
    load_node
    command -v mvn >/dev/null 2>&1 || die "Maven was not found in WSL."
    command -v java >/dev/null 2>&1 || die "Java was not found in WSL."
    [[ "$(java -version 2>&1 | head -n 1)" == *'17.'* ]] || die "Java 17 is required."
    check_docker
}

ensure_runtime_dirs() {
    mkdir -p \
        "${SCRIPT_DIR}/docker-data/mysql/data" \
        "${SCRIPT_DIR}/docker-data/mysql/conf" \
        "${SCRIPT_DIR}/docker-data/redis/data" \
        "${SCRIPT_DIR}/docker-data/minio/data" \
        "${SCRIPT_DIR}/docker-data/minio/config" \
        "${SCRIPT_DIR}/docker-data/nginx/cert" \
        "${SCRIPT_DIR}/docker-data/nginx/log" \
        "${SCRIPT_DIR}/docker-data/server1/logs" \
        "${SCRIPT_DIR}/docker-data/server2/logs" \
        "${SCRIPT_DIR}/docker-data/monitor/logs" \
        "${SCRIPT_DIR}/docker-data/snailjob/logs"

    # The official Redis image runs as a non-root UID. A bind-mounted WSL
    # directory created by the host user is otherwise not writable by Redis.
    chmod 0777 "${SCRIPT_DIR}/docker-data/redis/data"
}

ensure_required_images() {
    log "Ensuring all required base images are available locally"
    local image attempt
    for image in "${REQUIRED_IMAGES[@]}"; do
        if docker image inspect "${image}" >/dev/null 2>&1; then
            printf 'Using cached image: %s\n' "${image}"
            continue
        fi

        printf '\nPulling %s\n' "${image}"
        for attempt in 1 2 3; do
            if docker pull "${image}"; then
                break
            fi
            if (( attempt == 3 )); then
                die "Failed to pull required image after 3 attempts: ${image}"
            fi
            warn "Pull attempt ${attempt}/3 failed for ${image}; retrying in $((attempt * 3)) seconds."
            sleep $((attempt * 3))
        done
    done
}

build_frontend() {
    log "Installing frontend dependencies and building production assets"
    (
        cd "${FRONTEND_DIR}"
        pnpm install
        pnpm run build:prod
    )
    [[ -f "${FRONTEND_DIR}/dist/index.html" ]] || die "Frontend build did not produce dist/index.html."
}

build_backend() {
    log "Building backend JARs with the prod Maven profile"
    (cd "${BACKEND_DIR}" && mvn package -Pprod -DskipTests)

    local jars=(
        "${BACKEND_DIR}/ruoyi-admin/target/ruoyi-admin.jar"
        "${BACKEND_DIR}/ruoyi-extend/ruoyi-monitor-admin/target/ruoyi-monitor-admin.jar"
        "${BACKEND_DIR}/ruoyi-extend/ruoyi-snailjob-server/target/ruoyi-snailjob-server.jar"
    )
    local jar
    for jar in "${jars[@]}"; do
        [[ -f "${jar}" ]] || die "Expected build artifact was not created: ${jar}"
    done
}

build_images() {
    log "Building backend Docker images"
    docker build --pull=false -t ruoyi/ruoyi-server:5.6.2 "${BACKEND_DIR}/ruoyi-admin"
    docker build --pull=false -t ruoyi/ruoyi-monitor-admin:5.6.2 "${BACKEND_DIR}/ruoyi-extend/ruoyi-monitor-admin"
    docker build --pull=false -t ruoyi/ruoyi-snailjob-server:5.6.2 "${BACKEND_DIR}/ruoyi-extend/ruoyi-snailjob-server"
}

start_services() {
    log "Starting infrastructure containers"
    ensure_runtime_dirs
    docker compose -f "${COMPOSE_FILE}" up -d --wait --wait-timeout 240 mysql redis minio

    log "Migrating container service addresses in existing database defaults"
    docker exec mysql mysql -uroot -proot ry-vue -e \
        "UPDATE sys_oss_config SET endpoint='minio:9000', domain=IF(domain='', 'localhost:9000', domain) WHERE endpoint IN ('127.0.0.1:9000', 'minio:9000') AND config_key IN ('minio', 'image');"

    log "Starting all application containers"
    docker compose -f "${COMPOSE_FILE}" up -d --wait --wait-timeout 240
    show_status
}

show_status() {
    docker compose -f "${COMPOSE_FILE}" ps
    cat <<'EOF'

Service URLs:
  Frontend:    http://localhost/
  Backend:     http://localhost/prod-api/
  Monitor:     http://localhost/admin/
  SnailJob:    http://localhost/snail-job/
  MinIO:       http://localhost:9001/
EOF
}

dev_start() {
    check_docker
    ensure_runtime_dirs
    log "Starting development infrastructure (MySQL, Redis, and MinIO)"
    docker compose -f "${COMPOSE_FILE}" up -d --wait --wait-timeout 240 mysql redis minio
    dev_status
}

dev_stop() {
    check_docker
    log "Stopping development infrastructure (containers and persistent data are preserved)"
    docker compose -f "${COMPOSE_FILE}" stop mysql redis minio
    dev_status
}

dev_restart() {
    check_docker
    ensure_runtime_dirs
    log "Restarting development infrastructure"
    docker compose -f "${COMPOSE_FILE}" stop mysql redis minio
    docker compose -f "${COMPOSE_FILE}" up -d --wait --wait-timeout 240 mysql redis minio
    dev_status
}

dev_status() {
    check_docker
    docker compose -f "${COMPOSE_FILE}" ps -a mysql redis minio
}

clean_build_artifacts() {
    log "Cleaning frontend dependencies and build outputs"
    [[ "${FRONTEND_DIR}" == "${PROJECT_DIR}/plus-ui" ]] || die "Refusing to clean an unexpected frontend path."
    rm -rf -- "${FRONTEND_DIR}/node_modules" "${FRONTEND_DIR}/dist"

    log "Cleaning Maven build outputs"
    (cd "${BACKEND_DIR}" && mvn clean -Pprod -DskipTests)
}

running_services() {
    docker compose -f "${COMPOSE_FILE}" ps --services --filter status=running
}

restore_running_services() {
    local service
    local -a services=()
    for service in "$@"; do
        [[ -n "${service}" ]] && services+=("${service}")
    done
    if (( ${#services[@]} > 0 )); then
        log "Restoring services that were running before the operation"
        docker compose -f "${COMPOSE_FILE}" up -d --wait --wait-timeout 240 "${services[@]}"
    fi
}

backup_data() {
    check_docker
    command -v gzip >/dev/null 2>&1 || die "gzip is required in WSL."

    local timestamp backup_set sql_file archive_file
    local -a services=()
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_set="${BACKUP_DIR}/${timestamp}"
    sql_file="${backup_set}/mysql-full.sql.gz"
    archive_file="${backup_set}/docker-data.tar.gz"
    mkdir -p "${backup_set}"
    mapfile -t services < <(running_services)

    log "Starting MySQL when necessary and creating a portable full SQL backup"
    ensure_runtime_dirs
    docker compose -f "${COMPOSE_FILE}" up -d --wait --wait-timeout 240 mysql
    if ! docker exec mysql mysqldump \
        -uroot -proot \
        --databases ry-vue \
        --add-drop-database \
        --single-transaction \
        --routines --triggers --events \
        --hex-blob \
        --set-gtid-purged=OFF \
        --default-character-set=utf8mb4 | gzip -9 > "${sql_file}"; then
        rm -f -- "${sql_file}"
        restore_running_services "${services[@]}"
        die "MySQL logical backup failed."
    fi
    gzip -t "${sql_file}" || die "The generated SQL backup is invalid."

    log "Stopping containers for a consistent persistent-data archive"
    docker compose -f "${COMPOSE_FILE}" stop
    if ! docker run --rm --entrypoint sh \
        -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
        -v "${SCRIPT_DIR}:/workspace" mysql:8.0.42 -c \
        "tar -C /workspace -czf '/workspace/backups/${timestamp}/docker-data.tar.gz' docker-data && chown \"\${HOST_UID}:\${HOST_GID}\" '/workspace/backups/${timestamp}/docker-data.tar.gz'"; then
        restore_running_services "${services[@]}"
        die "Persistent-data archive failed."
    fi
    if ! tar -tzf "${archive_file}" >/dev/null; then
        restore_running_services "${services[@]}"
        die "The generated persistent-data archive is invalid."
    fi

    if ! {
        printf 'created_at=%s\n' "$(date --iso-8601=seconds)"
        printf 'mysql_image=mysql:8.0.42\n'
        sha256sum "${sql_file}" "${archive_file}"
    } > "${backup_set}/SHA256SUMS"; then
        restore_running_services "${services[@]}"
        die "Failed to write the backup manifest."
    fi

    restore_running_services "${services[@]}"
    log "Backup completed: ${backup_set}"
    printf '  MySQL:      %s\n  Docker data: %s\n' "${sql_file}" "${archive_file}"
}

resolve_backup_file() {
    local requested="${1:-}"
    [[ -n "${requested}" ]] || die "A backup file path is required."
    realpath -e -- "${requested}" 2>/dev/null || die "Backup file not found: ${requested}"
}

restore_database() {
    check_docker
    command -v gzip >/dev/null 2>&1 || die "gzip is required in WSL."
    local input
    local -a services=()
    input="$(resolve_backup_file "${1:-}")"
    [[ "${input}" == *.sql.gz ]] || die "restore-db requires a .sql.gz backup created by this script."
    gzip -t "${input}" || die "Invalid or damaged SQL backup: ${input}"
    mapfile -t services < <(running_services)

    log "Stopping application containers before restoring MySQL"
    docker compose -f "${COMPOSE_FILE}" stop
    ensure_runtime_dirs
    docker compose -f "${COMPOSE_FILE}" up -d --wait --wait-timeout 240 mysql redis
    if ! gzip -dc -- "${input}" | docker exec -i mysql mysql -uroot -proot --default-character-set=utf8mb4; then
        die "Database restore failed; application services remain stopped for inspection."
    fi
    docker exec redis redis-cli -a ruoyi123 FLUSHALL >/dev/null
    docker compose -f "${COMPOSE_FILE}" stop mysql redis
    restore_running_services "${services[@]}"
    log "MySQL restore completed. Redis cache was cleared."
}

validate_data_archive() {
    local archive="$1" entry
    while IFS= read -r entry; do
        [[ "${entry}" == docker-data || "${entry}" == docker-data/* ]] \
            || die "Unsafe archive entry outside docker-data: ${entry}"
        [[ "/${entry}/" != *'/../'* ]] || die "Unsafe parent path in archive: ${entry}"
    done < <(tar -tzf "${archive}")
}

restore_persistent_data() {
    check_docker
    local input relative
    local -a services=()
    input="$(resolve_backup_file "${1:-}")"
    [[ "${input}" == "${BACKUP_DIR}/"* && "${input}" == *.tar.gz ]] \
        || die "restore-data only accepts a .tar.gz file inside ${BACKUP_DIR}."
    tar -tzf "${input}" >/dev/null || die "Invalid or damaged data archive: ${input}"
    validate_data_archive "${input}"
    relative="${input#${SCRIPT_DIR}/}"
    mapfile -t services < <(running_services)

    log "Stopping and replacing all persistent container data"
    docker compose -f "${COMPOSE_FILE}" down
    docker run --rm --entrypoint sh -v "${SCRIPT_DIR}:/workspace" mysql:8.0.42 -c \
        "rm -rf /workspace/docker-data && tar -C /workspace -xzf '/workspace/${relative}'"
    restore_running_services "${services[@]}"
    log "Persistent-data restore completed."
}

remove_runtime_files() {
    log "Removing frontend dependencies, build outputs, Maven targets, and runtime logs"
    [[ "${FRONTEND_DIR}" == "${PROJECT_DIR}/plus-ui" ]] || die "Refusing to clean an unexpected frontend path."
    rm -rf -- "${FRONTEND_DIR}/node_modules" "${FRONTEND_DIR}/dist" \
        "${FRONTEND_DIR}/.vite" "${FRONTEND_DIR}/.eslintcache"
    find "${BACKEND_DIR}" -path "${DATA_DIR}" -prune -o \
        -type d -name target -prune -exec rm -rf -- {} +
    mkdir -p "${DATA_DIR}"
    docker run --rm --entrypoint sh -v "${DATA_DIR}:/cleanup" mysql:8.0.42 -c \
        "rm -rf /cleanup/nginx/log /cleanup/server1/logs /cleanup/server2/logs /cleanup/monitor/logs /cleanup/snailjob/logs"
}

clean_cache() {
    check_docker
    docker compose -f "${COMPOSE_FILE}" down
    remove_runtime_files
    log "Project caches and logs were removed. Persistent MySQL, Redis, and MinIO data was preserved."
}

clean_all() {
    check_docker
    if [[ "${1:-}" != "--yes" ]]; then
        printf 'This permanently deletes MySQL, Redis, MinIO, all container data, caches, and logs.\n'
        read -r -p "Type DELETE to continue: " confirmation
        [[ "${confirmation}" == "DELETE" ]] || die "Cancelled; no persistent data was deleted."
    fi
    docker compose -f "${COMPOSE_FILE}" down
    remove_runtime_files
    [[ "${DATA_DIR}" == "${SCRIPT_DIR}/docker-data" ]] || die "Refusing to delete an unexpected data path."
    docker run --rm --entrypoint sh -v "${DATA_DIR}:/cleanup" mysql:8.0.42 -c \
        "find /cleanup -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
    log "All project caches and persistent container data were removed. Backups were preserved."
}

run_build_and_start() {
    check_build_tools
    ensure_required_images
    build_frontend
    build_backend
    build_images
    start_services
}

main() {
    case "${1:-}" in
        start)
            run_build_and_start
            ;;
        stop)
            check_docker
            log "Stopping project containers (persistent data is preserved)"
            docker compose -f "${COMPOSE_FILE}" down
            ;;
        status)
            check_docker
            show_status
            ;;
        dev-start)
            dev_start
            ;;
        dev-stop)
            dev_stop
            ;;
        dev-restart)
            dev_restart
            ;;
        dev-status)
            dev_status
            ;;
        clean)
            check_build_tools
            ensure_required_images
            clean_build_artifacts
            build_frontend
            build_backend
            build_images
            start_services
            ;;
        backup)
            backup_data
            ;;
        restore-db)
            restore_database "${2:-}"
            ;;
        restore-data)
            restore_persistent_data "${2:-}"
            ;;
        clean-cache)
            clean_cache
            ;;
        clean-all)
            clean_all "${2:-}"
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
