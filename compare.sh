#!/usr/bin/env bash

run_mysql() {
  local config="$1" statement="$2" port="$PORT_97"
  case "$config" in
    84) port="$PORT_84" ;;
    97off|97on)
      statement="SET SESSION optimizer_switch='hypergraph_optimizer=${config#97}';
$statement"
      ;;
  esac
  MYSQL_PWD="$PASS" mysql -h "$HOST" -P "$port" -u "$USER" -N -B -r "$DB" -e "$statement"
}

# 標準出力と診断を分け、結果のハッシュやプランの解析に診断を混ぜない。
capture_mysql() {
  local config="$1" statement="$2" output="$3"
  local status=0
  run_mysql "$config" "$statement" > "$output" 2> "$scratch/mysql.stderr" || status=$?
  if [[ -s "$scratch/mysql.stderr" ]]; then
    {
      printf '[%s] %s\n' "$config" "$output"
      cat "$scratch/mysql.stderr"
    } >> "$raw_dir/mysql.stderr"
  fi
  if (( status != 0 )); then
    cat "$scratch/mysql.stderr" >&2
  fi
  return "$status"
}

mysql_error() {
  awk '
    NR == 1 { first = $0 }
    /^ERROR/ { first = $0; exit }
    END {
      if (first == "") first = "mysql failed"
      gsub(/[[:cntrl:]]/, " ", first)
      print "ERR:" substr(first, 1, 80)
    }
  ' "$scratch/mysql.stderr"
}

root_time() {
  awk '
    index($0, "printed elsewhere") { print "n/a(split)"; split_plan = 1; exit }
    !root_seen && /^[[:space:]]*->/ {
      root_seen = 1
      number = "[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?"
      if (match($0, "actual time=" number "[.][.]" number "[[:space:]]")) {
        elapsed = substr($0, RSTART, RLENGTH - 1)
        sub(/^.*[.][.]/, "", elapsed)
      }
    }
    END { if (!split_plan && elapsed != "") print elapsed }
  ' "$1"
}

normalize_plan() {
  sed -E '/^[[:space:]]*$/d; s/[[:blank:]]+\((cost=|actual time=)[^)]*\)//g' "$1"
}

median() {
  sort -g "$1" | awk '
    { value[NR] = $1 }
    END {
      if (NR % 2) printf "%.17g", value[(NR + 1) / 2]
      else printf "%.17g", (value[NR / 2] + value[NR / 2 + 1]) / 2
    }
  '
}

markdown_row() {
  local cell
  printf '|'
  for cell in "$@"; do
    cell=${cell//|/\\|}
    printf ' %s |' "$cell"
  done
  printf '\n'
}

worse_note() {
  local ratio="$1" plan_changed="$2" threshold="${WORSE_RATIO:-1.2}"
  if awk -v ratio="$ratio" -v threshold="$threshold" 'BEGIN { exit !(ratio > threshold) }'; then
    case "$plan_changed" in
      Y) printf '%s' 'WORSE' ;;
      N) printf '%s' 'same plan: 差はノイズの可能性' ;;
    esac
  fi
}

compare_times() {
  local off="$1" on="$2" changed="$3" ratio_raw ratio note
  local number='^[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$'
  if [[ "$off" == 'n/a(split)' || "$on" == 'n/a(split)' ]]; then
    printf '%s\n' 'n/a'
  elif [[ "$off" =~ $number && "$on" =~ $number ]]; then
    # 判定には表示用に丸める前の比を使う。
    ratio_raw=$(awk -v off="$off" -v on="$on" 'BEGIN {
      if (off == 0) print "-"
      else printf "%.17g", on / off
    }')
    if [[ "$ratio_raw" == '-' ]]; then
      printf '%s\n' '-'
    else
      ratio=$(awk -v ratio="$ratio_raw" 'BEGIN { printf "%.3f", ratio }')
      note=$(worse_note "$ratio_raw" "$changed")
      printf '%s\t%s\n' "$ratio" "$note"
    fi
  else
    printf '%s\n' '-'
  fi
}

