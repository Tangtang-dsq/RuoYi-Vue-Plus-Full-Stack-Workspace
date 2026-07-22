# RuoYi Vue Plus Full Stack Workspace

一个集成 RuoYi-Vue-Plus 后端、Vue 3 前端和 Docker Compose 部署工具的全栈开发工作区。项目提供统一的本地开发、生产构建、容器启动、数据备份恢复与环境清理流程，便于快速运行、二次开发和部署 RuoYi Vue Plus。

## 第一部分：Windows + WSL2 首次配置与冷启动

这一部分面向第一次配置开发环境的用户。请特别注意每段命令标注的执行位置：Windows PowerShell 命令不能直接复制到 Ubuntu，Ubuntu 命令也不要放进 PowerShell 执行。

### 1. 安装 WSL2、Docker Desktop 和 Ubuntu 24.04

先在 Windows 的“启用或关闭 Windows 功能”中确认已启用：

- 适用于 Linux 的 Windows 子系统
- 虚拟机平台

以管理员身份打开 Windows PowerShell，执行：

```powershell
wsl --install -d Ubuntu-24.04
wsl --update
wsl --set-default-version 2
wsl --list --verbose
```

在最后一条命令的输出中，`Ubuntu-24.04` 的 `VERSION` 必须为 `2`。如果不是，执行：

```powershell
wsl --set-version Ubuntu-24.04 2
```

从 Docker 官方网站安装 Docker Desktop。安装完成后启动 Docker Desktop，进入：

```text
Settings → Resources → WSL Integration
```

开启 `Enable integration with my default WSL distro`，并打开 `Ubuntu-24.04` 对应的开关，然后点击 `Apply & restart`。

> [!IMPORTANT]
> 本项目使用 Docker Desktop 提供的 Docker Engine。不要再在 Ubuntu 中单独执行 `apt install docker.io`，否则容易同时存在两套 Docker，造成上下文、端口和数据目录混乱。这里所说的“在 Ubuntu 中启用 Docker”，是启用 Docker Desktop 的 WSL Integration。

打开 Ubuntu 24.04 终端，验证：

```bash
docker version
docker compose version
docker info
```

如果出现 `docker: command not found` 或无法连接 daemon，请确认 Docker Desktop 正在运行、WSL Integration 已开启，然后在 PowerShell 执行 `wsl --shutdown` 并重新打开 Ubuntu。

### 2. 安装 Maven 和基础工具

以下命令都在 Ubuntu 24.04 终端执行：

```bash
sudo apt update
sudo apt install -y maven wget curl git ca-certificates
mvn -version
git --version
```

### 3. 安装 BellSoft JDK 17

在 Ubuntu 终端下载并安装 BellSoft JDK 17：

```bash
cd /tmp
wget 'https://download.bell-sw.com/java/17.0.19+11/bellsoft-jdk17.0.19+11-linux-amd64-full.deb'
sudo apt install -y ./bellsoft-jdk17.0.19+11-linux-amd64-full.deb
java -version
javac -version
```

`java -version` 应显示 BellSoft/Liberica JDK 17。如果机器上存在多个 JDK，可以选择默认版本：

```bash
sudo update-alternatives --config java
sudo update-alternatives --config javac
```

再次执行 `mvn -version`，确认 Maven 显示的 Java version 为 `17`。

### 4. 安装 NVM

