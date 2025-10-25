# Mongo Single-Node ReplicaSet (Railway Ready)

单节点副本集，支持事务 / Change Streams。适配 Railway Docker Image 部署。

## 环境变量
- MONGO_INITDB_ROOT_USERNAME
- MONGO_INITDB_ROOT_PASSWORD
- RS_NAME (默认 rs0)
- AUTH (默认 true)
- MONGO_PORT (默认 27017)

## Railway 部署步骤
1. 新建 Service → Deploy from GitHub → 选择本仓库
2. Service Type: Docker Image
3. 设置环境变量
4. 在 Volumes 挂载 `/data/db`
5. 完成部署后查看 Host:Port 并使用以下连接：
   ```
   mongodb://<user>:<password>@<HOST>:<PORT>/?replicaSet=rs0&authSource=admin
   ```

## 验证
```bash
mongosh --host <HOST> --port <PORT> -u <user> -p <password> --authenticationDatabase admin --eval "db.adminCommand({ hello: 1 })"
```

## 本地运行
```bash
docker build -t mongo-single-rs .
docker run -p 27017:27017 -v $(pwd)/data:/data/db mongo-single-rs
```
