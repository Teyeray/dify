# Variables
DOCKER_REGISTRY=langgenius
WEB_IMAGE=$(DOCKER_REGISTRY)/dify-web
API_IMAGE=$(DOCKER_REGISTRY)/dify-api
VERSION=latest
DOCKER_DIR=docker
DOCKER_MIDDLEWARE_ENV=$(DOCKER_DIR)/middleware.env
DOCKER_MIDDLEWARE_ENV_EXAMPLE=$(DOCKER_DIR)/envs/middleware.env.example
DOCKER_MIDDLEWARE_PROJECT=dify-middlewares-dev
CODE_SERVER_PG_DATA ?= $(HOME)/data/postgres
CODE_SERVER_FAKE_ROOT_SO ?= /tmp/fake_root.so
CODE_SERVER_DB_NAME ?= dify
CODE_SERVER_DB_USER ?= postgres
CODE_SERVER_DB_PASSWORD ?= difyai123456
CODE_SERVER_PG_PORT ?= 5432
CODE_SERVER_REDIS_PORT ?= 6379
CODE_SERVER_API_PORT ?= 5001
CODE_SERVER_WEB_PORT ?= 3000
CODE_SERVER_PYTHON ?= python
CODE_SERVER_SANDBOX_PORT ?= 8194
CODE_SERVER_SANDBOX_API_KEY ?= dify-sandbox

# Default target - show help
.DEFAULT_GOAL := help

# Backend Development Environment Setup
.PHONY: dev-setup prepare-docker prepare-web prepare-api

# Dev setup target
dev-setup: prepare-docker prepare-web prepare-api
	@echo "✅ Backend development environment setup complete!"

# Step 1: Prepare Docker middleware
prepare-docker:
	@echo "🐳 Setting up Docker middleware..."
	@if [ ! -f "$(DOCKER_MIDDLEWARE_ENV)" ]; then \
		cp "$(DOCKER_MIDDLEWARE_ENV_EXAMPLE)" "$(DOCKER_MIDDLEWARE_ENV)"; \
		echo "Docker middleware.env created"; \
	else \
		echo "Docker middleware.env already exists"; \
	fi
	@cd $(DOCKER_DIR) && docker compose -f docker-compose.middleware.yaml --env-file middleware.env -p $(DOCKER_MIDDLEWARE_PROJECT) up -d
	@echo "✅ Docker middleware started"

# Step 2: Prepare web environment
prepare-web:
	@echo "🌐 Setting up web environment..."
	@cp -n web/.env.example web/.env.local 2>/dev/null || echo "Web .env.local already exists"
	@pnpm install
	@echo "✅ Web environment prepared (not started)"

# Step 3: Prepare API environment
prepare-api:
	@echo "🔧 Setting up API environment..."
	@cp -n api/.env.example api/.env 2>/dev/null || echo "API .env already exists"
	@cd api && uv sync --dev
	@cd api && uv run flask db upgrade
	@echo "✅ API environment prepared (not started)"

# Clean dev environment
dev-clean:
	@echo "⚠️  Stopping Docker containers..."
	@if [ -f "$(DOCKER_MIDDLEWARE_ENV)" ]; then \
		cd $(DOCKER_DIR) && docker compose -f docker-compose.middleware.yaml --env-file middleware.env -p $(DOCKER_MIDDLEWARE_PROJECT) down; \
	else \
		echo "Docker middleware.env does not exist, skipping compose down"; \
	fi
	@echo "🗑️  Removing volumes..."
	@rm -rf docker/volumes/db
	@rm -rf docker/volumes/mysql
	@rm -rf docker/volumes/redis
	@rm -rf docker/volumes/plugin_daemon
	@rm -rf docker/volumes/weaviate
	@rm -rf docker/volumes/sandbox/dependencies
	@rm -rf api/storage
	@echo "✅ Cleanup complete"

# Backend Code Quality Commands
format:
	@echo "🎨 Running ruff format..."
	@uv run --project api --dev ruff format ./api
	@echo "✅ Code formatting complete"

check:
	@echo "🔍 Running ruff check..."
	@uv run --project api --dev ruff check ./api
	@echo "✅ Code check complete"

