# hkai-workflow Studio — 启动指南

## 前置条件

- macOS（脚本基于 Homebrew）
- Python 3.12（通过 miniforge/conda 安装）
- Node.js + pnpm
- PostgreSQL 15：`brew install postgresql@15`
- Redis：`brew install redis`

**安装 conda 环境（首次）：**

```bash
conda create -n dify python=3.12 -c conda-forge
conda activate dify
```

---

## 快速启动

### 第一次运行：执行初始化

```bash
./scripts/dev/setup.sh
```

该脚本会依次完成：

1. 安装 Python 依赖（dify-agent + api）
2. 安装前端依赖（pnpm install）
3. 执行数据库迁移
4. 创建本地 storage 目录

### 启动所有服务

```bash
./scripts/dev/start.sh
```

启动后访问：

| 服务     | 地址                    |
|----------|-------------------------|
| 前端     | http://localhost:3000   |
| API      | http://localhost:5001   |
| PostgreSQL | localhost:5432        |
| Redis    | localhost:6379          |

按 `Ctrl+C` 停止所有服务。

### 停止服务

```bash
./scripts/dev/stop.sh
```

交互式询问是否同时停止 PostgreSQL 和 Redis。

---

## 分步启动

如需单独启动各组件：

```bash
# 1. 启动基础设施（PostgreSQL + Redis）
./scripts/dev/start-infra.sh

# 2. 启动 API 后端（端口 5001）
./scripts/dev/start-api.sh

# 3. 启动前端（端口 3000）
./scripts/dev/start-web.sh

# 4. 启动 Celery Worker（异步任务，可选）
./scripts/dev/start-worker.sh
```

---

## 环境变量

可通过以下环境变量覆盖默认配置：

| 变量             | 默认值                        | 说明                    |
|------------------|-------------------------------|-------------------------|
| `HKAI_PYTHON`    | `~/miniforge3/envs/dify/bin/python` | Python 3.12 路径   |
| `HKAI_API_PORT`  | `5001`                        | API 服务端口            |
| `HKAI_WEB_PORT`  | `3000`                        | 前端服务端口            |
| `HKAI_API_URL`   | `http://localhost:5001`       | 前端访问 API 的地址     |

示例：

```bash
HKAI_API_PORT=5002 HKAI_WEB_PORT=3001 ./scripts/dev/start.sh
```

---

## 默认数据库配置

| 参数       | 值              |
|------------|-----------------|
| Host       | localhost       |
| Port       | 5432            |
| Username   | postgres        |
| Password   | difyai123456    |
| Database   | dify            |
| Redis URL  | redis://localhost:6379/0 |

`start-infra.sh` 会自动创建 `postgres` 用户、设置密码并创建 `dify` 数据库。

---

## 常见问题

**Python 找不到**

脚本默认查找 `~/miniforge3/envs/dify/bin/python`。如路径不同，通过环境变量指定：

```bash
export HKAI_PYTHON=/path/to/python3.12
./scripts/dev/start.sh
```

**端口冲突**

```bash
HKAI_API_PORT=5002 HKAI_WEB_PORT=3001 ./scripts/dev/start.sh
```

**PostgreSQL 连接失败**

```bash
brew services list | grep postgresql   # 检查是否已启动
brew services restart postgresql@15    # 重启服务
```

**Redis 连接失败**

```bash
redis-cli ping                        # 应返回 PONG
brew services restart redis
```

---

## 代码质量

**后端：**

```bash
make format        # ruff 格式化
make lint          # 格式化 + lint
make type-check    # 类型检查
make test          # 单元测试
```

**前端：**

```bash
pnpm -C web run test    # 单元测试（Vitest）
pnpm -C web run lint    # ESLint
pnpm -C web run build   # 生产构建
```

---

## 目录结构

```
/api          — Flask 后端（Python）
/web          — Next.js 前端（TypeScript）
/dify-agent   — Agent 后端服务
/docker       — Docker Compose 配置
/scripts/dev  — 本地开发启动脚本
/storage      — 本地文件存储（自动创建）
```
