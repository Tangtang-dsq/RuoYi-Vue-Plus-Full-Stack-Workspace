# 快速参考指南

## 常用命令速查表

### 开发环境

```powershell
# 启动基础服务
cd RuoYi-Vue-Plus/script/docker
docker-compose up -d mysql redis minio

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f mysql

# 停止服务
docker-compose stop
```

### 生产环境

```powershell
# 构建前端
cd plus-ui
npm run build:prod

# 构建后端
cd ../RuoYi-Vue-Plus
mvn clean package -DskipTests

# 构建 Docker 镜像
cd ruoyi-admin
docker build -t ruoyi/ruoyi-server:5.6.2 .

# 启动所有服务
cd ../script/docker
docker-compose up -d

# 查看所有容器
docker-compose ps

# 重启某个服务
docker-compose restart ruoyi-server1
```

### 备份与恢复

```powershell
# 手动备份
.\backup.ps1

# 自定义保留天数
.\backup.ps1 -RetentionDays 30

# 数据库备份
docker exec mysql mysqldump -uroot -proot ry-vue > backups/db-$(Get-Date -Format "yyyyMMdd-HHmmss").sql

# 数据库恢复
Get-Content backups/db-20260721-120000.sql | docker exec -i mysql mysql -uroot -proot ry-vue
```

### 故障排查

```powershell
# 查看容器日志
docker-compose logs -f [服务名]

# 进入容器
docker exec -it [容器名] /bin/bash

# 查看容器资源使用
docker stats

# 重启容器
docker-compose restart [服务名]

# 完全重建容器
docker-compose down
docker-compose up -d
```

## 端口映射

| 服务 | 端口 | 说明 |
|-----|------|-----|
| Nginx (前端) | 80, 443 | HTTP/HTTPS |
| MySQL | 3306 | 数据库 |
| Redis | 6379 | 缓存 |
| MinIO API | 9000 | 对象存储 API |
| MinIO Console | 9001 | 管理控制台 |
| 后端 Server1 | 8080 | 主应用服务 |
| 后端 Server2 | 8081 | 备用应用服务 |
| SnailJob | 8800, 17888 | 任务调度 |

## 目录说明

```
docker-data/
├── mysql/
│   ├── conf/     # MySQL 配置（git 管理）
│   └── data/     # MySQL 数据（不提交）
├── redis/
│   ├── conf/     # Redis 配置（git 管理）
│   └── data/     # Redis 数据（不提交）
├── minio/
│   ├── config/   # MinIO 配置（不提交）
│   └── data/     # 文件存储（不提交）
├── nginx/
│   ├── cert/     # SSL 证书（git 管理）
│   ├── conf/     # Nginx 配置（git 管理）
│   └── log/      # 访问日志（不提交）
└── server*/logs/ # 后端日志（不提交）
```

## 检查清单

### 首次部署

- [ ] 运行 `init-docker-data.ps1` 初始化目录
- [ ] 创建 `nginx.conf` 配置文件
- [ ] 构建前端：`npm run build:prod`
- [ ] 编译后端：`mvn clean package`
- [ ] 构建后端镜像
- [ ] 启动服务：`docker-compose up -d`
- [ ] 验证所有服务运行正常

### 日常维护

- [ ] 定期执行数据库备份（建议每天）
- [ ] 检查磁盘空间（`docker-data` 目录）
- [ ] 查看日志，检查异常
- [ ] 定期清理旧日志和备份文件
- [ ] 测试备份恢复流程

### 更新部署

- [ ] 拉取最新代码
- [ ] 重新构建前端：`npm run build:prod`
- [ ] 重新编译后端：`mvn clean package`
- [ ] 重新构建 Docker 镜像
- [ ] 停止旧服务：`docker-compose down`
- [ ] 启动新服务：`docker-compose up -d`
- [ ] 验证服务正常

## 常见问题

### Q: 容器启动失败？
```powershell
# 查看详细错误
docker-compose logs [服务名]

# 检查端口是否被占用
netstat -ano | findstr ":3306"
```

### Q: 前端页面 404？
- 检查 `plus-ui/dist` 目录是否存在
- 确认已执行 `npm run build:prod`
- 检查 nginx 配置文件是否正确

### Q: 后端连接数据库失败？
- 确认 MySQL 容器正在运行
- 检查后端配置文件中的数据库连接信息
- 确认网络模式为 `host`

### Q: 如何查看 MySQL 数据？
```powershell
# 进入 MySQL 容器
docker exec -it mysql mysql -uroot -proot

# 查看数据库
show databases;
use ry-vue;
show tables;
```

## 紧急恢复流程

1. **停止所有服务**
   ```powershell
   docker-compose down
   ```

2. **恢复数据**
   ```powershell
   # 恢复 docker-data 目录
   Expand-Archive backups/full-backup-xxx.zip -Force
   
   # 或恢复数据库
   Get-Content backups/db-xxx.sql | docker exec -i mysql mysql -uroot -proot ry-vue
   ```

3. **重启服务**
   ```powershell
   docker-compose up -d
   ```

4. **验证**
   ```powershell
   docker-compose ps
   docker-compose logs
   ```
