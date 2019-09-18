# docker_mysql03

запускаем контейнер local/c7-mysql-clean, но при этом, переопределяем CMD, запуская bash, а не указанное при создании образа CMD ["/usr/sbin/mysqld", "--user=mysql"]
```bash
docker run --net mysql-nosystemd-net --ip 172.20.20.153 -it -d --hostname mysql03 --add-host mysql01:172.20.20.151 --add-host mysql02:172.20.20.152 --add-host mysqlrouter:172.20.20.100 --name mysql03-nosysd local/c7-mysql-clean bash
```
для удобства, создаём файл docker_run_mysql03-nosysd.sh и можно запустить его, а не команду выше
```bash
#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net --ip 172.20.20.153 \
--add-host mysql01:172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysqlrouter:172.20.20.100 \
-it -d --hostname mysql03 \
--name mysql03-nosysd local/c7-mysql-clean bash
```
подключаемся к контейнеру
```bash
docker exec -it mysql03-nosysd bash
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
```bash
mysqlsh --uri cladmin@mysql03:3306 -p'StrongPassword!#1' -e "dba.checkInstanceConfiguration()"
```
добавляем эту ноду кластер
это не принципиально, но я делал это на [первой ноде](/flies/innodb_nosystemd/_info/docker_mysql01.md)

после добавления всех нод в кластер (у меня это выполнялось на первой ноде) выходим из контейнера и делаем коммит контейнера
```bash
docker commit -m "first commit after add node to cluster" 928efd9f6df2 timlok/mysql03-nosysd:v1
```
соответственно, после коммита запускать нужно уже последний образ timlok/mysql03-nosysd с переопределённой CMD
```bash
#!/usr/bin/env bash
docker run \
--net mysql-nosystemd-net --ip 172.20.20.153 \
--add-host mysql01:172.20.20.151 \
--add-host mysql02:172.20.20.152 \
--add-host mysqlrouter:172.20.20.100 \
-it -d --hostname mysql03 \
--name mysql03-nosysd timlok/mysql03-nosysd:v1 /usr/sbin/mysqld --user=mysql
#--name mysql03-nosysd local/c7-mysql-clean bash
```
если это делалось вместе с другими нодами, то после запуска и [настройки mysqlrouter](/flies/innodb_nosystemd/_info/docker_mysqlRouter.md) тоже необходимо сделать коммит
