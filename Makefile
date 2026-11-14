# Makefile
.PHONY: up down verify logs clean compare compare-84 compare-97

# デフォルトの SQL ファイルと出力先（上書き可）
SQL_FILE ?= query.sql
OUT_DIR  ?= results

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
