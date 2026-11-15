# セットアップと比較

ホストに Docker Compose、GNU Make、Bash（連想配列対応）、curl、tar、mysql クライアントが必要です。

```sh
make setup
make verify
make compare
```

`make setup` は SQL が揃っていればダウンロード・展開をスキップします。アーカイブだけがあれば再利用して展開します。取得データは Git 管理対象外です。

空の DB ボリュームには Compose が Sakila を初期投入します。既存ボリュームで Sakila が未投入の場合は、`make setup` → `make up` の後、両 DB が接続可能になってから次を実行してください。既存の Sakila は再作成されます。

```sh
for port in 3306 3307; do
  MYSQL_PWD=rootpass mysql -h 127.0.0.1 -P "$port" -u root < data/sakila-db/sakila-schema.sql
  MYSQL_PWD=rootpass mysql -h 127.0.0.1 -P "$port" -u root < data/sakila-db/sakila-data.sql
done
make verify
make compare
```

URL は `SAKILA_URL`、展開先は `SAKILA_DIR`、アーカイブ保存先は `SAKILA_ARCHIVE` で上書きできます。保存先を変える場合は、後続の make コマンドにも同じ値を指定し、Git 管理対象外の場所を使用してください。スクリプトを直接実行するときは `SAKILA_DIR` を環境変数として渡します。