仍在 Ubuntu 终端执行：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
source ~/.bashrc
nvm --version
```

如果当前终端仍然提示 `nvm: command not found`，关闭并重新打开 Ubuntu 终端后再试。

### 5. 安装 Node.js 24

```bash
nvm install 24
nvm alias default 24
nvm use 24
node --version
npm --version
```

以后新打开的 WSL 终端会默认使用 Node.js 24。

### 6. 在 WSL2 的 Linux 文件系统中克隆项目

不要把项目克隆到 `C:\` 后通过 `/mnt/c/...` 编译。Node.js 的大量小文件、Maven 构建和 Docker bind mount 在 `/mnt/c` 下通常更慢，而且容易遇到权限、文件监听和换行符问题。

推荐在 Ubuntu 终端中克隆到 Linux 用户目录：

```bash
mkdir -p ~/dev
cd ~/dev
git clone <你的GitLab仓库地址> ruoyi-vue-plus-full-stack-workspace
cd ~/dev/ruoyi-vue-plus-full-stack-workspace
```

同一个目录有两种表示方式：

| 使用位置 | 示例路径 |
| --- | --- |
| WSL/Ubuntu 终端 | `/home/<Ubuntu用户名>/dev/ruoyi-vue-plus-full-stack-workspace` 或 `~/dev/ruoyi-vue-plus-full-stack-workspace` |
| Windows、IntelliJ、资源管理器 | `\\wsl.localhost\Ubuntu-24.04\home\<Ubuntu用户名>\dev\ruoyi-vue-plus-full-stack-workspace` |

> [!IMPORTANT]
> `~/dev/...` 是 Ubuntu 内部路径，Windows 程序不能把它当成 `C:\...` 使用。Windows 需要通过 `\\wsl.localhost\Ubuntu-24.04\...` 访问。反过来，Ubuntu 中的 `/mnt/c/...` 才对应 Windows 的 `C:\...`，但本项目不建议放在那里。

### 7. 检查端口冲突

完整部署会使用以下 Windows 主机端口：

```text
80、3306、6379、8080、8081、8800、9000、9001、9090
```

在 Ubuntu 中检查是否已有程序监听：

```bash
for port in 80 3306 6379 8080 8081 8800 9000 9001 9090; do
  if ss -ltn "sport = :$port" | grep -q LISTEN; then
    echo "占用  $port"
  else
    echo "可用  $port"
  fi
done
```

也可以在管理员 PowerShell 中检查 Windows 进程：

```powershell
Get-NetTCPConnection -State Listen |
  Where-Object LocalPort -in 80,3306,6379,8080,8081,8800,9000,9001,9090 |
  Sort-Object LocalPort |
  Format-Table LocalAddress,LocalPort,OwningProcess
```

如果端口被占用，应先停止冲突程序。初学阶段不建议随意修改 Compose 端口，因为前端代理和服务配置可能也需要同步调整。

### 8. 首次初始化并完整部署

在 Ubuntu 终端执行：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
chmod +x manage.sh
./manage.sh start
```

第一次执行可能需要较长时间，因为脚本会检查或拉取镜像、安装前端依赖、编译前端、用 Maven 打包后端、构建后端镜像、初始化数据库并等待所有服务健康。任何步骤失败时脚本都会停止，不会继续使用不完整产物。

启动完成后检查：

```bash
./manage.sh status
docker compose logs --tail 100
```

### 9. 从 Windows 浏览器验证并停止生产部署

在 Windows 桌面的浏览器中访问：

- 前端：<http://localhost/>
- MinIO 控制台：<http://localhost:9001/>
- Monitor：<http://localhost/admin/>
- SnailJob：<http://localhost/snail-job/>

能正常进入前端后，说明 Windows → Docker Desktop → WSL 项目的访问链路正常。回到 Ubuntu 终端停止完整生产部署：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
./manage.sh stop
```

`stop` 会删除生产容器和 Compose 网络，但不会删除 `docker-data` 中的 MySQL、Redis、MinIO 数据。

### 10. 使用 IntelliJ IDEA 和 Cursor 打开 WSL2 项目

后端建议用 IntelliJ IDEA 打开：

```text
\\wsl.localhost\Ubuntu-24.04\home\<Ubuntu用户名>\dev\ruoyi-vue-plus-full-stack-workspace\RuoYi-Vue-Plus
```

等待 IntelliJ 导入根目录 `pom.xml`，将 Project SDK 和 Maven Runner JRE 设置为 JDK 17，并确认 Maven 面板能识别全部模块。

前端建议使用 Cursor 的 WSL/Remote WSL 模式打开。在 Ubuntu 终端中进入前端目录：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/plus-ui
cursor .
```