lint:
	@echo "🔧 Running ruff format, check with fixes, response contract lint, import linter, and dotenv-linter..."
	@uv run --project api --dev ruff format ./api
	@uv run --project api --dev ruff check --fix ./api
	@$(MAKE) api-contract-lint
	@uv run --directory api --dev lint-imports
	@uv run --project api --dev dotenv-linter ./api/.env.example ./web/.env.example
	@echo "✅ Linting complete"

api-contract-lint:
	@echo "🔎 Linting Flask response contracts..."
	@uv run --project api --dev python api/dev/lint_response_contracts.py
	@echo "✅ Response contract lint complete"

type-check:
	@echo "📝 Running type checks (pyrefly + mypy)..."
	@./dev/pyrefly-check-local $(PATH_TO_CHECK)
	@uv --directory api run mypy --exclude-gitignore --exclude '(^|/)conftest\.py$$' --exclude 'tests/' --exclude 'migrations/' --exclude 'dev/generate_swagger_specs.py' --exclude 'dev/generate_fastopenapi_specs.py' --check-untyped-defs --disable-error-code=import-untyped .
	@echo "✅ Type checks complete"

type-check-core:
	@echo "📝 Running core type checks (pyrefly + mypy)..."
	@./dev/pyrefly-check-local $(PATH_TO_CHECK)
	@uv --directory api run mypy --exclude-gitignore --exclude '(^|/)conftest\.py$$' --exclude 'tests/' --exclude 'migrations/' --exclude 'dev/generate_swagger_specs.py' --exclude 'dev/generate_fastopenapi_specs.py' --check-untyped-defs --disable-error-code=import-untyped .
	@echo "✅ Core type checks complete"

test:
	@echo "🧪 Running backend unit tests..."
	@if [ -n "$(TARGET_TESTS)" ]; then \
		echo "Target: $(TARGET_TESTS)"; \
		uv run --project api --dev pytest $(TARGET_TESTS); \
	else \
		echo "Running backend unit tests"; \
		uv run --project api --dev pytest -p no:benchmark --timeout "$${PYTEST_TIMEOUT:-20}" -n auto \
			api/tests/unit_tests \
			api/providers/vdb/*/tests/unit_tests \
			api/providers/trace/*/tests/unit_tests \
			--ignore=api/tests/unit_tests/controllers; \
		uv run --project api --dev pytest --timeout "$${PYTEST_TIMEOUT:-20}" --cov-append \
			api/tests/unit_tests/controllers; \
	fi
	@echo "✅ Unit tests complete"

test-all:
	@echo "🧪 Running full backend test suite..."
	@if [ -n "$(TARGET_TESTS)" ]; then \
		echo "Target: $(TARGET_TESTS)"; \
		uv run --project api --dev pytest $(TARGET_TESTS); \
	else \
		echo "Running backend unit tests"; \
		uv run --project api --dev pytest -p no:benchmark --timeout "$${PYTEST_TIMEOUT:-20}" -n auto \
			api/tests/unit_tests \
			api/providers/vdb/*/tests/unit_tests \
			api/providers/trace/*/tests/unit_tests \
			--ignore=api/tests/unit_tests/controllers; \
		uv run --project api --dev pytest --timeout "$${PYTEST_TIMEOUT:-20}" --cov-append \
			api/tests/unit_tests/controllers; \
		echo "Running backend integration tests"; \
		uv run --project api --dev pytest -p no:benchmark --start-middleware -n auto \
			--timeout "$${PYTEST_TIMEOUT:-180}" \
			--cov-append \
			api/tests/integration_tests/workflow \
			api/tests/integration_tests/tools \
			api/tests/test_containers_integration_tests; \
		echo "Running VDB smoke tests"; \
		uv run --project api --dev pytest --start-vdb \
			--timeout "$${PYTEST_TIMEOUT:-180}" \
			--cov-append \
			api/providers/vdb/vdb-chroma/tests/integration_tests \
			api/providers/vdb/vdb-pgvector/tests/integration_tests \
			api/providers/vdb/vdb-qdrant/tests/integration_tests \
			api/providers/vdb/vdb-weaviate/tests/integration_tests; \
	fi
	@echo "✅ Tests complete"

