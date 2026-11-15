#!/usr/bin/env bash
set -euo pipefail

# DB 接続や結果ファイルの作成より前にセットアップを確認する。
SAKILA_DIR="${SAKILA_DIR:-data/sakila-db}"
if [[ ! -f "$SAKILA_DIR/sakila-schema.sql" || ! -f "$SAKILA_DIR/sakila-data.sql" ]]; then
  echo "ERROR: Sakila がありません。先に make setup を実行してください。" >&2
  exit 1
fi

# ==========================================
# 設定
# ==========================================
HOST="127.0.0.1"
PORT_84=3306
PORT_97=3307
USER="root"
PASS="rootpass"
DB="sakila"

SQL_FILE="${1:-query.sql}"
OUT_DIR="${2:-results}"

# ==========================================
# 前提チェック
# ==========================================
if [[ ! -f "$SQL_FILE" ]]; then
  echo "ERROR: SQL file not found: $SQL_FILE" >&2
  exit 1
fi
SQL=$(cat "$SQL_FILE")

mkdir -p "$OUT_DIR"

run_mysql() {
  local port="$1"
  local sql="$2"
  MYSQL_PWD="$PASS" mysql \
    -h "$HOST" -P "$port" -u "$USER" "$DB" \
    -e "$sql" 2>&1
}

# ==========================================
# 1. MySQL 8.4（デフォルト）
# ==========================================
echo "=== MySQL 8.4 (default) ==="
{
  echo "=== MySQL 8.4 (default) ==="
  run_mysql "$PORT_84" "EXPLAIN ANALYZE $SQL"
} >"$OUT_DIR/result_84.txt"

# ==========================================
# 2. MySQL 9.7 Hypergraph OFF
# ==========================================
echo "=== MySQL 9.7 (Hypergraph OFF) ==="
{
  echo "=== MySQL 9.7 (Hypergraph OFF) ==="
  run_mysql "$PORT_97" "
    SET optimizer_switch='hypergraph_optimizer=off';
    EXPLAIN ANALYZE $SQL;
  "
} >"$OUT_DIR/result_97_off.txt"

# ==========================================
# 3. MySQL 9.7 Hypergraph ON
# ==========================================
echo "=== MySQL 9.7 (Hypergraph ON) ==="
{
  echo "=== MySQL 9.7 (Hypergraph ON) ==="
  run_mysql "$PORT_97" "
    SET optimizer_switch='hypergraph_optimizer=on';
    EXPLAIN ANALYZE $SQL;
  "
} >"$OUT_DIR/result_97_on.txt"

# ==========================================
# 4. optimizer_trace の抜粋（9.7 ON 時）
# ==========================================
echo "=== optimizer_trace excerpt (9.7 Hypergraph ON) ==="
{
  echo "=== optimizer_trace excerpt (9.7 Hypergraph ON) ==="
  run_mysql "$PORT_97" "
    SET optimizer_trace='enabled=on';
    SET optimizer_switch='hypergraph_optimizer=on';
    $SQL;
    SELECT TRACE FROM information_schema.optimizer_trace;
  " | grep -o '.\{0,80\}Constructed hypergraph.\{0,120\}' || echo "(no 'Constructed hypergraph' found)"
} >"$OUT_DIR/trace_97_on.txt"

# ==========================================
# 5. 実行時間のサマリ
# ==========================================
echo ""
echo "=== Summary (actual time of top Sort node) ==="
for f in "$OUT_DIR"/result_84.txt "$OUT_DIR"/result_97_off.txt "$OUT_DIR"/result_97_on.txt; do
  label=$(basename "$f" .txt)
  # "Sort: ... (actual time=X..Y rows=Z loops=W)" の Y を拾う
  time=$(grep -oE 'actual time=[0-9.]+\.\.[0-9.]+' "$f" | head -1 | sed -E 's/actual time=[0-9.]+\.\.([0-9.]+)/\1/')
  if [[ -n "${time:-}" ]]; then
    printf "%-20s %s ms\n" "$label" "$time"
  else
    printf "%-20s (could not parse)\n" "$label"
  fi
done

echo ""
echo "Output files:"
ls -1 "$OUT_DIR"
