# docker_mysqlRouter

на основе образа centos:7 создаём образ в котором устанавливаем только mysql-router и mysql-shell, ну и пакеты по мелочи
[Dockerfile:](/flies/innodb_nosystemd/mysqlRouter/Dockerfile)

```dockerfile
FROM centos:7
COPY screenrc /root/.screenrc
COPY cluster_reconfigure.sh /opt/cluster_reconfigure.sh

RUN rpm --import https://www.percona.com/downloads/RPM-GPG-KEY-percona; \
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
percona-release setup ps80; \
yum -y install bash net-tools nmap screen percona-mysql-router percona-server-client percona-mysql-shell; \
yum clean all; \
rm -rf /etc/mysqlrouter/*; \
chmod +x /opt/cluster_reconfigure.sh

CMD ["/usr/bin/bash"]
```
```bash
docker build -t local/c7-nosysd-mysqlrouter .
```

запускаем контейнер local/c7-nosysd-mysqlrouter
```bash
docker run --net mysql-nosystemd-net  --ip 172.20.20.100 -it -d --hostname mysqlrouter --add-host mysql01:172.20.20.151 --add-host mysql02:172.20.20.152 --add-host mysql03:172.20.20.153 --name mysqlrouter-nosysd --entrypoint="" local/c7-nosysd-mysqlrouter bash
```

для удобства, создаём файл docker_run_mysqlrouter-nosysd.sh и запускаем его
```bash
#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net  --ip 172.20.20.100 \
-it -d --hostname mysqlrouter \
--add-host mysql01:172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysql03:172.20.20.153 \
--name mysqlrouter-nosysd \
--entrypoint="" \
local/c7-nosysd-mysqlrouter bash
#--name mysqlrouter timlok/mysqlrouter:v1
```

подключаемся к контейнеру
```bash
docker exec -it mysqlrouter-nosysd bash
```

реконфигурируем кластер (возвращаем к жизни), если он развалился
```bash
echo -e "y\ny\n"| mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "var cluster = dba.rebootClusterFromCompleteOutage();"
```

проверим статус кластера
```bash
[root@mysql01 ~]# mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' --cluster
 MySQL  mysql01:3306 ssl  JS > cluster.status()
 {   
    "clusterName": "TestCluster",
    "defaultReplicaSet": {
        "name": "default",
        "primary": "mysql01:3306",
        "ssl": "REQUIRED",
        "status": "OK",
        "statusText": "Cluster is ONLINE and can tolerate up to ONE failure.",
        "topology": {
            "mysql01:3306": {
                "address": "mysql01:3306",
                "mode": "R/W",
                "readReplicas": {},
                "role": "HA",
                "status": "ONLINE"
            },
            "mysql02:3306": {
                "address": "mysql02:3306",
                "mode": "R/O",
                "readReplicas": {},
                "role": "HA",
                "status": "ONLINE"
            },
            "mysql03:3306": {
                "address": "mysql03:3306",
                "mode": "R/O",
                "readReplicas": {},
                "role": "HA",
                "status": "ONLINE"
            }
        },
        "topologyMode": "Single-Primary"
    },
    "groupInformationSourceMember": "mysql01:3306"
}
```

настраиваем mysql-router с помощью bootstrap, при указании IP адреса или имени, необходимо указать адрес текущего RW сервера (mysql01)
```bash
[root@mysqlRouter ~]# mysqlrouter --bootstrap cladmin@mysql01:3306 --directory /etc/mysqlrouter/ --user=root
```

лучше, конечно, бутстрапить от имени пользователя mysqlrouter и запускать потом mysqlrouter тоже лучше от этого пользователя
```bash
[root@mysqlRouter ~]# mysqlrouter --bootstrap cladmin@mysql01:3306 --directory /etc/mysqlrouter/ --user=mysqlrouter
```

запускаем mysqlrouter
```bash
mysqlrouter -c /etc/mysqlrouter/mysqlrouter.conf
```

проверим, что работает подключение к кластеру через mysqlrouter
```bash
[root@mysqlrouter ~]# echo "show databases;" | mysqlsh --sql --uri cladmin@127.0.0.1:6446 -p'StrongPassword!#1'
WARNING: Using a password on the command line interface can be insecure.
Database
information_schema
mysql
mysql_innodb_cluster_metadata
performance_schema
sys
```
или так
```sql
[root@mysqlrouter ~]# mysqlsh --uri cladmin@127.0.0.1:6446 -p'StrongPassword!#1' --sql
 MySQL  127.0.0.1:6446 ssl  SQL > show databases;
+-------------------------------+
| Database                      |
+-------------------------------+
| information_schema            |
| mysql                         |
| mysql_innodb_cluster_metadata |
| performance_schema            |
| sys                           |
+-------------------------------+
5 rows in set (0.0024 sec)
```

или так
```bash
[root@mysqlrouter ~]# mysqlsh --uri cladmin@127.0.0.1:6446 -p'StrongPassword!#1' --sql -e "show databases;"
WARNING: Using a password on the command line interface can be insecure.
Database
information_schema
mysql
mysql_innodb_cluster_metadata
performance_schema
sys
```

выходим из контейнера и делаем коммит контейнера
```bash
docker commit -m "first commit mysqlrouter" 86e06f881577 timlok/mysqlrouter-nosysd:v1
```

т.к. mysql-router создаёт пользователя в БД, то после настройки mysql-router нужно сделать коммиты (обновить образы) всех нод mysql в кластере

соответственно, после коммита запускать нужно уже последний образ timlok/mysqlrouter-nosysd
запускаем контейнер local/c7-nosysd-mysqlrouter, но при этом, задаём entrypoint "/opt/cluster_reconfigure.sh" и переопределяем CMD на "mysqlrouter -c /etc/mysqlrouter/mysqlrouter.conf"
```bash
docker run --net mysql-nosystemd-net  --ip 172.20.20.100 -it -d --hostname mysqlrouter --add-host mysql01:172.20.20.151 --add-host mysql02:172.20.20.152 --add-host mysql03:172.20.20.153 --name mysqlrouter-nosysd --entrypoint /opt/cluster_reconfigure.sh timlok/mysqlrouter-nosysd:v2 mysqlrouter -c /etc/mysqlrouter/mysqlrouter.conf
```

или тоже самое в файле docker_run_mysqlrouter-nosysd.sh
```bash
#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net  --ip 172.20.20.100 \
-it -d --hostname mysqlrouter \
--add-host mysql01:172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysql03:172.20.20.153 \
--name mysqlrouter-nosysd \
--entrypoint /opt/cluster_reconfigure.sh \
timlok/mysqlrouter-nosysd:v2 mysqlrouter -c /etc/mysqlrouter/mysqlrouter.conf
#timlok/mysqlrouter-nosysd:v1 bash
#local/c7-nosysd-mysqlrouter bash
```

в ENTRYPOINT указан скрипт [cluster_reconfigure.sh](/flies/innodb_nosystemd/mysqlRouter/cluster_reconfigure.sh), который при запуске docker-контейнера ждёт 2 минуты, пытается подключиться к каждой ноде и переконфигурировать  кластер (пересобрать кластер возможно только на RW-ноде)

выходим из контейнера и делаем коммит контейнера
```bash
docker commit -m "fix2 cluster_reconfigure.sh" 1aa18ab9c413 timlok/mysqlrouter-nosysd:v2
```