如果 `cursor` 命令不可用，先在 Cursor 中安装 WSL 扩展并执行命令面板中的 `WSL: Reopen Folder in WSL`，或者直接打开 Windows 路径：

```text
\\wsl.localhost\Ubuntu-24.04\home\<Ubuntu用户名>\dev\ruoyi-vue-plus-full-stack-workspace\plus-ui
```

不要让 IDE 把项目复制到 Windows 临时目录；后端、前端和 `docker-data` 必须保持 README 所示的相对目录结构。

### 11. 启动日常开发环境

在 Ubuntu 终端只启动开发所需的数据库、缓存和对象存储：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
./manage.sh dev-start
```

随后：

1. IntelliJ Maven Profiles 选择 `dev`，依次启动 `MonitorAdminApplication`、`SnailJobServerApplication`、`DromaraApplication`。
2. 在 WSL 前端终端执行：

   ```bash
   cd ~/dev/ruoyi-vue-plus-full-stack-workspace/plus-ui
   npm install
   npm run dev
   ```

3. 开发结束后停止 IntelliJ 中的 Java 服务，在前端终端按 `Ctrl+C`，最后执行：

   ```bash
   cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
   ./manage.sh dev-stop
   ```

### 12. 使用 Codex 开发后，哪些内容需要重启

Codex 修改完代码后先查看它的总结和 `git diff`，确认修改范围，再按下表操作：

| Codex 修改的内容 | 需要执行的操作 |
| --- | --- |
| Vue、TypeScript、CSS、前端页面 | Vite 通常自动热更新，不需要重启；页面异常时重启 `npm run dev` |
| `package.json` 或 lock 文件 | 在 `plus-ui` 执行 `npm install`，然后重启 `npm run dev` |
| 普通后端 Java 代码 | 在 IntelliJ 重新运行 `DromaraApplication` |
| Monitor 模块代码 | 重新运行 `MonitorAdminApplication` |
| SnailJob 模块代码 | 重新运行 `SnailJobServerApplication` |
| `pom.xml` 或 Maven 依赖 | IntelliJ 重新加载 Maven 项目，再重启受影响的 Java 服务 |
| `application-dev.yml` | 重启使用该配置的 IntelliJ Java 服务 |
| MySQL 表结构或初始化 SQL | 先执行 `./manage.sh backup`；按迁移 SQL 更新现有数据库，随后重启受影响的后端服务 |
| Redis 或 MinIO 配置 | 执行 `./manage.sh dev-restart`，再重启依赖它们的后端服务 |
| `docker-compose.yml`、Nginx 或生产配置 | 开发环境按需执行 `dev-restart`；验证生产部署时执行 `./manage.sh start` |
| `manage.sh` | 当前运行中的服务不会自动变化；根据修改内容重新执行相应的管理命令 |

日常开发结束前建议执行：

```bash
git status
git diff
```

数据库发生重要变化时先执行 `./manage.sh backup`，再提交代码。不要把 `docker-data` 或 `backups` 加入 Git。

## ⚠️ 数据备份、恢复与危险清理操作（必读）

> [!CAUTION]
> `clean-all`、`restore-db` 和 `restore-data` 都是破坏性操作：
> `clean-all` 会永久删除全部容器持久化数据；`restore-db` 会覆盖当前 `ry-vue` 数据库；`restore-data` 会替换整个 `docker-data`。
> 操作前必须执行 `./manage.sh backup`，确认备份文件存在，并将重要备份复制到项目目录之外。

以下命令均在 WSL 中执行：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker

# 同时生成可移植的 MySQL 全量 SQL，以及 MySQL/Redis/MinIO 等全部持久化数据归档
./manage.sh backup

# 只清理 node_modules、dist、Maven target 和容器运行日志；不删除业务数据，也不启动项目
./manage.sh clean-cache
```