# Build Docker images
build-web:
	@echo "Building web Docker image: $(WEB_IMAGE):$(VERSION)..."
	docker build -f web/Dockerfile -t $(WEB_IMAGE):$(VERSION) .
	@echo "Web Docker image built successfully: $(WEB_IMAGE):$(VERSION)"

build-api:
	@echo "Building API Docker image: $(API_IMAGE):$(VERSION)..."
	docker build -t $(API_IMAGE):$(VERSION) ./api
	@echo "API Docker image built successfully: $(API_IMAGE):$(VERSION)"

# Push Docker images
push-web:
	@echo "Pushing web Docker image: $(WEB_IMAGE):$(VERSION)..."
	docker push $(WEB_IMAGE):$(VERSION)
	@echo "Web Docker image pushed successfully: $(WEB_IMAGE):$(VERSION)"

push-api:
	@echo "Pushing API Docker image: $(API_IMAGE):$(VERSION)..."
	docker push $(API_IMAGE):$(VERSION)
	@echo "API Docker image pushed successfully: $(API_IMAGE):$(VERSION)"

# Build all images
build-all: build-web build-api

# Push all images
push-all: push-web push-api

build-push-api: build-api push-api
build-push-web: build-web push-web

# Build and push all images
build-push-all: build-all push-all
	@echo "All Docker images have been built and pushed."

# code-server restricted environment helpers
codeserver-install-project:
	@echo "Installing Python editable packages and frontend dependencies..."
	@pip install -e ./dify-agent
	@pip install -e ./api
	@pnpm install
	@echo "Project dependencies installed"

codeserver-fake-root:
	@printf '%s\n' \
		'#include <unistd.h>' \
		'uid_t getuid(void)  { return 1000; }' \
		'uid_t geteuid(void) { return 1000; }' \
		'gid_t getgid(void)  { return 1000; }' \
		'gid_t getegid(void) { return 1000; }' \
		> /tmp/fake_root.c
	@gcc -shared -fPIC -o $(CODE_SERVER_FAKE_ROOT_SO) /tmp/fake_root.c
	@echo "Built $(CODE_SERVER_FAKE_ROOT_SO)"

codeserver-postgres-init: codeserver-fake-root
	@mkdir -p $(CODE_SERVER_PG_DATA)
	@chown 1000:1000 $(CODE_SERVER_PG_DATA) 2>/dev/null || true
	@if [ -f "$(CODE_SERVER_PG_DATA)/PG_VERSION" ]; then \
		echo "PostgreSQL data directory already initialized"; \
	else \
		LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) initdb -D $(CODE_SERVER_PG_DATA); \
	fi

codeserver-postgres-start: codeserver-fake-root
	@if LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) pg_ctl -D $(CODE_SERVER_PG_DATA) status >/dev/null 2>&1; then \
		echo "PostgreSQL is already running; checking health..."; \
		LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) psql -U $(CODE_SERVER_DB_USER) -h /tmp -p $(CODE_SERVER_PG_PORT) -c "SELECT 1;" >/dev/null; \
		echo "PostgreSQL is healthy"; \
	else \
		LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) pg_ctl \
			-D $(CODE_SERVER_PG_DATA) \
			-l $(CODE_SERVER_PG_DATA)/logfile \
			start -o "-p $(CODE_SERVER_PG_PORT) -k /tmp"; \
	fi

codeserver-postgres-createdb: codeserver-fake-root
	@LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) psql -U $(CODE_SERVER_DB_USER) -h /tmp -p $(CODE_SERVER_PG_PORT) -v ON_ERROR_STOP=1 \
		-c "ALTER USER $(CODE_SERVER_DB_USER) WITH PASSWORD '$(CODE_SERVER_DB_PASSWORD)';"
	@if LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) psql -U $(CODE_SERVER_DB_USER) -h /tmp -p $(CODE_SERVER_PG_PORT) -tAc "SELECT 1 FROM pg_database WHERE datname = '$(CODE_SERVER_DB_NAME)'" | grep -q 1; then \
		echo "Database $(CODE_SERVER_DB_NAME) already exists"; \
	else \
		LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) createdb -U $(CODE_SERVER_DB_USER) -h /tmp -p $(CODE_SERVER_PG_PORT) $(CODE_SERVER_DB_NAME); \
	fi
	@LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) psql -U $(CODE_SERVER_DB_USER) -h /tmp -p $(CODE_SERVER_PG_PORT) -v ON_ERROR_STOP=1 \
		-c "GRANT ALL PRIVILEGES ON DATABASE $(CODE_SERVER_DB_NAME) TO $(CODE_SERVER_DB_USER);"

