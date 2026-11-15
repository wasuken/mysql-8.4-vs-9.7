# Makefile
.DEFAULT_GOAL := up
.PHONY: setup up down verify logs clean compare compare-84 compare-97

# デフォルトの SQL ファイルと出力先（上書き可）
SQL_FILE ?= query.sql
OUT_DIR  ?= results

# Sakila の取得先と保存先（上書き可）
SAKILA_URL ?= https://downloads.mysql.com/docs/sakila-db.tar.gz
SAKILA_DIR ?= data/sakila-db
SAKILA_ARCHIVE ?= data/sakila-db.tar.gz
export SAKILA_DIR

setup:
	@set -eu; \
	if [ -f "$(SAKILA_DIR)/sakila-schema.sql" ] && [ -f "$(SAKILA_DIR)/sakila-data.sql" ]; then \
	  echo "Sakila は取得済みです: $(SAKILA_DIR)"; \
	  exit 0; \
	fi; \
	mkdir -p "$$(dirname "$(SAKILA_ARCHIVE)")" "$(SAKILA_DIR)"; \
	if [ ! -f "$(SAKILA_ARCHIVE)" ]; then \
	  trap 'rm -f "$(SAKILA_ARCHIVE).tmp"' EXIT HUP INT TERM; \
	  curl -fL "$(SAKILA_URL)" -o "$(SAKILA_ARCHIVE).tmp"; \
	  mv "$(SAKILA_ARCHIVE).tmp" "$(SAKILA_ARCHIVE)"; \
	fi; \
	tar -xzf "$(SAKILA_ARCHIVE)" -C "$(SAKILA_DIR)" --strip-components=1; \
	test -f "$(SAKILA_DIR)/sakila-schema.sql"; \
	test -f "$(SAKILA_DIR)/sakila-data.sql"

up:
	docker compose up -d --build

down:
	docker compose down

verify: up
	@echo "Waiting for MySQL instances to be healthy..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' mysql84-compare 2>/dev/null)" = "healthy" ] && \
	       [ "$$(docker inspect -f '{{.State.Health.Status}}' mysql97-compare 2>/dev/null)" = "healthy" ]; do \
	  sleep 2; \
	done
	bash verify.sh

logs:
	docker compose logs -f

clean: down
	docker volume rm $$(docker volume ls -q | grep -E 'mysql(84|97)-data') 2>/dev/null || true

# ==========================================
# Hypergraph オプティマイザ比較
# ==========================================
compare: up
	@echo "Waiting for MySQL instances to be healthy..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' mysql84-compare 2>/dev/null)" = "healthy" ] && \
	       [ "$$(docker inspect -f '{{.State.Health.Status}}' mysql97-compare 2>/dev/null)" = "healthy" ]; do \
	  sleep 2; \
	done
	bash compare.sh $(SQL_FILE) $(OUT_DIR)

# 8.4 のみ / 9.7 のみを個別に実行したい場合のフック
compare-84: up
	bash compare.sh $(SQL_FILE) $(OUT_DIR)

compare-97: up
	bash compare.sh $(SQL_FILE) $(OUT_DIR)