### 备份内容

每次备份保存在 `RuoYi-Vue-Plus/script/docker/backups/<时间戳>/`，其中：

- `mysql-full.sql.gz`：`ry-vue` 的表结构和全部数据，可跨环境恢复。
- `docker-data.tar.gz`：MySQL、Redis、MinIO 及容器日志的物理快照，用于原样恢复整套环境。
- `SHA256SUMS`：备份时间、MySQL 镜像版本和两个备份文件的校验值。

备份会自动记录当前运行的服务、启动 MySQL 完成逻辑导出、停止容器生成一致的物理快照，最后恢复原先运行的服务。恢复是显式操作，不会在 `start` 时自动套用旧备份：

> [!IMPORTANT]
> `backup` 为保证 MySQL 物理文件一致，会短暂停止容器。它不是零停机备份，请避开正在使用系统的时间执行。

### 恢复数据库或全部持久化数据

```bash
# 只恢复数据库；恢复后自动清空 Redis，避免读取旧缓存
./manage.sh restore-db backups/20260722-180000/mysql-full.sql.gz

# 原样恢复全部持久化数据；该操作会替换整个 docker-data
./manage.sh restore-data backups/20260722-180000/docker-data.tar.gz

# 恢复完成后，如项目原先没有运行，再手动启动
./manage.sh start
```

恢复命令的区别：

| 命令 | 被覆盖的内容 | 适用场景 |
| --- | --- | --- |
| `restore-db <mysql-full.sql.gz>` | 当前 `ry-vue` 数据库，并清空 Redis 缓存 | 恢复数据库结构和数据、迁移 MySQL |
| `restore-data <docker-data.tar.gz>` | 整个 `docker-data` | 原样恢复 MySQL、Redis、MinIO 和容器运行数据 |

### 清理项目缓存

下面的命令只删除可重新生成的文件，不删除 MySQL、Redis、MinIO 数据，并且清理后不会自动启动项目：

```bash
./manage.sh clean-cache
```

删除范围包括前端 `node_modules`、`dist`、Vite/ESLint 缓存、全部 Maven `target` 和容器运行日志。清理完成后需要重新部署时执行 `./manage.sh start`。

### 彻底清空并重新初始化

> [!CAUTION]
> 以下命令会永久删除 MySQL、Redis、MinIO 以及 `docker-data` 中的全部内容。仅仅想解决编译问题时不要使用它，应使用 `clean-cache`。

```bash
# 推荐：要求手动输入 DELETE，降低误操作风险
./manage.sh clean-all

# 极度危险：跳过确认，主要用于已经确认备份有效的自动化操作
./manage.sh clean-all --yes
```

彻底清理之后有两种恢复方式：

```bash
# 方式一：根据仓库内的三份基线 SQL 创建全新数据库
./manage.sh start

# 方式二：原样恢复此前的全部持久化数据，然后启动项目
./manage.sh restore-data backups/<时间戳>/docker-data.tar.gz
./manage.sh start
```

如果只需要恢复 MySQL，脚本会临时启动 MySQL 和 Redis、完成恢复并清空旧缓存：

```bash
./manage.sh restore-db backups/<时间戳>/mysql-full.sql.gz
./manage.sh start
```

`backups/` 已被 Git 忽略，不会随 `git commit` 保存。建议备份完成后复制到其他磁盘、NAS 或异地存储；项目目录损坏或被删除时，项目内的备份也会一起丢失。

## 🚀 项目启动与部署（必读）

项目统一在 WSL Ubuntu 24.04 中运行。请先安装 JDK 17、Maven、Node.js 20.19+，并在 Docker Desktop 的 **Settings → Resources → WSL Integration** 中启用当前 WSL 发行版。项目使用标准 Compose bridge 网络，不需要启用 Docker Desktop host networking。

