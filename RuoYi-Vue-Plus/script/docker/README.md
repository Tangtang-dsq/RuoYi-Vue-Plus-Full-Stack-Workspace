# WSL 容器化运行说明

## 备份、恢复和清理

```bash
# 创建 backups/<时间戳>/mysql-full.sql.gz、docker-data.tar.gz 和 SHA256SUMS
./manage.sh backup

# 显式恢复 MySQL（结构和数据），并清空 Redis 旧缓存
./manage.sh restore-db backups/<时间戳>/mysql-full.sql.gz

# 显式替换并恢复整个 docker-data
./manage.sh restore-data backups/<时间戳>/docker-data.tar.gz

# 只删除项目依赖、编译产物和运行日志，不启动项目、不删除持久化数据
./manage.sh clean-cache

# 删除项目缓存和全部持久化数据，不启动项目
./manage.sh clean-all          # 交互输入 DELETE
./manage.sh clean-all --yes    # 跳过交互确认
```

`backup` 中的 SQL 包含 `ry-vue` 的表结构和全部数据，适合迁移或单独恢复数据库；`tar.gz` 是停止容器后生成的物理快照，包含 MySQL、Redis、MinIO 和其他 `docker-data` 内容。备份完成后只恢复操作前正在运行的服务。

`start` 不会自动恢复任何备份。彻底清理后，可以选择直接执行 `start` 使用仓库内三份基线 SQL 初始化，也可以先执行 `restore-data` 原样恢复；若只需恢复数据库，则先让 MySQL 可用后执行 `restore-db`。备份文件默认不提交 Git，请另行复制到安全位置。

本目录使用一个 WSL Bash 脚本管理完整项目。脚本会先确认全部外部基础镜像在本地可用：已有固定版本镜像直接使用，缺失镜像最多重试拉取三次。确认齐全后才构建前端、以 Maven `prod` Profile 打包后端、构建三个后端 Docker 镜像，最后由 Docker Compose 启动全部服务。

## 前置条件

- WSL Ubuntu 24.04
- Java 17 和 Maven
- Node.js 20.19 或更高版本（支持 NVM）
- Docker Desktop 已启动，并在 **Settings → Resources → WSL Integration** 中启用当前发行版
- Docker Compose v2（`docker compose`）

首次使用：

```bash
cd ~/dev/one-student-ruoyi-plus/RuoYi-Vue-Plus/script/docker
chmod +x manage.sh
```

脚本根据自身位置解析项目路径，因此之后可以从任意目录调用。

## 命令

```bash
# 增量安装依赖、构建前后端与镜像，然后启动全部服务
./manage.sh start

# 查看容器状态和访问地址
./manage.sh status

# 停止并删除项目容器，但保留所有持久化数据
./manage.sh stop

# 清除 node_modules、dist 和 Maven target，重新安装并全量构建后启动
./manage.sh clean
```

`clean` 和 `stop` 都不会删除 `docker-data`。不要给 `docker compose down` 添加 `--volumes`。

## 首次数据库初始化

MySQL 使用 `MYSQL_DATABASE=ry-vue` 创建数据库。仅当 `docker-data/mysql/data` 为空时，MySQL 官方入口会依次执行：

1. `ry_vue_5.X.sql`
2. `ry_workflow.sql`
3. `ry_job.sql`

已有数据库不会重复导入。只有明确需要完全重建数据库时，才应在完成备份后执行 `./manage.sh clean-all`；该操作不可恢复，并且需要输入 `DELETE` 或显式传入 `--yes`。

## 持久化目录

以下数据通过相对 bind mount 保存在本目录下：

- `docker-data/mysql/data`
- `docker-data/redis/data`
- `docker-data/minio/data`
- `docker-data/minio/config`
- `docker-data/nginx/log`
- 各 Java 服务的 `logs`

相对挂载能防止删除容器时丢失数据，但它不是独立备份。重要数据仍需定期复制到其他磁盘或异地存储。

管理脚本会在启动前为 Redis 数据目录设置容器所需的写权限；不要手动改回仅宿主用户可写，否则启用 AOF 的 Redis 会因无法创建 `appendonlydir` 而退出。

## 服务地址

- 前端：<http://localhost/>
- 后端代理：<http://localhost/prod-api/>
- 监控中心：<http://localhost/admin/>
- SnailJob：<http://localhost/snail-job/>
- MinIO 控制台：<http://localhost:9001/>
- MySQL：`localhost:3306`
- Redis：`localhost:6379`
