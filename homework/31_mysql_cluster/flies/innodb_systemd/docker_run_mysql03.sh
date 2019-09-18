#!/usr/bin/env bash
docker run --privileged \
--net mysql-net --ip 172.20.11.153 \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-it -d --hostname mysql03 \
--add-host mysql01:172.20.11.151 \
--add-host mysql02:172.20.11.152 \
--add-host mysqlRouter:172.20.11.100 \
--name mysql03 timlok/mysql03-cl:v3
#--name mysql03 local/c7-sysd-mysql-clean

