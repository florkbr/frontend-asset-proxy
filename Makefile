# Makefile for Caddy Frontend Asset Proxy

# Default command to run when just 'make' is typed
.DEFAULT_GOAL := help

# Variables
COMPOSE_FILE := docker-compose.yml
TEST_SCRIPT := ./test_caddy.sh

# Phony targets are targets that don't represent actual files
.PHONY: help up up-aws init-env check-aws-env down logs test clean clean-all setup-minio

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Start Minio, aws-sigv4-proxy, and Caddy in detached mode (local MinIO default)
	@echo "Starting Docker Compose services (Minio, aws-sigv4-proxy, and Caddy)..."
	podman-compose -f $(COMPOSE_FILE) up -d --remove-orphans
	@echo "Services started. Minio console: http://localhost:9001, Caddy proxy: http://localhost:8080"
	@echo "Run 'make setup-minio' if this is the first time or Minio data was cleared."

up-aws: check-aws-env ## Start Caddy + aws-sigv4-proxy targeting AWS S3 (override upstream host/port)
	@echo "Starting Caddy and aws-sigv4-proxy for AWS S3 (no MinIO)..."
	AWS_SIGV4_UPSTREAM_HOST=s3.amazonaws.com AWS_SIGV4_UPSTREAM_PORT=443 podman-compose -f $(COMPOSE_FILE) up -d --remove-orphans caddy aws-sigv4-proxy
	@echo "Services started. Caddy proxy: http://localhost:8080"

init-env: ## Create .env from env.example if missing
	@if [ ! -f .env ]; then cp env.example .env && echo ".env created from env.example"; else echo ".env already exists"; fi

check-aws-env: ## Check required AWS env vars are set
	@: $${PUSHCACHE_AWS_ACCESS_KEY_ID?"PUSHCACHE_AWS_ACCESS_KEY_ID not set"}
	@: $${PUSHCACHE_AWS_SECRET_ACCESS_KEY?"PUSHCACHE_AWS_SECRET_ACCESS_KEY not set"}
	@echo "AWS env variables present"

setup-minio: ## Remind user to configure Minio (bucket, policy, files)
	@echo "--------------------------------------------------------------------------------------"
	@echo "ACTION REQUIRED: Configure Minio (if not already done):"
	@echo "1. Go to Minio Console: http://localhost:9001 (Login: minioadmin / minioadmin)"
	@echo "2. Create bucket: 'frontend-assets'"
	@echo "3. Set 'frontend-assets' bucket Access Policy to 'Public'."
	@echo "4. Upload 'index.html' to the root of 'frontend-assets'."
	@echo "5. Upload 'edge-navigation.json' to 'frontend-assets/api/chrome-service/v1/static/stable/prod/navigation/'."
	@echo "--------------------------------------------------------------------------------------"
	@echo "Press Enter to continue after Minio setup..."
	@read

down: ## Stop Minio and Caddy services
	@echo "Stopping Docker Compose services..."
	podman-compose -f $(COMPOSE_FILE) down

logs: ## Follow logs for all services
	@echo "Following logs for all services (Ctrl+C to stop)..."
	podman-compose -f $(COMPOSE_FILE) logs -f

caddy-logs: ## Follow logs for the Caddy service
	@echo "Following logs for Caddy service (Ctrl+C to stop)..."
	podman-compose -f $(COMPOSE_FILE) logs -f caddy

minio-logs: ## Follow logs for the Minio service
	@echo "Following logs for Minio service (Ctrl+C to stop)..."
	podman-compose -f $(COMPOSE_FILE) logs -f minio

test: up setup-minio ## Start services, ensure Minio is set up, then run tests
	@echo "Running tests..."
	@if [ -x "$(TEST_SCRIPT)" ]; then \
		$(TEST_SCRIPT); \
	else \
		echo "Test script $(TEST_SCRIPT) not found or not executable. Please run 'chmod +x $(TEST_SCRIPT)'."; \
		exit 1; \
	fi
	@echo "Tests finished. Run 'make down' to stop services."

build: ## Build or rebuild the Caddy Docker image
	@echo "Building Caddy Docker image..."
	podman-compose -f $(COMPOSE_FILE) build --no-cache caddy

clean: down ## Stop and remove containers and networks
	@echo "Cleaning up (removing containers and networks)..."
	podman-compose -f $(COMPOSE_FILE) down --remove-orphans

clean-all: clean ## Stop and remove containers, networks, AND Minio data volume
	@echo "Cleaning up thoroughly (removing containers, networks, and Minio data volume)..."
	podman-compose -f $(COMPOSE_FILE) down -v --remove-orphans
	@echo "Minio data volume 'minio_data' has been removed."

