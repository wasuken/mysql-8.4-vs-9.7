#!/usr/bin/env bash
set -euo pipefail

# 接続先定義
declare -A HOSTS=(
  ["8.4"]="127.0.0.1:3306"
  ["9.7"]="127.0.0.1:3307"
)
MYSQL_USER="root"
MYSQL_PASS="rootpass"

query() {
  local hostport="$1"
  local sql="$2"
  local host="${hostport%:*}"
  local port="${hostport#*:}"
  MYSQL_PWD="$MYSQL_PASS" mysql -h "$host" -P "$port" -u "$MYSQL_USER" -N -B -e "$sql" 2>/dev/null
}

echo "=========================================="
echo " MySQL 8.4 vs 9.7 動作検証"
echo "=========================================="

for ver in "8.4" "9.7"; do
  hp="${HOSTS[$ver]}"
  echo ""
  echo "--- MySQL $ver ($hp) ---"

  # 1. バージョン確認
  version=$(query "$hp" "SELECT VERSION();")
  echo "VERSION(): $version"

  # 2. optimizer_switch の確認
  opt=$(query "$hp" "SELECT @@optimizer_switch;")
  if echo "$opt" | grep -q "hypergraph_optimizer=on"; then
    echo "hypergraph_optimizer: ON"
  elif echo "$opt" | grep -q "hypergraph_optimizer=off"; then
    echo "hypergraph_optimizer: OFF"
  else
    echo "hypergraph_optimizer: (not present in optimizer_switch)"
  fi

  # 3. 基本 SQL 検証（DDL + DML + SELECT）
  query "$hp" "DROP DATABASE IF EXISTS verify_db; CREATE DATABASE verify_db;"
  query "$hp" "USE verify_db; CREATE TABLE t1 (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(64));"
  query "$hp" "USE verify_db; INSERT INTO t1 (name) VALUES ('alice'), ('bob');"
  count=$(query "$hp" "SELECT COUNT(*) FROM verify_db.t1;")
  echo "INSERT/SELECT count: $count (expected: 2)"

  # 4. 9.7 のみ: optimizer_trace で Hypergraph の痕跡を確認
  if [[ "$ver" == "9.7" ]]; then
    # sakila ロード後、9.7 で Hypergraph の on/off 比較
    echo "--- Hypergraph optimizer comparison (9.7) ---"
    SQL="SELECT c.name, COUNT(*) FROM rental r JOIN inventory i ON r.inventory_id=i.inventory_id JOIN film f ON i.film_id=f.film_id JOIN film_category fc ON f.film_id=fc.film_id JOIN category c ON fc.category_id=c.category_id WHERE r.rental_date >= '2005-07-01' GROUP BY c.name ORDER BY COUNT(*) DESC"

    # verify.sh の [off] セクションを一時的にこれに差し替え
    docker exec mysql97-compare mysql -uroot -prootpass -e "
    SET optimizer_trace='enabled=on';
    SET optimizer_switch='hypergraph_optimizer=on';
    SELECT COUNT(*) FROM sakila.rental;
    SELECT TRACE LIKE '%Constructed hypergraph%' AS hypergraph_used FROM information_schema.optimizer_trace;
    " 2>&1 | tail -5
  fi
done

echo ""
echo "=========================================="
echo " 検証完了"
echo "=========================================="
