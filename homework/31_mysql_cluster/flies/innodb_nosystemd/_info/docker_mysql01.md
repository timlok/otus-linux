# docker_mysql01

запускаем контейнер local/c7-mysql-clean, но при этом, переопределяем CMD, запуская bash, а не указанное при создании образа CMD ["/usr/sbin/mysqld", "--user=mysql"]
```bash
docker run --net mysql-nosystemd-net --ip 172.20.20.151 -it -d --hostname mysql01 --add-host mysql02:172.20.20.152 --add-host mysql03:172.20.20.153 --add-host mysqlrouter:172.20.20.100 --name mysql01-nosysd local/c7-mysql-clean bash
```
для удобства, создаём файл docker_run_mysql01-nosysd.sh и можно запустить его, а не команду выше
```bash
#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net --ip 172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysql03:172.20.20.153 \
--add-host mysqlrouter:172.20.20.100 \
-it -d --hostname mysql01 \
--name mysql01-nosysd local/c7-mysql-clean bash
```
подключаемся к контейнеру
```bash
docker exec -it mysql01-nosysd bash
```
в одном из терминалов screen инициализируем mysql в запущенном контейнере и запускаем mysql
```bash
/usr/sbin/mysqld --initialize --user=mysql && /usr/sbin/mysqld --user=mysql
```
меняем пароль root в mysql
```bash
TMP_PASS=$(cat /var/log/mysqld.log | grep root@localhost | awk '{ print $13 }'); echo $TMP_PASS; mysql -uroot -p$TMP_PASS --connect-expired-password -e "alter user 'root'@'localhost' identified by 'New0tus*';"
```
подключаемся с указанным пользователем и паролем сразу к нужному серверу без интерактивного ввода пароля и создадим пользователя cladmin
```bash
mysqlsh --uri root@127.0.0.1:3306 -p'New0tus*' -e "dba.configureLocalInstance(\"127.0.0.1:3306\", {password: \"New0tus*\", mycnfPath: \"/etc/my.cnf\", clusterAdmin: \"cladmin\", clusterAdminPassword: \"StrongPassword\!\#1\"})"
```
перезапускаем ранее запущенный mysql
```bash
ps aux | grep "\/usr\/sbin\/mysqld" | grep -v grep | awk ' { print $2} ' | xargs kill -15; /usr/sbin/mysqld --user=mysql &
```
подключимся админом кластера и проверим статус ноды
```js
mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "dba.checkInstanceConfiguration()"
```
создадим кластер указав в качестве ipWhitelist всю подсеть 172.20.20.0/24
```js
mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "cl=dba.createCluster('TestCluster', {ipWhitelist: '172.20.20.0/24'})"
```
выходим из контейнера
```bash
exit
```
делаем коммит контейнера (можно это сделать после окончания всех работ)
```bash
docker commit -m "before add other mysql-nodes" c3d7a5d7309a260543684a2dc1d5bdd94e809773f76f0b9795174811e65f8e32 timlok/mysql01-cl:v1
```
и опять логинимся в контейнер
```bash
docker exec -it mysql01 bash
```

запускаем и настраиваем ноды [mysql02](/homework/31_mysql_cluster/flies/innodb_nosystemd/_info/docker_mysql02.md) и [mysql03](/homework/31_mysql_cluster/flies/innodb_nosystemd/_info/docker_mysql03.md)

вторую и третью ноду добавляем в кластер (можно выполнить на любой ноде)
```bash
mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' --cluster -e "cluster.addInstance('cladmin@mysql02:3306', {password: \"StrongPassword\!\#1\", ipWhitelist: '172.20.20.0/24'})"
mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' --cluster -e "cluster.addInstance('cladmin@mysql03:3306', {password: \"StrongPassword\!\#1\", ipWhitelist: '172.20.20.0/24'})"
```
проверим статус кластера
```js
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
проверим стаус репликации, хотя кластер и не будет работать без GTID-репликации ;)
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
выходим из контейнера и делаем коммит контейнера
```bash
docker commit -m "first commit after add all nodes to cluster" 9041bb3b0a5f timlok/mysql01-nosysd:v1
```
соответственно, после коммита нужно запускать уже последний образ timlok/mysql01-nosysd с переопределённой CMD
```bash
#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net --ip 172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysql03:172.20.20.153 \
--add-host mysqlrouter:172.20.20.100 \
-it -d --hostname mysql01 \
--name mysql01-nosysd timlok/mysql01-nosysd:v1 /usr/sbin/mysqld --user=mysql
#--name mysql01-nosysd local/c7-mysql-clean bash
```

после запуска и [настройки mysqlrouter](/homework/31_mysql_cluster/flies/innodb_nosystemd/_info/docker_mysqlRouter.md) тоже необходимо сделать коммит