```bash
# 基础环境检查
java -version
mvn -version
node --version
npm --version
docker info
docker compose version
```

### 日常开发启动（推荐）

开发环境使用 `dev` Profile：Docker 只运行 MySQL、Redis、MinIO，Java 后端在 IntelliJ IDEA 中运行，Vue 前端在 WSL 中通过 Vite 运行。日常开发不要执行 `./manage.sh start`，该命令用于完整生产构建和容器化部署。

#### 1. 启动开发基础容器

如果此前执行过 `./manage.sh stop`，在 WSL 中重新创建并启动三个基础容器：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
./manage.sh dev-start
```

确认 MySQL、Redis、MinIO 的状态均为 `healthy`。MySQL 数据目录为空时会自动创建 `ry-vue` 数据库，并依次导入 `ry_vue_5.X.sql`、`ry_workflow.sql`、`ry_job.sql`；已有数据库不会重复初始化。

#### 2. 配置 IntelliJ IDEA

- Project SDK 和所有运行配置使用 JDK 17。
- 在右侧 Maven 面板的 `Profiles` 中勾选 `dev`。
- 取消选择 `prod`，不要使用配置不完整的 `local` Profile。

#### 3. 在 IntelliJ IDEA 中启动后端

完整开发环境按以下顺序启动三个 Spring Boot 类：

```text
1. MonitorAdminApplication
2. SnailJobServerApplication
3. DromaraApplication
```

IntelliJ 顶部可能同时显示带 Docker 图标的以下配置：

```text
ruoyi-server
ruoyi-monitor-admin
ruoyi-snailjob-server
```

这些配置用于完整容器部署，日常 IDEA 开发时不要运行。只开发普通业务接口时可以只启动 `DromaraApplication`，但控制台可能持续出现 Monitor 和 SnailJob 连接失败后的重试日志。

#### 4. 启动前端开发服务器

打开另一个 WSL 终端：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/plus-ui

# 首次运行、执行过 clean-cache 或前端依赖发生变化时执行
npm install

npm run dev
```

前端开发地址以 Vite 的终端输出为准。修改 Vue、TypeScript 或样式文件后会自动热更新，通常不需要重新启动。

### 日常修改、重启与结束开发

- 修改前端源码：等待 Vite 自动热更新。
- 修改普通后端 Java 代码：在 IntelliJ 中重新运行 `DromaraApplication`。
- 修改监控模块：重新运行 `MonitorAdminApplication`。
- 修改任务调度模块：重新运行 `SnailJobServerApplication`。
- 修改数据库结构或积累重要开发数据后，及时执行 `./manage.sh backup`。
- 修改 MySQL、Redis 或 MinIO 配置后，执行：

  ```bash
  cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
  ./manage.sh dev-restart
  ```

- 随时查看三个开发基础容器的状态：

  ```bash
  ./manage.sh dev-status
  ```

结束当天开发时：

1. 在 IntelliJ IDEA 中停止正在运行的 Java 服务。
2. 在前端终端按 `Ctrl+C` 停止 Vite。
3. 停止基础容器，但保留容器和持久化数据：

   ```bash
   cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
   ./manage.sh dev-stop
   ```

下次继续开发时，统一执行：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
./manage.sh dev-start
```

`dev-start` 同时适用于容器已经存在和容器被 `./manage.sh stop` 删除的情况，并会等待三个服务全部通过健康检查。`dev-stop` 只停止容器，不删除容器和持久化数据。

开发环境的运行结构如下：

```text
MySQL、Redis、MinIO  -> Docker Compose
Java 后端             -> IntelliJ IDEA + dev Profile + JDK 17
Vue 前端              -> WSL + npm run dev
```

### 完整生产构建与容器部署

生产部署使用 `prod` Profile。管理脚本会先确认全部外部基础镜像在本地可用，已有固定版本镜像直接使用，缺失镜像最多重试拉取三次；确认齐全后再构建前端、打包全部后端、构建三个后端镜像，并启动 Nginx、两个业务节点、监控、SnailJob、MySQL、Redis 和 MinIO。

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker

# 首次使用只需执行一次
chmod +x manage.sh

# 增量安装依赖、重新构建并部署全部服务
./manage.sh start

# 查看状态与访问地址
./manage.sh status

# 查看全部或单个服务日志
docker compose logs -f
docker compose logs -f ruoyi-server1
```

