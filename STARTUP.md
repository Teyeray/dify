# hkai-workflow Studio — 手动启动指南

适用于服务器环境，逐步手动启动每个组件。

---

## 前置条件

- Python 3.12（conda 环境）
- Node.js + pnpm
- PostgreSQL 15 已安装并运行
- Redis 已安装并运行

---

## Step 1：创建 conda 环境

```bash
conda create -n dify python=3.12 -c conda-forge
conda activate dify
```

---

## Step 2：安装 Python 依赖

```bash
# 在项目根目录执行
pip install -e ./dify-agent
pip install -e ./api
```

---

## Step 3：安装前端依赖

```bash
# 在项目根目录执行
pnpm install
```

---

## Step 4：启动 PostgreSQL

```bash
# 启动服务（按实际环境选择）
pg_ctl start -D /your/data/dir        # 通用方式
# 或
sudo systemctl start postgresql        # systemd
```

然后创建数据库和用户：

```bash
psql -U postgres
```

```sql
ALTER USER postgres PASSWORD 'difyai123456';
CREATE DATABASE dify;
\q
```

验证：

```bash
PGPASSWORD=difyai123456 psql -U postgres -h localhost -d dify -c "SELECT 1"
```

---

## Step 5：启动 Redis

```bash
redis-server --daemonize yes          # 后台运行
# 或
sudo systemctl start redis
```

验证：

```bash
redis-cli ping    # 应返回 PONG
```

---

## Step 6：数据库迁移

```bash
conda activate dify
cd api

export FLASK_APP=app.py
export DB_HOST=localhost
export DB_PORT=5432
export DB_USERNAME=postgres
export DB_PASSWORD=difyai123456
export DB_DATABASE=dify
export REDIS_URL=redis://localhost:6379/0
export CELERY_BROKER_URL=redis://localhost:6379/0
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH=../storage

python -m flask upgrade-db
```

---

## Step 7：启动 API

新开一个终端：

```bash
conda activate dify
cd api

export FLASK_APP=app.py
export DB_HOST=localhost
export DB_PORT=5432
export DB_USERNAME=postgres
export DB_PASSWORD=difyai123456
export DB_DATABASE=dify
export REDIS_URL=redis://localhost:6379/0
export CELERY_BROKER_URL=redis://localhost:6379/0
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH=../storage
export DIFY_BIND_ADDRESS=0.0.0.0
export DIFY_PORT=5001

mkdir -p ../storage
python -m app
```

API 运行在 http://localhost:5001

---

## Step 8：启动 Celery Worker

新开一个终端：

```bash
conda activate dify
cd api

export FLASK_APP=app.py
export DB_HOST=localhost
export DB_PORT=5432
export DB_USERNAME=postgres
export DB_PASSWORD=difyai123456
export DB_DATABASE=dify
export REDIS_URL=redis://localhost:6379/0
export CELERY_BROKER_URL=redis://localhost:6379/0
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH=../storage

python -m celery -A celery_entrypoint.celery worker \
  -P gevent -c 1 \
  --max-tasks-per-child 50 \
  --loglevel INFO \
  -Q api_token,dataset,mail,pipeline,workflow,schedule_poller,schedule_executor,conversation,app_deletion
```

---

## Step 9：启动前端

新开一个终端：

```bash
cd web

export NEXT_PUBLIC_DEPLOY_ENV=PRODUCTION
export NEXT_PUBLIC_EDITION=SELF_HOSTED
export NEXT_PUBLIC_API_PREFIX=http://localhost:5001/console/api
export NEXT_PUBLIC_PUBLIC_API_PREFIX=http://localhost:5001/api
export NEXT_TELEMETRY_DISABLED=1

npx next dev --port 3000
```

前端运行在 http://localhost:3000

---

## 启动顺序总结

```
1. PostgreSQL
2. Redis
3. flask upgrade-db（只需首次或更新后执行）
4. API（python -m app）
5. Celery Worker
6. Web（npx next dev）
```

---

## 停止服务

```bash
# 停止 API 和前端
kill $(lsof -ti:5001)   # API
kill $(lsof -ti:3000)   # Web

# 停止 Worker
pkill -f "celery.*worker"

# 停止 PostgreSQL / Redis（按实际方式）
sudo systemctl stop postgresql
sudo systemctl stop redis
```
