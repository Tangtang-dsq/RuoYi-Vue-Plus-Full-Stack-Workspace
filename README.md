# RuoYi Vue Plus Full Stack Workspace

本仓库是一个集成 RuoYi-Vue-Plus 后端、Vue 3 前端和 Docker Compose 部署工具的全栈开发工作区，提供本地开发、前后端构建、完整容器部署、数据备份恢复和环境清理能力。

本文档以 Windows 11 + WSL2 + Ubuntu 24.04 + Docker Desktop 为标准环境。除明确标注为 PowerShell 的命令外，其余命令均在 WSL Ubuntu 终端中执行。

## 目录

1. [项目概述](#1-项目概述)
2. [技术栈](#2-技术栈)
3. [项目结构](#3-项目结构)
4. [环境要求](#4-环境要求)
5. [首次环境配置](#5-首次环境配置)
6. [获取项目与初始化](#6-获取项目与初始化)
7. [前端依赖安装与构建](#7-前端依赖安装与构建)
8. [日常开发](#8-日常开发)
9. [完整构建与容器部署](#9-完整构建与容器部署)
10. [服务地址与端口](#10-服务地址与端口)
11. [管理脚本命令](#11-管理脚本命令)
12. [数据持久化、备份与恢复](#12-数据持久化备份与恢复)
13. [代码修改后的重启规则](#13-代码修改后的重启规则)
14. [常见问题与排查](#14-常见问题与排查)
15. [生产部署注意事项](#15-生产部署注意事项)
16. [相关文档与协议](#16-相关文档与协议)

## 1. 项目概述

### 1.1 运行模式

项目支持两种运行模式：

| 场景 | 前端 | 后端 | Docker 容器 |
| --- | --- | --- | --- |
| 日常开发 | Vite 开发服务器，读取 `.env.development` | IntelliJ IDEA + Maven `dev` Profile | MySQL、Redis、MinIO |
| 完整部署 | Nginx 托管 `plus-ui/dist` | Maven `prod` Profile 构建的容器镜像 | 全部服务 |

日常开发优先使用第一种模式，以获得前端热更新和后端断点调试能力。`manage.sh start` 与 `manage-pnpm.sh start` 用于完整构建和容器化部署。

### 1.2 主要功能

- 用户、角色、菜单、部门、岗位、字典与参数管理
- 多租户、数据权限、数据脱敏和字段加密
- 操作日志、登录日志、在线用户与服务监控
- SnailJob 分布式任务调度
- 代码生成、接口文档、文件与对象存储管理
- WebSocket、SSE、国际化、分布式锁和幂等控制

## 2. 技术栈

| 层级 | 主要技术 |
| --- | --- |
| 后端 | Spring Boot 3.5.15、JDK 17、MyBatis-Plus、Sa-Token、Redisson |
| 前端 | Vue 3、TypeScript、Element Plus、Vite 7、Pinia |
| 数据与中间件 | MySQL 8.0、Redis 7.2、MinIO、SnailJob |
| 部署 | Nginx、Docker Desktop、Docker Compose v2 |
| 构建工具 | Maven、npm 或 pnpm |

当前项目版本基于 RuoYi-Vue-Plus `5.6.2`，前端 `package.json` 要求 Node.js `>= 20.19.0`。

## 3. 项目结构

```text
ruoyi-vue-plus-full-stack-workspace/
├── README.md
├── plus-ui/                              # Vue 3 前端
│   ├── package.json                      # 前端脚本与依赖
│   ├── .env.development                  # 开发环境变量
│   ├── .env.production                   # 生产环境变量
│   └── dist/                             # 前端生产构建产物
└── RuoYi-Vue-Plus/                       # Spring Boot 后端
    ├── pom.xml                           # Maven 聚合工程
    ├── ruoyi-admin/                      # 主应用
    ├── ruoyi-common/                     # 通用模块
    ├── ruoyi-extend/                     # Monitor 与 SnailJob
    ├── ruoyi-modules/                    # 业务模块
    └── script/docker/
        ├── manage.sh                     # npm 构建与环境管理脚本
        ├── manage-pnpm.sh                # pnpm 构建与环境管理脚本
        ├── docker-compose.yml            # 完整容器编排
        ├── nginx/conf/nginx.conf          # Nginx 配置
        ├── redis/conf/redis.conf          # Redis 配置
        ├── docker-data/                   # 容器持久化数据
        └── backups/                       # 管理脚本生成的备份
```

后端、前端和 `script/docker` 依赖当前相对目录关系，请勿单独移动其中一个目录。

## 4. 环境要求

### 4.1 软件要求

| 软件 | 要求 |
| --- | --- |
| 操作系统 | Windows 11，启用 WSL2 |
| WSL 发行版 | Ubuntu 24.04 |
| Docker | Docker Desktop，启用 WSL Integration |
| JDK | BellSoft Liberica JDK 17 或其他兼容 JDK 17 |
| Maven | Maven 3.8+ |
| Node.js | `>= 20.19.0`，推荐 Node.js 24 |
| 前端包管理器 | npm 8.19+ 或 pnpm |
| 基础工具 | Git、curl、wget、gzip、tar |

### 4.2 环境检查

```bash
java -version
mvn -version
node --version
npm --version
pnpm --version          # 选择 pnpm 时检查
docker version
docker compose version
docker info
```

`mvn -version` 显示的 Java version 必须为 `17`。Docker 必须由 Docker Desktop 提供，并能在 WSL 中正常访问。

### 4.3 端口要求

完整部署会占用以下主机端口：

```text
80、3306、6379、8080、8081、8800、9000、9001、9090
```

在 WSL 中检查端口：

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

## 5. 首次环境配置

### 5.1 安装 WSL2 与 Ubuntu 24.04

先在 Windows 的“启用或关闭 Windows 功能”中启用：

- 适用于 Linux 的 Windows 子系统
- 虚拟机平台

以管理员身份打开 PowerShell：

```powershell
wsl --install -d Ubuntu-24.04
wsl --update
wsl --set-default-version 2
wsl --list --verbose
```

如果 `Ubuntu-24.04` 的 `VERSION` 不是 `2`：

```powershell
wsl --set-version Ubuntu-24.04 2
```

### 5.2 配置 Docker Desktop

安装并启动 Docker Desktop，打开：

```text
Settings -> Resources -> WSL Integration
```

启用默认 WSL 发行版集成，并打开 `Ubuntu-24.04` 对应开关，然后选择 `Apply & restart`。

> [!IMPORTANT]
> 本项目使用 Docker Desktop 提供的 Docker Engine。不要在 Ubuntu 中额外安装 `docker.io`，否则可能出现两套 Docker 上下文、端口和数据目录互不一致的问题。

如果 WSL 无法访问 Docker，请确认 Docker Desktop 正在运行，然后在 PowerShell 执行 `wsl --shutdown` 并重新打开 Ubuntu。

### 5.3 安装 JDK、Maven 与基础工具

在 Ubuntu 中执行：

```bash
sudo apt update
sudo apt install -y maven wget curl git ca-certificates gzip tar

cd /tmp
wget 'https://download.bell-sw.com/java/17.0.19+11/bellsoft-jdk17.0.19+11-linux-amd64-full.deb'
sudo apt install -y ./bellsoft-jdk17.0.19+11-linux-amd64-full.deb

java -version
javac -version
mvn -version
```

存在多个 JDK 时，可切换默认版本：

```bash
sudo update-alternatives --config java
sudo update-alternatives --config javac
```

### 5.4 安装 Node.js

通过 NVM 安装 Node.js 24：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
source ~/.bashrc
nvm install 24
nvm alias default 24
nvm use 24
node --version
npm --version
```

如果当前终端找不到 `nvm`，关闭并重新打开 Ubuntu 终端后再试。

### 5.5 安装 pnpm（可选）

使用 pnpm 开发或执行 `manage-pnpm.sh` 前，需要在 WSL 中安装 pnpm：

```bash
npm install -g pnpm
pnpm --version
```

也可以在系统提供 Corepack 时安装：

```bash
corepack enable
corepack prepare pnpm@latest --activate
pnpm --version
```

只使用 npm 时不需要安装 pnpm。

## 6. 获取项目与初始化

### 6.1 克隆到 WSL 文件系统

建议将项目放在 WSL 的 Linux 文件系统中，不要放在 `/mnt/c/...` 下。Maven、Node.js 和 Docker bind mount 在 Linux 文件系统中通常具有更好的性能和文件权限兼容性。

```bash
mkdir -p ~/dev
cd ~/dev
git clone <你的GitLab仓库地址> ruoyi-vue-plus-full-stack-workspace
cd ~/dev/ruoyi-vue-plus-full-stack-workspace
```

路径对应关系：

| 使用位置 | 项目路径 |
| --- | --- |
| WSL/Ubuntu | `~/dev/ruoyi-vue-plus-full-stack-workspace` |
| Windows/IntelliJ | `\\wsl.localhost\Ubuntu-24.04\home\<Ubuntu用户名>\dev\ruoyi-vue-plus-full-stack-workspace` |

### 6.2 IDE 配置

IntelliJ IDEA 打开后端目录：

```text
\\wsl.localhost\Ubuntu-24.04\home\<Ubuntu用户名>\dev\ruoyi-vue-plus-full-stack-workspace\RuoYi-Vue-Plus
```

等待根 `pom.xml` 导入完成，将 Project SDK 和 Maven Runner JRE 设置为 JDK 17。

前端建议使用 Cursor 或 VS Code 的 WSL 模式打开：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/plus-ui
cursor .
```

## 7. 前端依赖安装与构建

前端目录为 `plus-ui`，npm 与 pnpm 均可执行现有 `package.json` 脚本。

> [!IMPORTANT]
> 同一工作目录请选择一种包管理器持续使用。不要在同一份 `node_modules` 上交替执行 `npm install` 和 `pnpm install`；切换包管理器前先删除 `node_modules`。仓库当前忽略 `package-lock.json` 和 `pnpm-lock.yaml`，安装时应以 `package.json` 为依赖来源。

### 7.1 npm 方式

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/plus-ui

# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 构建生产资源
npm run build:prod

# 本地预览生产构建
npm run preview
```

### 7.2 pnpm 方式

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/plus-ui

# 安装依赖
pnpm install

# 启动开发服务器
pnpm run dev

# 构建生产资源
pnpm run build:prod

# 本地预览生产构建
pnpm run preview
```

两种方式都会将生产资源输出到 `plus-ui/dist/`。可用的其他前端命令：

| 功能 | npm | pnpm |
| --- | --- | --- |
| 开发环境构建 | `npm run build:dev` | `pnpm run build:dev` |
| ESLint 检查 | `npm run lint:eslint` | `pnpm run lint:eslint` |
| ESLint 自动修复 | `npm run lint:eslint:fix` | `pnpm run lint:eslint:fix` |
| Prettier 格式化 | `npm run prettier` | `pnpm run prettier` |

## 8. 日常开发

### 8.1 启动基础设施

npm 与 pnpm 管理脚本的基础设施命令行为一致，任选一套即可。以下以 npm 脚本为例：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
chmod +x manage.sh manage-pnpm.sh
./manage.sh dev-start
```

该命令只启动 MySQL、Redis 和 MinIO，并等待健康检查通过。MySQL 数据目录为空时，会自动创建 `ry-vue` 数据库并依次导入三份基线 SQL；已有数据库不会重复初始化。

### 8.2 启动后端

在 IntelliJ IDEA 的 Maven Profiles 中：

1. 选择 `dev`。
2. 取消选择 `prod`。
3. 不使用配置不完整的 `local` Profile。

完整开发环境按以下顺序运行：

```text
1. MonitorAdminApplication
2. SnailJobServerApplication
3. DromaraApplication
```

只开发普通业务接口时可以仅启动 `DromaraApplication`，但控制台可能持续出现 Monitor 和 SnailJob 连接失败后的重试日志。

### 8.3 启动前端

选择一种包管理器：

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/plus-ui

# npm
npm install
npm run dev

# 或 pnpm
pnpm install
pnpm run dev
```

前端地址以 Vite 输出为准。当前开发配置使用 `/dev-api`，由 Vite 代理到 `http://localhost:8080`。修改 Vue、TypeScript 或样式文件后通常会自动热更新。

### 8.4 查看状态与停止开发环境

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker

./manage.sh dev-status
./manage.sh dev-stop
```

`dev-stop` 只停止 MySQL、Redis 和 MinIO 容器，不删除容器和持久化数据。结束开发前还应在 IntelliJ 中停止 Java 服务，并在前端终端按 `Ctrl+C` 停止 Vite。

## 9. 完整构建与容器部署

完整部署使用 Maven `prod` Profile，并启动 Nginx、两个业务节点、Monitor、SnailJob、MySQL、Redis 和 MinIO。

### 9.1 使用 npm 构建部署

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
chmod +x manage.sh

./manage.sh start
./manage.sh status
```

`manage.sh start` 的主要流程：

1. 检查 Node.js、npm、JDK 17、Maven、Docker 与 Compose。
2. 检查并拉取缺失的固定版本基础镜像。
3. 执行 `npm install` 和 `npm run build:prod`。
4. 执行 `mvn package -Pprod -DskipTests`。
5. 构建三个后端 Docker 镜像。
6. 启动基础设施和全部应用容器。

### 9.2 使用 pnpm 构建部署

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
chmod +x manage-pnpm.sh

./manage-pnpm.sh start
./manage-pnpm.sh status
```

`manage-pnpm.sh` 与 `manage.sh` 的服务编排、后端构建、备份恢复和清理行为一致，区别仅在前端依赖安装与构建阶段：

```bash
pnpm install
pnpm run build:prod
```

### 9.3 更新、重建与停止

代码更新后使用最初选择的脚本重新部署：

```bash
# npm 路径
./manage.sh start

# 或 pnpm 路径
./manage-pnpm.sh start
```

清除前端依赖、前端产物和 Maven 构建产物，再完整重建：

```bash
./manage.sh clean
# 或
./manage-pnpm.sh clean
```

停止并删除 Compose 容器和网络，但保留 `docker-data`：

```bash
./manage.sh stop
# 或
./manage-pnpm.sh stop
```

## 10. 服务地址与端口

### 10.1 访问地址

| 服务 | 日常开发 | 完整部署 |
| --- | --- | --- |
| 前端 | Vite 输出地址 | <http://localhost/> |
| 后端 API | <http://localhost:8080/> | <http://localhost/prod-api/> |
| Monitor | <http://localhost:9090/admin/> | <http://localhost/admin/> |
| SnailJob | <http://localhost:8800/snail-job/> | <http://localhost/snail-job/> |
| MinIO 控制台 | <http://localhost:9001/> | <http://localhost:9001/> |

### 10.2 端口映射

| 主机端口 | 服务 | 用途 |
| ---: | --- | --- |
| `80` | Nginx | 前端以及 `/prod-api/`、`/admin/`、`/snail-job/` 反向代理 |
| `3306` | MySQL | 数据库连接 |
| `6379` | Redis | 缓存连接 |
| `8080` | 业务节点 1 | 开发后端或直接调试节点 1 |
| `8081` | 业务节点 2 | 直接调试节点 2 |
| `8800` | SnailJob | 调度控制台 |
| `9000` | MinIO | S3 API 与对象访问 |
| `9001` | MinIO | 管理控制台 |
| `9090` | Monitor Admin | 服务监控 |

SnailJob 内部端口 `17888`、`28080`、`28081` 只在 Compose 网络内使用。HTTPS `443` 当前未启用。

### 10.3 默认基础设施账号

| 服务 | 地址 | 用户名 | 密码 |
| --- | --- | --- | --- |
| MySQL | `localhost:3306/ry-vue` | `root` | `root` |
| Redis | `localhost:6379` | - | `ruoyi123` |
| MinIO | `localhost:9000` / `localhost:9001` | `ruoyi` | `ruoyi123` |

## 11. 管理脚本命令

`manage.sh` 和 `manage-pnpm.sh` 支持相同的命令。下表中的 `<script>` 表示二者之一。

| 命令 | 作用 | 是否影响持久化数据 |
| --- | --- | --- |
| `./<script> start` | 增量构建前后端镜像并启动全部服务 | 否 |
| `./<script> stop` | 停止并删除项目容器与网络 | 否 |
| `./<script> status` | 查看完整部署状态与访问地址 | 否 |
| `./<script> dev-start` | 启动 MySQL、Redis、MinIO | 否 |
| `./<script> dev-stop` | 停止开发基础设施容器 | 否 |
| `./<script> dev-restart` | 重启开发基础设施并等待健康 | 否 |
| `./<script> dev-status` | 查看开发基础设施状态 | 否 |
| `./<script> clean` | 清理构建产物后完整重建并启动 | 否 |
| `./<script> backup` | 备份 MySQL 和全部 `docker-data` | 否 |
| `./<script> restore-db <file>` | 覆盖恢复 `ry-vue` 数据库并清空 Redis | 是 |
| `./<script> restore-data <file>` | 替换整个 `docker-data` | 是 |
| `./<script> clean-cache` | 删除构建缓存和运行日志 | 否 |
| `./<script> clean-all [--yes]` | 删除构建缓存和全部持久化数据 | 是 |
| `./<script> help` | 显示帮助 | 否 |

示例：

```bash
./manage.sh dev-restart
./manage-pnpm.sh status
```

同一次操作应只执行其中一个脚本，不需要两个脚本都执行。

## 12. 数据持久化、备份与恢复

### 12.1 持久化目录

运行数据保存在 `RuoYi-Vue-Plus/script/docker/docker-data/`：

```text
docker-data/
├── mysql/data/       # MySQL 数据
├── redis/data/       # Redis RDB/AOF
├── minio/data/       # MinIO 对象文件
├── minio/config/     # MinIO 配置
├── nginx/log/        # Nginx 日志
├── server1/logs/     # 主服务节点 1 日志
├── server2/logs/     # 主服务节点 2 日志
├── monitor/logs/     # Monitor 日志
└── snailjob/logs/    # SnailJob 日志
```

删除或重建容器不会删除这些目录，但持久化不等于备份。

### 12.2 创建备份

以下示例使用 `manage.sh`；pnpm 用户可将其替换为 `manage-pnpm.sh`。

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker
./manage.sh backup
```

每次备份保存在 `backups/<时间戳>/`：

| 文件 | 内容 |
| --- | --- |
| `mysql-full.sql.gz` | `ry-vue` 数据库结构与全部数据 |
| `docker-data.tar.gz` | MySQL、Redis、MinIO 和容器运行数据的物理快照 |
| `SHA256SUMS` | 创建时间、MySQL 镜像版本和文件校验值 |

> [!IMPORTANT]
> 为保证物理快照一致，`backup` 会短暂停止容器，并在完成后恢复操作前正在运行的服务。它不是零停机备份。

### 12.3 恢复数据库

```bash
./manage.sh restore-db backups/20260722-180000/mysql-full.sql.gz
```

该命令覆盖当前 `ry-vue` 数据库，并清空 Redis，避免读取旧缓存。

### 12.4 恢复全部持久化数据

```bash
./manage.sh restore-data backups/20260722-180000/docker-data.tar.gz
```

该命令会替换整个 `docker-data`。如果项目恢复前没有运行，完成后再执行：

```bash
./manage.sh start
```

### 12.5 清理缓存或全部数据

只删除前端 `node_modules`、`dist`、Vite/ESLint 缓存、Maven `target` 和运行日志：

```bash
./manage.sh clean-cache
```

> [!CAUTION]
> `clean-all` 会永久删除 MySQL、Redis、MinIO 以及 `docker-data` 中的全部内容。执行前必须运行 `backup`，检查备份文件，并将重要备份复制到项目目录之外。

```bash
# 要求手动输入 DELETE
./manage.sh clean-all

# 跳过确认，仅用于已确认备份有效的自动化场景
./manage.sh clean-all --yes
```

`backups/` 已被 Git 忽略。建议将重要备份同步到其他磁盘、NAS 或异地存储。

## 13. 代码修改后的重启规则

| 修改内容 | 操作 |
| --- | --- |
| Vue、TypeScript、CSS | 等待 Vite 热更新；异常时重启 `npm run dev` 或 `pnpm run dev` |
| `package.json` | 使用当前包管理器重新安装依赖并重启 Vite |
| 普通后端 Java 代码 | 重新运行 `DromaraApplication` |
| Monitor 模块代码 | 重新运行 `MonitorAdminApplication` |
| SnailJob 模块代码 | 重新运行 `SnailJobServerApplication` |
| `pom.xml` 或 Maven 依赖 | 重新加载 Maven 项目并重启受影响服务 |
| `application-dev.yml` | 重启使用该配置的 Java 服务 |
| MySQL 表结构或初始化 SQL | 先备份，再执行迁移 SQL，并重启受影响服务 |
| Redis 或 MinIO 配置 | 执行 `dev-restart`，再重启依赖服务 |
| Compose、Nginx 或生产配置 | 重新执行所选管理脚本的 `start` |
| `manage.sh` 或 `manage-pnpm.sh` | 根据修改内容重新执行相应命令 |

提交代码前建议检查：

```bash
git status
git diff
```

不要提交 `docker-data`、`backups`、`node_modules`、`dist` 或 Maven `target`。

## 14. 常见问题与排查

### 14.1 Docker 无法访问

```bash
docker info
docker compose version
```

如果出现 `docker: command not found` 或无法连接 daemon，请启动 Docker Desktop，检查当前 Ubuntu 发行版的 WSL Integration，并在 PowerShell 执行 `wsl --shutdown` 后重试。

### 14.2 前端依赖或构建失败

```bash
node --version
npm --version
pnpm --version
```

确认 Node.js 不低于 `20.19.0`。不要在同一份 `node_modules` 中混用 npm 和 pnpm；需要切换时先执行所选管理脚本的 `clean-cache`，或在前端目录删除 `node_modules` 后重新安装。

生产构建成功后应存在：

```text
plus-ui/dist/index.html
```

### 14.3 后端构建失败

```bash
java -version
mvn -version
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus
mvn package -Pprod -DskipTests
```

确认终端、IntelliJ Project SDK 和 Maven Runner 全部使用 JDK 17。

### 14.4 查看容器状态与日志

```bash
cd ~/dev/ruoyi-vue-plus-full-stack-workspace/RuoYi-Vue-Plus/script/docker

docker compose ps
docker compose logs -f
docker compose logs -f mysql
docker compose logs -f redis
docker compose logs -f ruoyi-server1
docker compose logs -f nginx-web
docker compose config
```

### 14.5 检查端口占用

```bash
ss -lntp | grep -E ':(80|3306|6379|8080|8081|8800|9000|9001|9090)\b'
```

端口冲突时应先停止占用进程。修改 Compose 映射后，还需要同步检查 Vite 代理、Nginx 和后端配置。

## 15. 生产部署注意事项

- 当前默认账号和密码仅适用于本地开发，部署前必须全部修改。
- 正式环境通常只对外开放 `80`，配置 HTTPS 后再开放 `443`。
- `3306`、`6379`、`8080`、`8081`、`8800`、`9000`、`9001`、`9090` 应通过防火墙限制来源。
- 不要在未备份时删除 `docker-data`，也不要执行会误删 bind mount 数据的清理操作。
- 不要在 MySQL 或 MinIO 正在写入时直接复制其数据目录，应使用管理脚本创建一致性备份。
- 生产代码更新后，使用同一包管理器对应的脚本重新构建部署。
- 项目使用标准 Compose bridge 网络，不需要启用 Docker Desktop host networking。

## 16. 相关文档与协议

- [本项目 Docker 运行文档](RuoYi-Vue-Plus/script/docker/README.md)
- [RuoYi-Vue-Plus 后端说明](RuoYi-Vue-Plus/README.md)
- [plus-ui 前端说明](plus-ui/README.md)
- [RuoYi-Vue-Plus 官方文档](https://plus-doc.dromara.org)
- [pnpm 官方文档](https://pnpm.io/)
- [Docker Compose 官方文档](https://docs.docker.com/compose/)
- [Spring Boot 官方文档](https://spring.io/projects/spring-boot)

本项目遵循 [MIT](RuoYi-Vue-Plus/LICENSE) 开源协议，基于 RuoYi-Vue-Plus 5.6.2。

> 本项目仅供学习交流使用，请勿用于商业用途。