生产代码更新后，在拉取最新代码并确认配置无误后重新部署：

```bash
./manage.sh start
```

清除前端依赖、前端产物和全部 Maven `target`，然后重新安装、构建并启动：

```bash
./manage.sh clean
```

停止并删除生产容器：

```bash
./manage.sh stop
```

`start`、`clean` 和 `stop` 都不会删除 `docker-data`。不要执行 `docker compose down --volumes`，也不要在未备份时删除 `docker-data/mysql/data`。

### 开发与生产环境对照

| 场景 | 前端 | 后端 | 容器范围 |
| --- | --- | --- | --- |
| 日常开发 | `npm run dev`，读取 `.env.development` | IDEA + Maven `dev`，读取 `application-dev.yml` | MySQL、Redis、MinIO |
| 完整部署 | `manage.sh` 执行 `npm run build:prod` | Maven `prod`，读取 `application-prod.yml` | 全部服务 |

仓库虽然保留 Maven `local` Profile，但目前没有完整的 `application-local.yml`，请勿使用。更详细的容器说明见 [Docker 运行文档](RuoYi-Vue-Plus/script/docker/README.md)。

## 服务访问

| 服务 | 开发环境 | 完整部署 |
| --- | --- | --- |
| 前端 | Vite 启动后以终端输出为准 | <http://localhost/> |
| 后端 API | <http://localhost:8080/> | <http://localhost/prod-api/> |
| 监控中心 | <http://localhost:9090/admin/> | <http://localhost/admin/> |
| SnailJob | <http://localhost:8800/snail-job/> | <http://localhost/snail-job/> |
| MinIO 控制台 | <http://localhost:9001/> | <http://localhost:9001/> |

默认基础设施连接信息：

- MySQL：`localhost:3306`，数据库 `ry-vue`，账号/密码 `root/root`
- Redis：`localhost:6379`，密码 `ruoyi123`
- MinIO：`localhost:9000/9001`，账号/密码 `ruoyi/ruoyi123`

## Docker 网络与端口占用

完整部署使用标准 Compose bridge 网络。容器之间通过 `mysql`、`redis`、`minio`、`ruoyi-server1` 等服务名通信；需要从 Windows、WSL 或浏览器访问的端口通过 `ports` 映射到主机。这种方式兼容 Docker Desktop，不需要启用 host networking。

### 主机端口

| 主机端口 | 服务 | 用途 |
| ---: | --- | --- |
| `80` | Nginx | 前端及 `/prod-api/`、`/admin/`、`/snail-job/` 反向代理 |
| `3306` | MySQL | 本地数据库工具和开发环境后端 |
| `6379` | Redis | 本地开发环境后端 |
| `8080` | 业务节点 1 | 直接调试后端节点 1 |
| `8081` | 业务节点 2 | 直接调试后端节点 2 |
| `8800` | SnailJob | 直接访问 SnailJob 控制台 |
| `9000` | MinIO | S3 API 和对象访问 |
| `9001` | MinIO | 管理控制台 |
| `9090` | Monitor Admin | 直接访问监控中心 |

SnailJob 内部端口 `17888`、`28080`、`28081` 只在 Compose 网络内使用，不映射、不占用 Windows 主机端口。HTTPS `443` 当前未启用，也不映射。

检查主机端口：

