# docker_mysqlRouter

создаём новый образ из локального образа с systemd local/c7-systemd в котором устанавливаем только mysql-router и mysql-shell
[Dockerfile:](/homework/31_mysql_cluster/flies/innodb_systemd/mysqlRouter/Dockerfile)

```dockerfile
FROM local/c7-systemd
COPY mysqlrouter-cluster.service /etc/systemd/system/mysqlrouter-cluster.service
RUN rpm --import https://www.percona.com/downloads/RPM-GPG-KEY-percona; \
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
percona-release setup ps80; \
yum -y install bash percona-mysql-router percona-mysql-shell; \
yum clean all; \
rm -rf /etc/mysqlrouter/*
#systemctl daemon-reload; \
#systemctl enable mysqlrouter-cluster

CMD ["/usr/sbin/init"]
```
```bash
docker build -t local/c7-sysd-mysqlrouter .
```
запускаем контейнер local/c7-sysd-mysqlrouter
в случае контейнера с systemd, при запуске контейнера нужно монтировать тома cgroups с хоста
```bash
docker run --privileged --net mysql-net --ip 172.20.11.100 -v /sys/fs/cgroup:/sys/fs/cgroup:ro -it -d --hostname mysqlrouter --add-host mysql01:172.20.11.151 --add-host mysql02:172.20.11.152 --add-host mysql03:172.20.11.153 --name mysqlrouter local/c7-sysd-mysqlrouter
```
для удобства, создаём файл docker_run_mysqlrouter.sh и запускаем его
```bash
#!/usr/bin/env bash
docker run --privileged \
--net mysql-net --ip 172.20.11.100 \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-it -d --hostname mysqlrouter \
--add-host mysql01:172.20.11.151 \
--add-host mysql02:172.20.11.152 \
--add-host mysql03:172.20.11.153 \
--name mysqlrouter local/c7-sysd-mysqlrouter
#--name mysqlrouter timlok/mysqlrouter:v1
```
подключаемся к контейнеру
```bash
docker exec -it mysqlrouter bash
```
реконфигурируем кластер (возвращаем к жизни), если он развалился
```bash
echo -e "y\ny\n"| mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "var cluster = dba.rebootClusterFromCompleteOutage();"
```
Задача ожидания и пересборки кластера после запуска docker-compose решена созданием systemd-таймера, который срабатывает при запуске контейнера с mysqlrouter. Конечно, для использования в продуктивной среде стоит добавить проверку доступности нужных портов или выполнять пересборку только после успешного подключения по порту tcp:3306 ко всем трём нодам, но в данном случае я обошёлся банальным ожиданием в 10 секунд.

/opt/cluster_reconfigure.sh:
```bash
#!/usr/bin/env bash
sleep 10
echo -e "y\ny\n"| /usr/bin/mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "var cluster = dba.rebootClusterFromCompleteOutage();"
sleep 10
```

/usr/lib/systemd/system/cluster-reconfigure.service:
```ini
[Unit]
Description=Reconfigure MySQL InnoDB cluster

[Service]
Type=oneshot
StartLimitBurst=0
ExecStart=/opt/cluster_reconfigure.sh
```

/usr/lib/systemd/system/cluster-reconfigure.timer:
```ini
[Unit]
Description=Run cluster-reconfigure service

[Timer]
AccuracySec=1us
OnBootSec=1
Unit=cluster-reconfigure.service


[Install]
WantedBy=multi-user.target
```
```bash
systemctl daemon-reload
systemctl enable cluster-reconfigure.timer
```
В результате, в логах systemd на mysqlrouter видим, что cluster-reconfigure.timer нормально отработал
```bash
Sep 14 15:25:42 mysqlrouter systemd[1]: Starting Reconfigure MySQL InnoDB cluster...
Sep 14 15:25:52 mysqlrouter cluster_reconfigure.sh[19]: WARNING: Using a password on the command line interface can be insecure.
Sep 14 15:25:52 mysqlrouter cluster_reconfigure.sh[19]: Reconfiguring the default cluster from complete outage...
Sep 14 15:25:52 mysqlrouter cluster_reconfigure.sh[19]: The instance 'mysql02:3306' was part of the cluster configuration.
Sep 14 15:25:52 mysqlrouter cluster_reconfigure.sh[19]: The instance 'mysql03:3306' was part of the cluster configuration.
Sep 14 15:26:50 mysqlrouter cluster_reconfigure.sh[19]: The cluster was successfully rebooted.
Sep 14 15:27:00 mysqlrouter systemd[1]: Started Reconfigure MySQL InnoDB cluster.
```
проверим статус кластера
```js
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
настраиваем mysqlrouter с помощью bootstrap, при указании IP адреса или имени, необходимо указать адрес текущего RW сервера (mysql01)
```bash
[root@mysqlRouter ~]# mysqlrouter --bootstrap cladmin@mysql01:3306 --directory /etc/mysqlrouter/ --user=root
```
активируем юнит
```bash
systemctl daemon-reload
systemctl enable mysqlrouter-cluster --now
systemctl status mysqlrouter-cluster
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
docker commit -m "mysqlrouter normal connect to cluster" 3b18cb25ba7e timlok/mysqlrouter-cl:v1
```
т.к. mysql-router создаёт пользователя в БД, то после настройки mysql-router нужно сделать коммиты (обновить образы) всех нод mysql в кластере


соответственно, после коммита запускать нужно уже последний образ, например, файл docker_run_mysqlrouter.sh
```bash
#!/usr/bin/env bash
docker run --privileged \
--net mysql-net --ip 172.20.11.100 \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-it -d --hostname mysqlrouter \
--add-host mysql01:172.20.11.151 \
--add-host mysql02:172.20.11.152 \
--add-host mysql03:172.20.11.153 \
--name mysqlrouter timlok/mysqlrouter-cl:v1
#--name mysqlrouter local/c7-sysd-mysqlrouter
```
