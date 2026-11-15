<!-- Section layout inspired by https://architecture.md/ -->
<!--
出典: ARCHITECTURE.md Template by timajwilliams (https://github.com/timajwilliams/architecture)。
archmd により節・見出し・説明を再構成し、ID マーカーと更新ルールを追加。
SPDX-License-Identifier: Apache-2.0
ライセンス全文: https://www.apache.org/licenses/LICENSE-2.0.txt
再配布時はこの表示を保持し、Apache-2.0 全文と archmd notices の出典表示を同梱する。
この表示はテンプレート・ルールに適用され、記載対象プロジェクトのライセンスは指定しない。
-->
# Architecture Overview

<!-- arch:project-structure | Project layout | Map the main directories to their responsibilities. -->
## Project layout

- ルート: `compose.yml`・`Dockerfile`・`Makefile` が実行環境、`compare.sh`・`verify.sh`・`query.sql` が比較・検証を担当する。
- `data/`: `make setup` が取得するアーカイブと `data/sakila-db/` のスキーマ SQL・データ SQL・モデルファイル。Git 管理対象外。
- `results/`: 比較結果とトレース抜粋。ルートの `result_*.txt` にも実行結果を保存している。

<!-- arch:high-level-diagram | System map | Show the system overview and connections between major components. -->
## System map

`Makefile` → Docker Compose → `mysql84` / `mysql97` → 各専用ボリューム。ホストの `compare.sh`・`verify.sh` → mysql クライアント → 各 DB（ポート 3306 / 3307）。`query.sql` → `compare.sh` → `results/`。

<!-- arch:core-components | Components | Describe each central module and the responsibility it owns. -->
## Components

- `compare.sh`: Sakila に対して 8.4 の既定設定と 9.7 の Hypergraph OFF / ON で `EXPLAIN ANALYZE` を実行し、結果・トレース抜粋を保存して時間を集計する。比較 SQL は `query.sql`、SQL ファイルと出力先は引数で変更できる。
- `verify.sh`: バージョン、optimizer_switch、DDL / DML / SELECT、9.7 のトレースを確認する。実行ごとに `verify_db` を再作成する。
- `Makefile`: Sakila の取得・展開、起動・停止・検証・比較・ログ・ボリューム削除の入口。`compare-84` / `compare-97` も両バージョンの比較スクリプトを呼ぶ。

<!-- arch:data-stores | Data stores | Name persistent stores and their tables or collections without detailed schemas. -->
## データストア

- `sakila`: actor, address, category, city, country, customer, film, film_actor, film_category, film_text, inventory, language, payment, rental, staff, store
- `verify_db`: t1

<!-- arch:external-integrations | External services | Identify outside services and the reason each connection exists. -->
## 外部連携

`make setup` が MySQL 公式配布元から Sakila を取得する。URL と保存先は Makefile の変数で指定する。

<!-- arch:deployment-infrastructure | Build and deploy | Outline where the system runs and how changes reach it. -->
## ビルドと実行環境

`Dockerfile` は公式 `mysql` イメージを使用し、Compose が 8.4 / 9.7 を指定する。データは `mysql84-data` / `mysql97-data` に永続化する。初期 DB は `testdb`。空の DB ボリュームでは `data/sakila-db/` の SQL を読み取り専用でマウントし、スキーマ・データの順に初期投入する。既存ボリュームには自動投入しない。

<!-- arch:decisions | Key decisions | Summarize each decision and its reason in one line. -->
<!-- arch:security-considerations | Security | Summarize access boundaries and protections for sensitive information. -->
## セキュリティ

Compose とスクリプトは固定の root 認証情報を使用する。公開ポートのホスト IP 制限は設定されていないため、学習用環境として接続範囲を管理する必要がある。

<!-- arch:dev-testing-environment | Development and testing | Name essential development tools and checks and link to setup instructions. -->
## 開発と検証

Docker Compose、GNU Make、Bash（連想配列対応）、curl、tar、ホストの mysql クライアントを使用する。最初に `make setup`、続けて `make verify` → `make compare` を実行する。既存ボリュームへの投入手順は CONTRIBUTING.md を参照する。`make verify` は動作検証、`make compare` は比較を実行する。両ターゲットは DB のヘルスチェック完了を待つ。

<!-- arch:future-considerations | Roadmap and known debt | Record likely architectural changes and unresolved design constraints. -->
<!-- arch:project-identification | About this project | Identify this project, its repository and maintainers, and its last reviewed date (YYYY-MM-DD). -->
## About this project

MySQL 8.4 と 9.7 の動作および Hypergraph オプティマイザを比較する学習用リポジトリ。最終確認日: 2026-11-15。

<!-- arch:glossary | Glossary | Define local terminology that a new contributor needs to understand. -->
