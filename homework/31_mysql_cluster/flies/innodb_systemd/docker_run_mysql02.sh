#!/usr/bin/env bash
docker run --privileged \
--net mysql-net --ip 172.20.11.152 \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-it -d --hostname mysql02 \
--add-host mysql01:172.20.11.151 \
--add-host mysql03:172.20.11.153 \
--add-host mysqlRouter:172.20.11.100 \
--name mysql02 timlok/mysql02-cl:v3
#--name mysql02 local/c7-sysd-mysql-clean
