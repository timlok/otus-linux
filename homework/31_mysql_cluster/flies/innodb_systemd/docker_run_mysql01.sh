#!/usr/bin/env bash
docker run --privileged \
--net mysql-net --ip 172.20.11.151 \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-it -d --hostname mysql01 \
--add-host mysql02:172.20.11.152 \
--add-host mysql03:172.20.11.153 \
--add-host mysqlRouter:172.20.11.100 \
--name mysql01 timlok/mysql01-cl:v3
#--name mysql01 local/c7-sysd-mysql-clean

