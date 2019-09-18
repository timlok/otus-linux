#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net  --ip 172.20.20.100 \
-it -d --hostname mysqlrouter \
--add-host mysql01:172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysql03:172.20.20.153 \
--name mysqlrouter-nosysd \
timlok/mysqlrouter-nosysd:v2 bash
#--entrypoint /opt/cluster_reconfigure.sh \
#timlok/mysqlrouter-nosysd:v2 mysqlrouter -c /etc/mysqlrouter/mysqlrouter.conf
#local/c7-nosysd-mysqlrouter bash
