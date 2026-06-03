# hkai-workflow Studio — code-server 启动指南

目标环境：

- Linux code-server，无 `sudo` / `su` / `systemctl`
- 通过 code-server 的 `/proxy/{{port}}` 访问各服务
- PostgreSQL 在 root 下启动需要 `LD_PRELOAD` 绕过用户检查
- 所有服务都在当前用户空间运行

本地普通开发机或 Docker 环境不需要这份流程。

---

## 默认端口与凭证

| 服务 | 地址 | 备注 |
|------|------|------|
| PostgreSQL | `localhost:5432`，Unix socket `/tmp` | 管理命令走 socket，API 走 TCP |
| Redis | `localhost:6379` | 无密码 |
| Flask API | `localhost:5001` | |
| Celery Worker | — | 无端口，连 Redis |
| Next.js Web | `localhost:3000` | |
| Dev Sandbox | `localhost:8194` | 工作流代码节点，可选 |
| DB name | `dify` | |
| DB user | `postgres` | |
| DB pass | `difyai123456` | |

所有默认值都可通过 Makefile 变量覆盖，例如：

```bash
make codeserver-start-web CODE_SERVER_WEB_PORT=3001
```

---

## 一次性安装（首次使用）

### 1. 创建 conda 环境

```bash
conda create -n dify python=3.12 -c conda-forge
conda activate dify
```

### 2. 安装 PostgreSQL 和 Redis

```bash
conda activate dify
conda install \
  -c https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge \
  postgresql=15 redis-server \
  -y
```

验证：

```bash
which initdb && initdb --version
redis-server --version
```

### 3. 安装项目依赖

```bash
# 在项目根目录
make codeserver-install-project
```

等价于：

```bash
pip install -e ./dify-agent
pip install -e ./api
pnpm install
```

### 4. 首次初始化（建库 + 写 env + 迁移）

```bash
make codeserver-setup
```

这一条命令按顺序执行：

1. 编译 `LD_PRELOAD` fake-root 库
2. 初始化 PostgreSQL 数据目录（`~/data/postgres`）
3. 启动 PostgreSQL
4. 创建 `dify` 数据库
5. 启动 Redis
6. 写入 `api/.env` 和 `web/.env.local`（自动检测 `$VSCODE_PROXY_URI`）
7. 运行数据库迁移

完成后会提示下一步：

```
code-server environment ready. Start each service in a separate terminal:
  make codeserver-start-api      # terminal 1 — Flask API
  make codeserver-start-worker   # terminal 2 — Celery worker
  make codeserver-start-web      # terminal 3 — Next.js frontend
```

---

## 日常启动

服务器重启或重新开始工作时：

```bash
# 步骤 1：重启基础设施（幂等，已运行则跳过）
make codeserver-infra-start

# 步骤 2：一键后台启动全部应用服务
make codeserver-start-all
```

启动后日志实时汇聚到 `logs/codeserver.log`，格式如下：

```
[22:42:51] [worker  ] celery@host ready.
[22:42:54] [api     ] POST /console/api/... 200
[22:42:54] [web     ] ✓ Ready in 291ms
[22:42:00] [sandbox ] listening on :8194
```

查看日志：

```bash
make codeserver-logs   # Ctrl-C 退出，日志文件保留
```

> **注意**：服务器重启后 `/tmp` 会清空，`codeserver-infra-start` 会自动重新编译 fake-root 库。

### 需要分终端调试时

也可以分别前台运行（日志直接打印到终端）：

```bash
make codeserver-start-api       # 终端 1
make codeserver-start-worker    # 终端 2
make codeserver-start-web       # 终端 3
make codeserver-start-sandbox   # 终端 4（可选）
```

---

## 停止服务

```bash
# 停止全部应用服务（按 PID 精准 kill）
make codeserver-stop-all

# 停止基础设施
make codeserver-infra-stop
```

---

## 浏览器访问

`codeserver-env` / `codeserver-setup` 会自动读取 `$VSCODE_PROXY_URI` 并写入前端代理路径。确认已写入：

```bash
grep EXTERNAL_BASE_PATH web/.env.local
# 应有类似：NEXT_PUBLIC_EXTERNAL_BASE_PATH=/<session>/codeserver/proxy/3000
```

浏览器访问地址：

