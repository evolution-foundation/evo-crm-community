# =============================================================================
# Evo AI Community — Makefile
# =============================================================================
# Usage: make [target]
# Run "make help" to see all available targets.
# =============================================================================

.DEFAULT_GOAL := help

# Colors
CYAN  := \033[36m
GREEN := \033[32m
RESET := \033[0m

.PHONY: help setup start stop restart logs clean build status \
        seed seed-auth seed-crm \
        shell-auth shell-crm shell-core shell-processor shell-bot-runtime

## —— General ——————————————————————————————————————————————————————————————————

help: ## Show this help message
	@echo ""
	@echo "  $(CYAN)Evo AI Community$(RESET) — Development Commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""

## —— Setup & Lifecycle ————————————————————————————————————————————————————————

setup: ## First-time setup: copy env, build, start, seed
	@echo "$(CYAN)Setting up Evo AI Community...$(RESET)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)Created .env from .env.example$(RESET)"; \
	else \
		echo ".env already exists, skipping copy"; \
	fi
	@git submodule update --init --recursive
	docker compose build
	docker compose up -d postgres redis mailhog
	@echo "Waiting for database to be ready..."
	@until docker compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do \
		sleep 2; \
	done
	@echo "$(GREEN)Database is ready!$(RESET)"
	@$(MAKE) seed
	docker compose up -d
	@echo ""
	@echo "$(GREEN)============================================$(RESET)"
	@echo "$(GREEN)  Evo AI Community is running!$(RESET)"
	@echo "$(GREEN)============================================$(RESET)"
	@echo ""
	@echo "  Frontend:      http://localhost:5173"
	@echo "  CRM API:      http://localhost:3000"
	@echo "  Auth API:     http://localhost:3001"
	@echo "  Processor:    http://localhost:8000"
	@echo "  Core API:     http://localhost:5555"
	@echo "  Bot Runtime:  http://localhost:8080"
	@echo "  Mailhog:      http://localhost:8025"
	@echo ""
	@echo "  First access: http://localhost:5173/setup"
	@echo "  Create your admin user via the setup wizard."
	@echo ""

start: ## Start all services
	docker compose up -d

stop: ## Stop all services
	docker compose down

restart: ## Restart all services
	docker compose down
	docker compose up -d

build: ## Rebuild all service images (no cache)
	docker compose build --no-cache

status: ## Show status of all services
	docker compose ps

logs: ## Show logs (use SERVICE=name to filter, e.g. make logs SERVICE=evo-crm)
ifdef SERVICE
	docker compose logs -f $(SERVICE)
else
	docker compose logs -f
endif

clean: ## Stop services and remove all data volumes
	@echo "$(CYAN)This will delete all data (database, redis, etc). Are you sure?$(RESET)"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	docker compose down -v
	@echo "$(GREEN)Cleaned up.$(RESET)"

## —— Database & Seeds —————————————————————————————————————————————————————————

seed: seed-crm seed-auth ## Run all seeds (CRM schema first, then auth)

seed-crm: ## Create DB + load CRM master schema + mark auth migrations + seed CRM
	@echo "$(CYAN)Loading CRM schema (master)...$(RESET)"
	docker compose run --rm evo-crm bundle exec rails db:create db:schema:load
	@echo "$(CYAN)Marking auth migrations as applied...$(RESET)"
	docker compose run --rm evo-auth bundle exec rails runner \
		"Dir['db/migrate/*.rb'].sort.map { |f| File.basename(f).split('_').first }.each { |v| begin; ActiveRecord::Base.connection.schema_migration.create_version(v); rescue ActiveRecord::RecordNotUnique; end }"
	@echo "$(CYAN)Seeding CRM service...$(RESET)"
	docker compose run --rm evo-crm bundle exec rails db:seed
	@echo "$(GREEN)CRM schema loaded and seeded.$(RESET)"

seed-auth: ## Seed the Auth service (creates default user)
	@echo "$(CYAN)Seeding Auth service...$(RESET)"
	docker compose run --rm evo-auth bundle exec rails db:seed
	@echo "$(GREEN)Auth service seeded.$(RESET)"

## —— Shell Access —————————————————————————————————————————————————————————————

shell-auth: ## Open a shell in the Auth service container
	docker compose exec evo-auth bash

shell-crm: ## Open a shell in the CRM service container
	docker compose exec evo-crm bash

shell-core: ## Open a shell in the Core service container
	docker compose exec evo-core sh

shell-processor: ## Open a shell in the Processor service container
	docker compose exec evo-processor bash

shell-bot-runtime: ## Open a shell in the Bot Runtime service container
	docker compose exec evo-bot-runtime sh