main() {
  set -euo pipefail

  SAKILA_DIR="${SAKILA_DIR:-data/sakila-db}"
  if [[ ! -f "$SAKILA_DIR/sakila-schema.sql" || ! -f "$SAKILA_DIR/sakila-data.sql" ]]; then
    echo "ERROR: Sakila がありません。先に make setup を実行してください。" >&2
    exit 1
  fi

  HOST="127.0.0.1"
  PORT_84=3306
  PORT_97=3307
  USER="root"
  PASS="rootpass"
  DB="sakila"

  export LC_ALL=C
  SQL_INPUT="${1:-queries}"
  OUT_DIR="${2:-results}"
  WARMUP="${WARMUP:-1}"
  RUNS="${RUNS:-3}"
  WORSE_RATIO="${WORSE_RATIO:-1.2}"

  shopt -s nullglob
  sql_files=()
  if [[ -d "$SQL_INPUT" ]]; then
    for file in "$SQL_INPUT"/*.sql; do
      [[ ! -f "$file" ]] || sql_files+=("$file")
    done
  elif [[ -f "$SQL_INPUT" ]]; then
    sql_files=("$SQL_INPUT")
  fi
  if (( ${#sql_files[@]} == 0 )); then
    echo "ERROR: 比較対象の SQL ファイルがありません: $SQL_INPUT" >&2
    exit 1
  fi

  if [[ ! "$WARMUP" =~ ^[0-9]+$ || ! "$RUNS" =~ ^[0-9]+$ ||
        ! "$WORSE_RATIO" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] ||
      (( 10#$RUNS == 0 )); then
    echo "ERROR: WARMUP は非負整数、RUNS は正整数、WORSE_RATIO は非負数を指定してください。" >&2
    exit 2
  fi
  WARMUP=$((10#$WARMUP))
  RUNS=$((10#$RUNS))
  started_at=$(date '+%Y-%m-%d %H:%M:%S %z')

  version84=$(run_mysql 84 'SELECT VERSION();') || exit 1
  version97=$(run_mysql 97 'SELECT VERSION();') || exit 1

  raw_dir="$OUT_DIR/raw"
  plans_dir="$OUT_DIR/plans"
  mkdir -p "$raw_dir" "$plans_dir"
  scratch=$(mktemp -d)
  trap 'rm -rf -- "$scratch"' EXIT
  : > "$raw_dir/mysql.stderr"

  for server in 84 97; do
    analyze="$raw_dir/analyze_$server.txt"
    # ビューを除いた全テーブルを、インスタンスごとに1文で分析する。
    if capture_mysql "$server" "
    SELECT CONCAT(CHAR(96), REPLACE(TABLE_NAME, CHAR(96), REPEAT(CHAR(96), 2)), CHAR(96))
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE'
    ORDER BY TABLE_NAME;
  " "$scratch/tables"; then
      tables=$(awk '{ printf "%s%s", (NR == 1 ? "" : ", "), $0 }' "$scratch/tables")
      if [[ -n "$tables" ]]; then
        capture_mysql "$server" "ANALYZE TABLE $tables;" "$analyze" ||
          mysql_error >> "$analyze"
      else
        printf '%s\n' 'ERR:Sakila にテーブルがありません' > "$analyze"
      fi
    else
      mysql_error > "$analyze"
    fi
  done

  summary_md="$OUT_DIR/summary.md"
  summary_tsv="$OUT_DIR/summary.tsv"
  columns=(id '84 (ms)' '97off (ms)' '97on (ms)' on/off plan_changed result_match hg_used note)
  markdown_row "${columns[@]}" > "$summary_md"
  printf '| --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |\n' >> "$summary_md"
  (IFS=$'\t'; printf '%s\n' "${columns[*]}") > "$summary_tsv"

  configs=(84 97off 97on)
  local -A errors times medians plans hashes splits
  for file in "${sql_files[@]}"; do
    id=${file##*/}
    id=${id%.sql}
    sql=$(cat -- "$file")
    errors=() medians=() plans=() hashes=() splits=()
    for config in "${configs[@]}"; do
      times[$config]="$scratch/times_$config"
      : > "${times[$config]}"
    done

    # ファイル番号はウォームアップを含む通し番号。集計には本番だけを使う。
    for ((n = 1; n <= WARMUP + RUNS; n++)); do
      for config in "${configs[@]}"; do
        output="$raw_dir/${id}_${config}_$n.txt"
        if ! capture_mysql "$config" "EXPLAIN ANALYZE $sql" "$output"; then
          error=$(mysql_error)
          cat "$scratch/mysql.stderr" >> "$output"
          errors[$config]=${errors[$config]:-$error}
        elif (( n > WARMUP )); then
          elapsed=$(root_time "$output")
          if [[ "$elapsed" == 'n/a(split)' ]]; then
            splits[$config]=1
            plans[$config]=${plans[$config]:-$output}
          elif [[ -n "$elapsed" ]]; then
            printf '%s\n' "$elapsed" >> "${times[$config]}"
            plans[$config]=${plans[$config]:-$output}
          else
            errors[$config]=${errors[$config]:-ERR:最上段の actual time を取得できません}
          fi
        fi
      done
    done

    for config in "${configs[@]}"; do
      if [[ -n "${splits[$config]:-}" ]]; then
        medians[$config]='n/a(split)'
      elif [[ -n "${errors[$config]:-}" ]]; then
        medians[$config]=${errors[$config]}
      else
        medians[$config]=$(median "${times[$config]}")
      fi
    done

    diff_file="$plans_dir/$id.diff"
    if [[ -n "${plans[97off]:-}" && -n "${plans[97on]:-}" ]]; then
      normalize_plan "${plans[97off]}" > "$scratch/97off"
      normalize_plan "${plans[97on]}" > "$scratch/97on"
      diff_status=0
      diff -u --label 97off --label 97on "$scratch/97off" "$scratch/97on" > "$diff_file" ||
        diff_status=$?
      case "$diff_status" in
        0) plan_changed=N ;;
        1) plan_changed=Y ;;
        *) plan_changed=ERR ;;
      esac
    else
      : > "$diff_file"
      plan_changed=ERR
    fi

    IFS=$'\t' read -r ratio note < <(compare_times "${medians[97off]}" "${medians[97on]}" "$plan_changed")
    if (( ${#splits[@]} > 0 )); then
      note="plan split: 最上段ノードの時間は全体を表さない${note:+ / $note}"
    fi
    for config in "${configs[@]}"; do
      if [[ -z "${errors[$config]:-}${splits[$config]:-}" ]]; then
        printf -v "medians[$config]" '%.3f' "${medians[$config]}"
      fi
    done

    result_match=Y
    for config in "${configs[@]}"; do
      if capture_mysql "$config" "$sql" "$scratch/result"; then
        hash=$(sort "$scratch/result" | md5sum)
        hashes[$config]=${hash%% *}
      else
        result_match=ERR
        error=$(mysql_error)
        note="${note:+$note / }結果 $config $error"
      fi
    done
    if [[ "$result_match" == Y &&
          ( "${hashes[84]}" != "${hashes[97off]}" || "${hashes[84]}" != "${hashes[97on]}" ) ]]; then
      result_match=N
    fi

    # クエリ結果との混同を避けるため、最後のトレース集計行だけを読む。
    if capture_mysql 97on "
    SET SESSION optimizer_trace='enabled=on';
    $sql
    ;
    SELECT IF(COALESCE(MAX(INSTR(TRACE, 'Constructed hypergraph')), 0) > 0, 'Y', 'N')
    FROM information_schema.optimizer_trace;
  " "$scratch/trace"; then
      hg_used=$(awk 'END { if ($0 == "Y" || $0 == "N") print; else print "ERR" }' "$scratch/trace")
    else
      hg_used=ERR
      error=$(mysql_error)
      note="${note:+$note / }トレース $error"
    fi

    row=("$id" "${medians[84]}" "${medians[97off]}" "${medians[97on]}" "$ratio" "$plan_changed" "$result_match" "$hg_used" "$note")
    markdown_row "${row[@]}" >> "$summary_md"
    (IFS=$'\t'; printf '%s\n' "${row[*]}") >> "$summary_tsv"
  done

  printf '\nWARMUP=%s RUNS=%s WORSE_RATIO=%s 実行日時=%s MySQL 8.4=%s MySQL 9.7=%s\n' \
    "$WARMUP" "$RUNS" "$WORSE_RATIO" "$started_at" "$version84" "$version97" >> "$summary_md"
  printf '\n- n/a(split) は、実行プランが分割され、最上段ノードの時間が全体を表さないことを示します。\n' >> "$summary_md"
  printf '%s\n' '- WORSE は、97off と 97on の中央値がともに数値で、on/off が WORSE_RATIO を超え、plan_changed が Y の場合に付きます。' >> "$summary_md"
  printf '比較結果: %s\n' "$summary_md"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