```bash
echo "${VSCODE_PROXY_URI/\{\{port\}\}/3000}"
```

如果 `$VSCODE_PROXY_URI` 为空，重新 `make codeserver-env`，或手动追加到 `web/.env.local`：

```bash
cat >> web/.env.local << 'EOF'
NEXT_PUBLIC_EXTERNAL_BASE_PATH=/your-prefix/proxy/3000
NEXT_PUBLIC_API_PREFIX=/your-prefix/proxy/5001/console/api
NEXT_PUBLIC_PUBLIC_API_PREFIX=/your-prefix/proxy/5001/api
NEXT_ALLOWED_DEV_ORIGINS=your-hostname
EOF
```

---

## Makefile 目标速查

| 目标 | 说明 |
|------|------|
| `codeserver-install-project` | 安装 Python 包 + pnpm 依赖（首次） |
| `codeserver-setup` | **首次一键初始化**：建库 → 写 env → 迁移 |
| `codeserver-infra-start` | 日常启动 PostgreSQL + Redis（幂等） |
| `codeserver-infra-stop` | 优雅停止 PostgreSQL + Redis |
| `codeserver-env` | 重写 `api/.env` 和 `web/.env.local` |
| `codeserver-upgrade-db` | 运行数据库迁移 |
| `codeserver-start-api` | 启动 Flask API（前台） |
| `codeserver-start-worker` | 启动 Celery worker（前台） |
| `codeserver-start-web` | 启动 Next.js（前台） |
| `codeserver-start-sandbox` | 启动 dev sandbox（前台，可选） |

---

## 常见问题

### PostgreSQL 报 `cannot be run as root`

`/tmp/fake_root.so` 已失效（服务器重启后 `/tmp` 清空）。运行：

```bash
make codeserver-fake-root
```

或直接 `make codeserver-infra-start`（会自动重新编译）。

### 前端静态资源 404 / API 请求失败

`web/.env.local` 里的代理路径可能过期：

```bash
make codeserver-env   # 重新生成（需要 $VSCODE_PROXY_URI 存在于当前 shell）
```

然后重启 `make codeserver-start-web`。

### 工作流代码节点报 sandbox 连接失败

启动 dev sandbox：

```bash
make codeserver-start-sandbox
```

确认 `api/.env` 有：

```
CODE_EXECUTION_ENDPOINT=http://localhost:8194
CODE_EXECUTION_API_KEY=dify-sandbox
```

若没有，重新 `make codeserver-env`。

> **⚠️ dev sandbox 无安全隔离**，代码节点中的代码直接在宿主进程执行。仅用于本地开发，勿暴露到外网。

### API 连接 Redis 失败

本流程的 Redis 无密码，`api/.env` 须显式留空：

```
REDIS_PASSWORD=
CELERY_BROKER_URL=redis://localhost:6379/1
```

`make codeserver-env` 已正确写入，手动改过 `.env` 时注意检查。

---

## 手动步骤参考

如果 Makefile 不可用，以下是各步骤的等价手动命令。

<details>
<summary>展开手动步骤</summary>

### 编译 fake-root 库

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

### 初始化并启动 PostgreSQL

```bash
mkdir -p ~/data/postgres
LD_PRELOAD=/tmp/fake_root.so initdb -D ~/data/postgres

LD_PRELOAD=/tmp/fake_root.so pg_ctl \
  -D ~/data/postgres \
  -l ~/data/postgres/logfile \
  start -o "-p 5432 -k /tmp"
```

### 创建数据库

```bash
LD_PRELOAD=/tmp/fake_root.so psql -U postgres -h /tmp -p 5432 << 'EOF'
ALTER USER postgres WITH PASSWORD 'difyai123456';
SELECT 'CREATE DATABASE dify'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dify')\gexec
GRANT ALL PRIVILEGES ON DATABASE dify TO postgres;
EOF
```

### 启动 Redis

```bash
redis-server --daemonize yes --port 6379
```

### 数据库迁移

```bash
cd api && python -m flask upgrade-db
```

### 停止 PostgreSQL 和 Redis

```bash
LD_PRELOAD=/tmp/fake_root.so pg_ctl -D ~/data/postgres stop -m fast
redis-cli -p 6379 shutdown nosave
```

</details>