```bash
for port in 80 3306 6379 8080 8081 8800 9000 9001 9090; do
  if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
    echo "OPEN   $port"
  else
    echo "CLOSED $port"
  fi
done
```

部署到真实服务器时通常只应向用户开放 `80`，启用 HTTPS 后再映射和开放 `443`；数据库、缓存、管理后台和直接后端端口应通过防火墙限制来源。

## 常用排错命令

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker

# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f
docker compose logs -f mysql
docker compose logs -f redis
docker compose logs -f ruoyi-server1
docker compose logs -f nginx-web

# 检查端口占用
ss -lntp | grep -E ':(80|3306|6379|8080|8081|8800|9000|9001|9090)\b'

# 检查最终 Compose 配置
docker compose config
```

如果 WSL 中提示找不到 Docker，请启动 Docker Desktop 并检查当前发行版的 WSL Integration。前端构建失败时先检查 Node 版本和 npm 网络；后端构建失败时确认 IDEA、终端和 Maven 都使用 JDK 17。

## 数据持久化与备份

运行数据通过相对 bind mount 保存在 `RuoYi-Vue-Plus/script/docker/docker-data/`：

```text
docker-data/
├── mysql/data/       # MySQL 数据
├── redis/data/       # Redis RDB/AOF
├── minio/data/       # MinIO 对象文件
├── minio/config/     # MinIO 配置
├── nginx/log/        # Nginx 日志
├── server1/logs/     # 主服务节点 1 日志
├── server2/logs/     # 主服务节点 2 日志
├── monitor/logs/     # 监控服务日志
└── snailjob/logs/    # SnailJob 日志
```

删除或重建容器不会删除这些目录，但持久化不等于备份。重要数据需要定期复制到其他磁盘或异地存储；不要在 MySQL 或 MinIO 正在写入时直接复制其数据目录。

管理脚本会在启动前设置 Redis bind mount 所需的写权限。若绕过脚本手动创建 Redis 数据目录，需要确保容器内的非 root Redis 用户可写，否则 AOF 初始化会失败。

## 项目结构

```text
ruoyi-vue-plus-full-stack-workspace/
├── plus-ui/                         # Vue 3 前端
└── RuoYi-Vue-Plus/                  # Spring Boot 后端
    ├── ruoyi-admin/                 # 主应用
    ├── ruoyi-common/                # 通用模块
    ├── ruoyi-extend/                # 监控与 SnailJob
    ├── ruoyi-modules/               # 业务模块
    └── script/docker/
        ├── manage.sh                # WSL 项目管理脚本
        ├── docker-compose.yml       # 完整容器编排
        ├── nginx/conf/nginx.conf
        └── redis/conf/redis.conf
```

## 技术栈

- 后端：Spring Boot 3.5.15、JDK 17、MyBatis-Plus、Sa-Token、Redisson
- 前端：Vue 3、TypeScript、Element Plus、Vite
- 基础设施：MySQL 8、Redis 7.2、MinIO、Nginx、Docker Compose

## 功能特性

- 用户、角色、菜单、部门、岗位、字典与参数管理
- 多租户、数据权限、数据脱敏和字段加密
- 操作日志、登录日志、在线用户与服务监控
- SnailJob 分布式任务调度
- 代码生成、接口文档、文件与对象存储管理
- WebSocket、SSE、国际化、分布式锁和幂等控制

## 相关文档

- [本项目 Docker 运行文档](RuoYi-Vue-Plus/script/docker/README.md)
- [RuoYi-Vue-Plus 官方文档](https://plus-doc.dromara.org)
- [Docker Compose 官方文档](https://docs.docker.com/compose/)
- [Spring Boot 官方文档](https://spring.io/projects/spring-boot)

## 开源协议

本项目遵循 [MIT](RuoYi-Vue-Plus/LICENSE) 开源协议，基于 RuoYi-Vue-Plus 5.6.2。

> 本项目仅供学习交流使用，请勿用于商业用途。
