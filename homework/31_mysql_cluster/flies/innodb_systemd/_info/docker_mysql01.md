# docker_mysql01

Запускаем контейнер local/c7-sysd-mysql-clean.
В случае контейнера с systemd, при запуске контейнера нужно монтировать тома cgroups с хоста
```bash
docker run --privileged --net mysql-net --ip 172.20.11.151 -v /sys/fs/cgroup:/sys/fs/cgroup:ro -it -d --hostname mysql01 --add-host mysql02:172.20.11.152 --add-host mysql03:172.20.11.153 --add-host mysqlRouter:172.20.11.100 --name mysql01 local/c7-sysd-mysql-clean
```
Для удобства, создаём файл docker_run_mysql01.sh и запускаем его
```bash
#!/usr/bin/env bash
docker run --privileged \
--net mysql-net --ip 172.20.11.151 \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-it -d --hostname mysql01 \
--add-host mysql02:172.20.11.152 \
--add-host mysql03:172.20.11.153 \
--add-host mysqlRouter:172.20.11.100 \
--name mysql01 local/c7-sysd-mysql-clean
```
Подключаемся к контейнеру
```bash
docker exec -it mysql01 bash
```
Меняем пароль root в mysql
```bash
TMP_PASS=$(cat /var/log/mysqld.log | grep root@localhost | awk '{ print $13 }'); echo $TMP_PASS; mysql -uroot -p$TMP_PASS --connect-expired-password -e "alter user 'root'@'localhost' identified by 'New0tus*';"
```
Подключаемся с указанным пользователем и паролем сразу к нужному серверу без интерактивного ввода пароля и создадим пользователя cladmin
```js
mysqlsh --uri root@127.0.0.1:3306 -p'New0tus*' -e "dba.configureLocalInstance(\"127.0.0.1:3306\", {password: \"New0tus*\", mycnfPath: \"/etc/my.cnf\", clusterAdmin: \"cladmin\", clusterAdminPassword: \"StrongPassword\!\#1\"})"
```
Подключимся админом кластера и проверим статус ноды
```js
mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "dba.checkInstanceConfiguration()"
```
Создадим кластер
```js
mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "cl=dba.createCluster('TestCluster', {ipWhitelist: 'mysql01,mysql02,mysql03'})"
```
Ввыходим из контейнера
```bash
exit
```
Делаем коммит контейнера (можно это сделать после окончания всех работ)
```bash
#docker commit mysql01
docker commit -m "before add other mysql-nodes" c3d7a5d7309a260543684a2dc1d5bdd94e809773f76f0b9795174811e65f8e32 timlok/mysql01-cl:v1
```
И опять логинимся в контейнер
```bash
docker exec -it mysql01 bash
```
Запускаем и настраиваем ноды [mysql02](/homework/31_mysql_cluster/flies/innodb_systemd/_info/docker_mysql02.md) и [mysql03](/homework/31_mysql_cluster/flies/innodb_systemd/_info/docker_mysql03.md)

Вторую и третью ноду добавляем в кластер (можно выполнить на любой ноде)
```js
mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' --cluster -e "cluster.addInstance('cladmin@mysql02:3306', {password: \"StrongPassword\!\#1\", ipWhitelist: 'mysql01,mysql02,mysql03'})"
mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' --cluster -e "cluster.addInstance('cladmin@mysql03:3306', {password: \"StrongPassword\!\#1\", ipWhitelist: 'mysql01,mysql02,mysql03'})"
```
Проверим статус кластера
```json
[root@mysql01 /]# mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' --cluster

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
Проверим стаус репликации
```sql
SELECT * FROM performance_schema.replication_group_members;
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| group_replication_applier | 28afa279-d49d-11e9-8939-525400261060 | mysql03     |        3306 | ONLINE       | SECONDARY   | 8.0.16         |
| group_replication_applier | 78aa74c6-d487-11e9-93b5-525400261060 | mysql02     |        3306 | ONLINE       | PRIMARY     | 8.0.16         |
| group_replication_applier | f2af24e5-d499-11e9-9cbb-525400261060 | mysql01     |        3306 | ONLINE       | SECONDARY   | 8.0.16         |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
```
Ввыходим из контейнера и делаем коммит контейнера
```bash
docker commit -m "after add all mysql-nodes" c3d7a5d7309a timlok/mysql01-cl:v2
```
После [запуска и настройки mysqlrouter](/homework/31_mysql_cluster/flies/innodb_systemd/_info/docker_mysqlRouter.md) тоже необходимо сделать коммит
```bash
docker commit -m "after add mysql-router" 58e85cd00d1f timlok/mysql01-cl:v3
```
Соответственно, после коммита запускать нужно уже последний образ