codeserver-redis-start:
	@if redis-cli -p $(CODE_SERVER_REDIS_PORT) ping >/dev/null 2>&1; then \
		echo "Redis is already running on port $(CODE_SERVER_REDIS_PORT)"; \
	else \
		redis-server --daemonize yes --port $(CODE_SERVER_REDIS_PORT); \
		redis-cli -p $(CODE_SERVER_REDIS_PORT) ping; \
	fi

codeserver-env:
	@mkdir -p storage
	@printf '%s\n' \
		'FLASK_APP=app.py' \
		'SECRET_KEY=code-server-dev-secret-key-change-me' \
		'' \
		'DB_TYPE=postgresql' \
		'DB_HOST=localhost' \
		'DB_PORT=$(CODE_SERVER_PG_PORT)' \
		'DB_USERNAME=$(CODE_SERVER_DB_USER)' \
		'DB_PASSWORD=$(CODE_SERVER_DB_PASSWORD)' \
		'DB_DATABASE=$(CODE_SERVER_DB_NAME)' \
		'' \
		'REDIS_HOST=localhost' \
		'REDIS_PORT=$(CODE_SERVER_REDIS_PORT)' \
		'REDIS_USERNAME=' \
		'REDIS_PASSWORD=' \
		'REDIS_DB=0' \
		'REDIS_USE_SSL=false' \
		'' \
		'CELERY_BROKER_URL=redis://localhost:$(CODE_SERVER_REDIS_PORT)/1' \
		'CELERY_BACKEND=redis' \
		'' \
		'STORAGE_TYPE=local' \
		'STORAGE_LOCAL_PATH=../storage' \
		'' \
		'CONSOLE_API_URL=http://localhost:$(CODE_SERVER_API_PORT)' \
		'CONSOLE_WEB_URL=http://localhost:$(CODE_SERVER_WEB_PORT)' \
		'CONSOLE_CORS_ALLOW_ORIGINS=*' \
		'' \
		'MARKETPLACE_ENABLED=false' \
		'ENABLE_CHECK_UPGRADABLE_PLUGIN_TASK=false' \
		'' \
		'CODE_EXECUTION_ENDPOINT=http://localhost:$(CODE_SERVER_SANDBOX_PORT)' \
		'CODE_EXECUTION_API_KEY=$(CODE_SERVER_SANDBOX_API_KEY)' \
		'' \
		'LOG_LEVEL=INFO' \
		> api/.env
	@printf '%s\n' \
		'NEXT_PUBLIC_BASE_PATH=' \
		'NEXT_PUBLIC_DEPLOY_ENV=DEVELOPMENT' \
		'NEXT_PUBLIC_EDITION=SELF_HOSTED' \
		'NEXT_TELEMETRY_DISABLED=1' \
		'CONSOLE_API_URL=http://127.0.0.1:$(CODE_SERVER_API_PORT)' \
		> web/.env.local
	@if [ -n "$$VSCODE_PROXY_URI" ]; then \
		web_proxy_path="$$(python -c 'import os; from urllib.parse import urlparse; print(urlparse(os.environ["VSCODE_PROXY_URI"].replace("{{port}}", "$(CODE_SERVER_WEB_PORT)")).path.rstrip("/"))')"; \
		api_proxy_path="$$(python -c 'import os; from urllib.parse import urlparse; print(urlparse(os.environ["VSCODE_PROXY_URI"].replace("{{port}}", "$(CODE_SERVER_API_PORT)")).path.rstrip("/"))')"; \
		proxy_host="$$(python -c 'import os; from urllib.parse import urlparse; print(urlparse(os.environ["VSCODE_PROXY_URI"].replace("{{port}}", "$(CODE_SERVER_WEB_PORT)")).hostname or "")')"; \
		printf '%s\n' \
			"NEXT_PUBLIC_EXTERNAL_BASE_PATH=$$web_proxy_path" \
			"NEXT_PUBLIC_API_PREFIX=$$api_proxy_path/console/api" \
			"NEXT_PUBLIC_PUBLIC_API_PREFIX=$$api_proxy_path/api" \
			"NEXT_ALLOWED_DEV_ORIGINS=$$proxy_host" \
			>> web/.env.local; \
		echo "Detected VSCODE_PROXY_URI and wrote code-server proxy paths"; \
	else \
		echo "VSCODE_PROXY_URI is empty; web/.env.local uses local paths until proxy values are added"; \
	fi
	@echo "Wrote api/.env and web/.env.local"

