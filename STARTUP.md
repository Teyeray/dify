# hkai-workflow Studio code-server 启动指南

这份文档用于从 0 开始在受限 code-server 环境启动本项目。目标环境特点：

- 不能 `su`，通常也不依赖 `sudo` / `systemctl`
- 通过 code-server 导出的 `/proxy/{{port}}` 访问服务
- PostgreSQL 在 root 环境下启动时需要 `LD_PRELOAD` 绕过用户检查
- Redis、PostgreSQL、API、Worker、Web 都在当前用户空间启动

如果是在普通本地开发机或 Docker 环境，不需要使用这份流程。

## 端口与密码

默认值如下，后续命令都按这些值写：

```bash
PostgreSQL: localhost:5432，Unix socket: /tmp
Redis:      localhost:6379，无密码
API:        localhost:5001
Web:        localhost:3000
DB name:    dify
DB user:    postgres
DB pass:    difyai123456
```

code-server 环境里一般会有：

```bash
echo "$VSCODE_PROXY_URI"
# 形如：https://10.211.18.233/<session-id>/codeserver/proxy/{{port}}
```

前端代码会自动读取这个变量，并把浏览器侧的 Web/API 路径转换成 code-server proxy 路径。

## Step 1：创建 conda 环境

```bash
conda create -n dify python=3.12 -c conda-forge
conda activate dify
```

确认 Python：

```bash
python --version
# 应为 Python 3.12.x
```

## Step 2：安装 PostgreSQL 15 和 Redis

```bash
conda activate dify

conda install \
  -c https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge \
  postgresql=15 redis-server \
  -y
```

验证：

```bash
which initdb
initdb --version
redis-server --version
```

## Step 3：安装 Python 依赖

在项目根目录执行：

```bash
conda activate dify

pip install -e ./dify-agent
pip install -e ./api
```

## Step 4：安装前端依赖

在项目根目录执行：

```bash
pnpm install
```

## Step 5：编译 LD_PRELOAD 欺骗库

root 环境下 PostgreSQL 拒绝启动，这里用 `LD_PRELOAD` 让 PostgreSQL 看到非 root UID。服务器重启后 `/tmp` 可能清空，需要重新执行本步骤。

```bash
cat > /tmp/fake_root.c << 'EOF'
#include <unistd.h>
uid_t getuid(void)  { return 1000; }
uid_t geteuid(void) { return 1000; }
gid_t getgid(void)  { return 1000; }
gid_t getegid(void) { return 1000; }
EOF

gcc -shared -fPIC -o /tmp/fake_root.so /tmp/fake_root.c
```

## Step 6：初始化并启动 PostgreSQL

首次初始化：

```bash
mkdir -p ~/data/postgres
chown 1000:1000 ~/data/postgres

LD_PRELOAD=/tmp/fake_root.so initdb -D ~/data/postgres
```

如果 `~/data/postgres/PG_VERSION` 已存在，跳过 `initdb`。

启动 PostgreSQL：

```bash
LD_PRELOAD=/tmp/fake_root.so pg_ctl \
  -D ~/data/postgres \
  -l ~/data/postgres/logfile \
  start -o "-p 5432 -k /tmp"
```

验证：

```bash
LD_PRELOAD=/tmp/fake_root.so psql -U postgres -h /tmp -p 5432 -c "SELECT 1;"
```

创建数据库和设置密码：

```bash
LD_PRELOAD=/tmp/fake_root.so psql -U postgres -h /tmp -p 5432 << 'EOF'
ALTER USER postgres WITH PASSWORD 'difyai123456';
SELECT 'CREATE DATABASE dify'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dify')\gexec
GRANT ALL PRIVILEGES ON DATABASE dify TO postgres;
EOF
```

API 进程连接数据库时使用 `localhost:5432`。`/tmp` socket 只用于 PostgreSQL 管理命令。

## Step 7：启动 Redis

```bash
redis-server --daemonize yes --port 6379
```

验证：

```bash
redis-cli -p 6379 ping
# PONG
```

## Step 8：创建 `.env` 文件

不要直接照抄 `api/.env.example`，里面的 Redis 密码和向量库默认值不适合这个最小环境。这里创建一份干净的最小配置。

在项目根目录执行：

```bash
mkdir -p storage

cat > api/.env << 'EOF'
FLASK_APP=app.py
SECRET_KEY=code-server-dev-secret-key-change-me

DB_TYPE=postgresql
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=difyai123456
DB_DATABASE=dify

REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_USERNAME=
REDIS_PASSWORD=
REDIS_DB=0
REDIS_USE_SSL=false

CELERY_BROKER_URL=redis://localhost:6379/1
CELERY_BACKEND=redis

STORAGE_TYPE=local
STORAGE_LOCAL_PATH=../storage

CONSOLE_API_URL=http://localhost:5001
CONSOLE_WEB_URL=http://localhost:3000
CONSOLE_CORS_ALLOW_ORIGINS=*

LOG_LEVEL=INFO
EOF

cat > web/.env.local << 'EOF'
NEXT_PUBLIC_BASE_PATH=
NEXT_PUBLIC_DEPLOY_ENV=DEVELOPMENT
NEXT_PUBLIC_EDITION=SELF_HOSTED
NEXT_TELEMETRY_DISABLED=1
CONSOLE_API_URL=http://127.0.0.1:5001
EOF

if [ -n "$VSCODE_PROXY_URI" ]; then
  WEB_PROXY_PATH="$(python - << 'PY'
import os
from urllib.parse import urlparse
print(urlparse(os.environ["VSCODE_PROXY_URI"].replace("{{port}}", "3000")).path.rstrip("/"))
PY
)"
  API_PROXY_PATH="$(python - << 'PY'
import os
from urllib.parse import urlparse
print(urlparse(os.environ["VSCODE_PROXY_URI"].replace("{{port}}", "5001")).path.rstrip("/"))
PY
)"

  cat >> web/.env.local << EOF
NEXT_PUBLIC_EXTERNAL_BASE_PATH=$WEB_PROXY_PATH
NEXT_PUBLIC_API_PREFIX=$API_PROXY_PATH/console/api
NEXT_PUBLIC_PUBLIC_API_PREFIX=$API_PROXY_PATH/api
EOF
fi
```

