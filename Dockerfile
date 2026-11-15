# Dockerfile
# 公式イメージをそのまま使う。カスタマイズが必要になったらここに追記する。
ARG MYSQL_VERSION=8.4
FROM mysql:${MYSQL_VERSION}