codeserver-upgrade-db:
	@cd api && FLASK_APP=app.py $(CODE_SERVER_PYTHON) -m flask upgrade-db

codeserver-start-api:
	@cd api && $(CODE_SERVER_PYTHON) -m app

codeserver-start-worker:
	@cd api && $(CODE_SERVER_PYTHON) -m celery -A celery_entrypoint.celery worker \
		-P gevent -c 1 \
		--max-tasks-per-child 50 \
		--loglevel INFO \
		-Q api_token,dataset,dataset_summary,priority_dataset,priority_pipeline,pipeline,mail,ops_trace,app_deletion,plugin,workflow_storage,conversation,workflow,schedule_poller,schedule_executor,triggered_workflow_dispatcher,trigger_refresh_publisher,trigger_refresh_executor,retention,workflow_based_app_execution

codeserver-start-web:
	@cd web && PORT=$(CODE_SERVER_WEB_PORT) pnpm dev

# Start all four services in the background, combined log with per-service prefixes
codeserver-start-all:
	@PYTHON=$(CODE_SERVER_PYTHON) \
	 SANDBOX_PORT=$(CODE_SERVER_SANDBOX_PORT) \
	 SANDBOX_API_KEY=$(CODE_SERVER_SANDBOX_API_KEY) \
	 API_PORT=$(CODE_SERVER_API_PORT) \
	 WEB_PORT=$(CODE_SERVER_WEB_PORT) \
	 bash scripts/dev/start-all.sh

# Stop all services started by codeserver-start-all
codeserver-stop-all:
	@bash scripts/dev/stop-all.sh

# Tail the combined log (Ctrl-C to exit)
codeserver-logs:
	@tail -f logs/codeserver.log

# Convenience aggregators for code-server — orchestrate the individual targets above

# First-time setup: build fake_root → init PG → start PG → create DB → start Redis → write envs → migrate
codeserver-setup: codeserver-postgres-init codeserver-postgres-start codeserver-postgres-createdb codeserver-redis-start codeserver-env codeserver-upgrade-db
	@echo ""
	@echo "code-server environment ready. Start each service in a separate terminal:"
	@echo "  make codeserver-start-api      # terminal 1 — Flask API"
	@echo "  make codeserver-start-worker   # terminal 2 — Celery worker"
	@echo "  make codeserver-start-web      # terminal 3 — Next.js frontend"

# Daily startup: bring PostgreSQL and Redis back up (idempotent — safe to re-run)
codeserver-infra-start: codeserver-postgres-start codeserver-redis-start
	@echo "Infrastructure is up"

# Graceful shutdown of PostgreSQL and Redis
codeserver-infra-stop:
	@echo "Stopping PostgreSQL..."
	@LD_PRELOAD=$(CODE_SERVER_FAKE_ROOT_SO) pg_ctl -D $(CODE_SERVER_PG_DATA) stop -m fast 2>/dev/null || true
	@echo "Stopping Redis..."
	@redis-cli -p $(CODE_SERVER_REDIS_PORT) shutdown nosave 2>/dev/null || true
	@echo "Infrastructure stopped"

