#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net --ip 172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysql03:172.20.20.153 \
--add-host mysqlrouter:172.20.20.100 \
-it -d --hostname mysql01 \
--name mysql01-nosysd timlok/mysql01-nosysd:v1 /usr/sbin/mysqld --user=mysql
#--name mysql01-nosysd local/c7-mysql-clean bash

