#!/usr/bin/env bash
docker run --privileged \
--net mysql-net --ip 172.20.11.100 \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-it -d --hostname mysqlrouter \
--add-host mysql01:172.20.11.151 \
--add-host mysql02:172.20.11.152 \
--add-host mysql03:172.20.11.153 \
--name mysqlrouter timlok/mysqlrouter-cl:v3
#--name mysqlrouter local/c7-sysd-mysqlrouter