# Minimal dev sandbox — no Docker, no isolation, dev only.
# Implements POST /v1/sandbox/run so workflow code nodes work locally.
codeserver-start-sandbox:
	@if curl -sf http://localhost:$(CODE_SERVER_SANDBOX_PORT)/health >/dev/null 2>&1; then \
		echo "Dev sandbox is already running on port $(CODE_SERVER_SANDBOX_PORT)"; \
	else \
		SANDBOX_PORT=$(CODE_SERVER_SANDBOX_PORT) \
		SANDBOX_API_KEY=$(CODE_SERVER_SANDBOX_API_KEY) \
		$(CODE_SERVER_PYTHON) scripts/dev/sandbox-server.py; \
	fi

# Help target
help:
	@echo "Development Setup Targets:"
	@echo "  make dev-setup      - Run all setup steps for backend dev environment"
	@echo "  make prepare-docker - Set up Docker middleware"
	@echo "  make prepare-web    - Set up web environment"
	@echo "  make prepare-api    - Set up API environment"
	@echo "  make dev-clean      - Stop Docker middleware containers and remove dev data"
	@echo ""
	@echo "Backend Code Quality:"
	@echo "  make format         - Format code with ruff"
	@echo "  make check          - Check code with ruff"
	@echo "  make lint           - Format, fix, and lint code (ruff, imports, dotenv)"
	@echo "  make api-contract-lint - Check Flask response docs against returned schemas"
	@echo "  make type-check     - Run type checks (pyrefly, mypy)"
	@echo "  make type-check-core - Run core type checks (pyrefly, mypy)"
	@echo "  make test           - Run backend unit tests (or TARGET_TESTS=./api/tests/<target_tests>)"
	@echo "  make test-all       - Run full backend tests, including Docker-backed suites"
	@echo ""
	@echo "Docker Build Targets:"
	@echo "  make build-web      - Build web Docker image"
	@echo "  make build-api      - Build API Docker image"
	@echo "  make build-all      - Build all Docker images"
	@echo "  make push-all       - Push all Docker images"
	@echo "  make build-push-all - Build and push all Docker images"
	@echo ""
	@echo "code-server Restricted Environment:"
	@echo "  make codeserver-install-project - Install editable Python packages and frontend deps"
	@echo "  make codeserver-fake-root       - Build /tmp/fake_root.so for PostgreSQL"
	@echo "  make codeserver-postgres-init   - Initialize PostgreSQL data under ~/data/postgres"
	@echo "  make codeserver-postgres-start  - Start PostgreSQL on localhost:5432 and /tmp socket"
	@echo "  make codeserver-postgres-createdb - Set postgres password and create dify database"
	@echo "  make codeserver-redis-start     - Start Redis on localhost:6379"
	@echo "  make codeserver-env             - Write api/.env and web/.env.local"
	@echo "  make codeserver-upgrade-db      - Run API database migrations"
	@echo "  make codeserver-setup           - First-time setup: init PG, create DB, write envs, migrate"
	@echo "  make codeserver-infra-start     - Daily startup: start PostgreSQL + Redis (idempotent)"
	@echo "  make codeserver-infra-stop      - Gracefully stop PostgreSQL + Redis"
	@echo "  make codeserver-start-all       - Start API + worker + web + sandbox in background (combined log)"
	@echo "  make codeserver-stop-all        - Stop all services started by codeserver-start-all"
	@echo "  make codeserver-logs            - Tail combined log (Ctrl-C to exit)"
	@echo "  make codeserver-start-api       - Start API  (foreground, terminal 1)"
	@echo "  make codeserver-start-worker    - Start Celery worker  (foreground, terminal 2)"
	@echo "  make codeserver-start-web       - Start Web  (foreground, terminal 3)"
	@echo "  make codeserver-start-sandbox   - Start dev sandbox  (foreground, terminal 4, optional)"

# Phony targets
.PHONY: build-web build-api push-web push-api build-all push-all build-push-all dev-setup prepare-docker prepare-web prepare-api dev-clean help format check lint api-contract-lint type-check test test-all codeserver-install-project codeserver-fake-root codeserver-postgres-init codeserver-postgres-start codeserver-postgres-createdb codeserver-redis-start codeserver-env codeserver-upgrade-db codeserver-setup codeserver-infra-start codeserver-infra-stop codeserver-start-all codeserver-stop-all codeserver-logs codeserver-start-api codeserver-start-worker codeserver-start-web codeserver-start-sandbox
