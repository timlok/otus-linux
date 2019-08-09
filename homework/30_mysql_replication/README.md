# Заметки к ДЗ-30 (Mysql: развернуть базу из дампа и настроить репликацию)

## Задача:

> развернуть базу из дампа и настроить репликацию
> В материалах приложены ссылки на вагрант для репликации
> и дамп базы bet.dmp
> базу развернуть на мастере
> и настроить чтобы реплицировались таблицы
> | bookmaker |
> | competition |
> | market |
> | odds |
> | outcome
>
> * Настроить GTID репликацию
>
> варианты которые принимаются к сдаче
> - рабочий вагрантафайл
> - скрины или логи SHOW TABLES
> * конфиги
> * пример в логе изменения строки и появления строки на реплике 
>

## Решение:

Т.к. провижининг ВМ выполняется с помощью ansible, то  ansible необходим на хостовой машине. Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/30_mysql_replication) и выполняем ```vagrant up```. 

Разворачивание стенда полностью автоматизировано. В результате получаем полностью рабочий тандем серверов mysql мастер-слэйв на Percona Server 5.7. Настроена GTID репликация.

Хотел реализовать обмен файлами между ВМ с помощью общего каталога на хосте и плагина vagrant-vbguest. Но так и не удалось решить/обойти неприятную особенность, мешающую полной автоматизации провижининга - синхронизация каталогов не работает до тех пор, пока после первого запуска ВМ не будут выполнены команды ```vagrant reload``` или ```vagrant up```. Пишут, что проблема проявляется на официальных vagrant-боксах centos/7. В итоге передача дампа базы от мастера на слэйв выполняется с помощью scp.

Ошибки возникшие на слэйве:
```bash
[ERROR] Slave SQL for channel '': Error 'Can't create database 'bet'; database exists' on query. Default database: 'bet'. Query: 'CREATE DATABASE `bet`', Error_code: 1007
```
и
```bash
[ERROR] Slave SQL for channel '': Error 'Operation CREATE USER failed for 'repl'@'%'' on query. Default database: 'bet'. Query: 'CREATE USER 'repl'@'%' IDENTIFIED WITH 'mysql_native_password' AS '*ECFCB85BB5615A4AB2522A71BE1FB1FF613CC7D4'', Error_code: 1396
```
решены мною так:
```mysql
stop slave;
flush privileges;
drop database bet;
drop user 'repl'@'%';
start slave;
```



## Проверка результата репликации

На мастере:
```mysql
[root@mysqlMaster ~]# mysqlbinlog -d bet /var/lib/mysql/mysql-bin.000002
SET @@SESSION.GTID_NEXT= 'f3fdd484-b9ca-11e9-8d9b-525400261060:40'/*!*/;
# at 119526
#190808 11:12:36 server id 1  end_log_pos 119599 CRC32 0x02f23fa5       Query   thread_id=10    exec_time=0     error_code=0
SET TIMESTAMP=1565262756/*!*/;
SET @@session.foreign_key_checks=1, @@session.unique_checks=1/*!*/;
SET @@session.sql_mode=1436549152/*!*/;
BEGIN
/*!*/;
# at 119599
#190808 11:12:36 server id 1  end_log_pos 119726 CRC32 0xb7f7a275       Query   thread_id=10    exec_time=0     error_code=0
SET TIMESTAMP=1565262756/*!*/;
insert into bookmaker (id,bookmaker_name) values (1,'OTUS')
/*!*/;
# at 119726
#190808 11:12:36 server id 1  end_log_pos 119757 CRC32 0x542c06b4       Xid = 640
COMMIT/*!*/;
```
```mysql
mysql> use bet;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> show tables;
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.00 sec)

mysql> select * from bet.bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
4 rows in set (0.00 sec)

mysql> insert into bookmaker (id,bookmaker_name) values (1,'OTUS');
Query OK, 1 row affected (0.01 sec)

mysql> select * from bet.bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  1 | OTUS           |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```

На слэйве:
```mysql
[root@mysqlSlave ~]# mysqlbinlog -d bet /var/lib/mysql/mysql-bin.000002
SET @@SESSION.GTID_NEXT= 'f3fdd484-b9ca-11e9-8d9b-525400261060:40'/*!*/;
# at 1034105
#190808 11:12:36 server id 1  end_log_pos 1034178 CRC32 0x550cf13f      Query   thread_id=10    exec_time=0     error_code=0
SET TIMESTAMP=1565262756/*!*/;
SET @@session.foreign_key_checks=1, @@session.unique_checks=1/*!*/;
SET @@session.sql_mode=1436549152/*!*/;
BEGIN
/*!*/;
# at 1034178
#190808 11:12:36 server id 1  end_log_pos 1034305 CRC32 0x17c80842      Query   thread_id=10    exec_time=0     error_code=0
SET TIMESTAMP=1565262756/*!*/;
insert into bookmaker (id,bookmaker_name) values (1,'OTUS')
/*!*/;
# at 1034305
#190808 11:12:36 server id 1  end_log_pos 1034336 CRC32 0x7a3b70fe      Xid = 447
COMMIT/*!*/;
```
```mysql
mysql> use bet;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> show tables;
+---------------+
| Tables_in_bet |
+---------------+
| bookmaker     |
| competition   |
| market        |
| odds          |
| outcome       |
+---------------+
5 rows in set (0.00 sec)

mysql> select * from bet.bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  1 | OTUS           |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```
