# docker_mysql02

запускаем контейнер local/c7-sysd-mysql-clean
в случае контейнера с systemd, при запуске контейнера нужно монтировать тома cgroups с хоста
```bash
docker run --privileged --net mysql-net --ip 172.20.11.152 -v /sys/fs/cgroup:/sys/fs/cgroup:ro -it -d --hostname mysql02 --add-host mysql01:172.20.11.151 --add-host mysql03:172.20.11.153 --add-host mysqlRouter:172.20.11.100 --name mysql02 local/c7-sysd-mysql-clean
```
для удобства, создаём файл docker_run_mysql02.sh и запускаем его
```bash
#!/usr/bin/env bash
docker run --privileged \
--net mysql-net --ip 172.20.11.152 \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
-it -d --hostname mysql02 \
--add-host mysql01:172.20.11.151 \
--add-host mysql03:172.20.11.153 \
--add-host mysqlRouter:172.20.11.100 \
--name mysql02 local/c7-sysd-mysql-clean
```
подключаемся к контейнеру
```bash
docker exec -it mysql02 bash
```
меняем пароль root в mysql
```bash
TMP_PASS=$(cat /var/log/mysqld.log | grep root@localhost | awk '{ print $13 }'); echo $TMP_PASS; mysql -uroot -p$TMP_PASS --connect-expired-password -e "alter user 'root'@'localhost' identified by 'New0tus*';"
```
подключаемся с указанным пользователем и паролем сразу к нужному серверу без интерактивного ввода пароля и создадим пользователя cladmin
```js
mysqlsh --uri root@127.0.0.1:3306 -p'New0tus*' -e "dba.configureLocalInstance(\"127.0.0.1:3306\", {password: \"New0tus*\", mycnfPath: \"/etc/my.cnf\", clusterAdmin: \"cladmin\", clusterAdminPassword: \"StrongPassword\!\#1\"})"
```
подключимся админом кластера и проверим статус ноды
```js
mysqlsh --uri cladmin@mysql02:3306 -p'StrongPassword!#1' -e "dba.checkInstanceConfiguration()"
```
после добавления всех нод в кластер (у меня это [выполнялось на первой ноде](/homework/31_mysql_cluster/flies/innodb_systemd/_info/docker_mysql01.md)) выходим из контейнера и делаем коммит контейнера
```bash
docker commit -m "after add node to cluster" 310eddde1aa6 timlok/mysql02-cl:v2
```
после запуска и [настройки mysqlrouter](/homework/31_mysql_cluster/flies/innodb_systemd/_info/docker_mysqlRouter.md) тоже необходимо сделать коммит
```bash
[root@docker innodb]# docker commit -m "after add mysql-router" d59826c71293 timlok/mysql02-cl:v3
```
соответственно, после коммита запускать нужно уже последний образ