不要在 `api/.env` 里设置 `VECTOR_STORE=weaviate`，除非你已经额外启动了对应向量库。

## Step 9：数据库迁移

```bash
conda activate dify
cd api
python -m flask upgrade-db
```

## Step 10：启动 API

新开一个终端：

```bash
conda activate dify
cd api
python -m app
```

API 固定运行在：

```text
http://localhost:5001
```

在 code-server 浏览器里访问时端口会变成 `$VSCODE_PROXY_URI` 对应的 `5001` proxy 地址。

## Step 11：启动 Celery Worker

新开一个终端：

```bash
conda activate dify
cd api
python -m celery -A celery_entrypoint.celery worker \
  -P gevent -c 1 \
  --max-tasks-per-child 50 \
  --loglevel INFO \
  -Q api_token,dataset,dataset_summary,priority_dataset,priority_pipeline,pipeline,mail,ops_trace,app_deletion,plugin,workflow_storage,conversation,workflow,schedule_poller,schedule_executor,triggered_workflow_dispatcher,trigger_refresh_publisher,trigger_refresh_executor,retention,workflow_based_app_execution
```

## Step 12：启动 Web

新开一个终端：

```bash
cd web
pnpm dev
```

如果 `$VSCODE_PROXY_URI` 存在，Step 8 会把下面这些值动态写入 `web/.env.local`：

```text
NEXT_PUBLIC_EXTERNAL_BASE_PATH=/<session-id>/codeserver/proxy/3000
NEXT_PUBLIC_API_PREFIX=/<session-id>/codeserver/proxy/5001/console/api
NEXT_PUBLIC_PUBLIC_API_PREFIX=/<session-id>/codeserver/proxy/5001/api
```

浏览器访问：

```bash
echo "${VSCODE_PROXY_URI/\{\{port\}\}/3000}"
```

如果环境没有 `$VSCODE_PROXY_URI`，先从 code-server 页面确认真实 proxy 前缀，再手动追加。不要照抄下面的占位值：

```bash
cat >> web/.env.local << 'EOF'
NEXT_PUBLIC_EXTERNAL_BASE_PATH=/your-code-server-prefix/proxy/3000
NEXT_PUBLIC_API_PREFIX=/your-code-server-prefix/proxy/5001/console/api
NEXT_PUBLIC_PUBLIC_API_PREFIX=/your-code-server-prefix/proxy/5001/api
EOF
```

## Makefile 快捷命令

上面的手动流程也可以用 Makefile 拆开执行：

```bash
make codeserver-fake-root
make codeserver-postgres-init
make codeserver-postgres-start
make codeserver-postgres-createdb
make codeserver-redis-start
make codeserver-env
make codeserver-upgrade-db
```

然后分别开三个终端：

```bash
make codeserver-start-api
make codeserver-start-worker
make codeserver-start-web
```

可覆盖变量：

```bash
make codeserver-start-web CODE_SERVER_WEB_PORT=3001
make codeserver-start-api CODE_SERVER_DB_PASSWORD=your-password
```

## 停止服务

```bash
LD_PRELOAD=/tmp/fake_root.so pg_ctl -D ~/data/postgres stop
redis-cli -p 6379 shutdown

pkill -f "python -m app"
pkill -f "celery.*worker"
pkill -f "next dev"
```

如果不能使用 `pkill`，用 `ps -ef` 找 PID 后 `kill <pid>`。

## 常见问题

### PostgreSQL 报 cannot be run as root

确认所有 PostgreSQL 管理命令前都有：

```bash
LD_PRELOAD=/tmp/fake_root.so
```

如果服务器重启过，重新执行 Step 5。

### 前端静态资源 404

确认当前 shell 有：

```bash
echo "$VSCODE_PROXY_URI"
```

如果为空，按 Step 12 手动设置 `NEXT_PUBLIC_EXTERNAL_BASE_PATH`、`NEXT_PUBLIC_API_PREFIX`、`NEXT_PUBLIC_PUBLIC_API_PREFIX`。

### API 连接 Redis 失败

本流程启动的 Redis 没有密码，因此 API 侧必须显式设置：

```bash
export REDIS_PASSWORD=
export CELERY_BROKER_URL=redis://localhost:6379/1
```

### API 尝试连接 Weaviate

不要从 `api/.env.example` 原样复制配置；其中 `VECTOR_STORE=weaviate` 需要额外服务。最小启动环境不配置向量库。
