#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net --ip 172.20.20.153 \
--add-host mysql01:172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysqlrouter:172.20.20.100 \
-it -d --hostname mysql03 \
--name mysql03-nosysd timlok/mysql03-nosysd:v1 /usr/sbin/mysqld --user=mysql
#--name mysql03-nosysd local/c7-mysql-clean bash

