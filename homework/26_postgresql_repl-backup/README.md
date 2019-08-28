# ДЗ-26 (PostgreSQL - резервное копирование и репликация)

## Задача:

>\- Настроить hot_standby репликацию с использованием слотов
>\- Настроить правильное резервное копирование
>
>Для сдачи присылаем postgresql.conf, pg_hba.conf и recovery.conf
>А так же конфиг barman, либо скрипт резервного копирования

## Решение:

Т.к. провижининг ВМ выполняется с помощью ansible и мной использован модуль postgresql_query, то на хостовой машине необходим ansible >= 2.8.

[Конфигурационные файлы](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf) и [скрипты](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts) для проверки ДЗ расположены в [соответствующих каталогах](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files). Тем не менее, можно выкачать всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup) и выполняем ```vagrant up```. 

Разворачивание стенда полностью автоматизировано. В результате получаем полностью рабочий тандем серверов мастер-слэйв на PostgreSQL 11.5 в режиме hot_stanby репликации с использованием слотов.

В процессе выполнения провижининга pg_basebackup [выполняется](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/03_pg_basebackup/tasks/main.yml) на ведомом сервере pgsqlSlave, но я применял и [другой вариант](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/03_pg_basebackup/tasks/main.yml_with_delegate), где pg_basebackup запускается на ведущем сервере (используется fuse-sshfs).

В ansibe для исполнения плэйбуков и их заданий в определённом порядке я использовал делегирование. В частности, [плэйбук](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/04_test_replication/tasks/main.yml) с тестированием репликации запускается на pgsqlSlave, но все таски делегированы на pgsqlMaster. В частности, новая [тестовая БД demo](https://edu.postgrespro.ru/demo_small.zip) скачивается и разворачивается на ведущем сервере и с помощью репликации попадает на ведомый сервер. Возможно это не очень оптимально, но это работает.

В итоге, на pgsqlSlave:

```
2019-08-27 13:41:35.746 UTC [8903] СООБЩЕНИЕ:  работа системы БД была прервана; последний момент работы: 2019-08-27 13:41:15 UTC
2019-08-27 13:41:35.896 UTC [8903] СООБЩЕНИЕ:  переход в режим резервного сервера
2019-08-27 13:41:35.898 UTC [8903] СООБЩЕНИЕ:  запись REDO начинается со смещения 0/3000028
2019-08-27 13:41:35.900 UTC [8903] СООБЩЕНИЕ:  согласованное состояние восстановления достигнуто по смещению 0/3000130
2019-08-27 13:41:35.900 UTC [8900] СООБЩЕНИЕ:  система БД готова к подключениям в режиме "только чтение"
2019-08-27 13:41:35.933 UTC [8907] СООБЩЕНИЕ:  начало передачи журнала с главного сервера, с позиции 0/4000000 на линии времени 1
```
```
-bash-4.2$ psql -l
                                  Список баз данных
    Имя    | Владелец | Кодировка | LC_COLLATE  |  LC_CTYPE   |     Права доступа     
-----------+----------+-----------+-------------+-------------+-----------------------
 demo      | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | 
 otus_test | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | 
 postgres  | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | 
 template0 | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | =c/postgres          +
           |          |           |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | =c/postgres          +
           |          |           |             |             | postgres=CTc/postgres
(5 строк)
```

Список таблиц БД demo на pgsqlSlave:

```sql
-bash-4.2$ psql -d demo -c "SELECT table_name FROM information_schema.tables WHERE table_schema NOT IN ('information_schema','pg_catalog');"
   table_name
-----------------
 ticket_flights
 flights_v
 boarding_passes
 aircrafts
 flights
 airports
 seats
 tickets
 bookings
(9 строк)
```

На pgsqlMaster статус репликации:

```sql
postgres=# select * from pg_stat_replication;
-[ RECORD 1 ]----+------------------------------
pid              | 9043
usesysid         | 16385
usename          | repluser
application_name | walreceiver
client_addr      | 192.168.11.151
client_hostname  |
client_port      | 43402
backend_start    | 2019-08-27 13:41:35.936942+00
backend_xmin     |
state            | streaming
sent_lsn         | 0/11419748
write_lsn        | 0/11419748
flush_lsn        | 0/11419748
replay_lsn       | 0/11419748
write_lag        |
flush_lag        |
replay_lag       |
sync_priority    | 0
sync_state       | async
```



### [Конфигурационные файлы:](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf)

Для настройки ведущего сервера pgsqlMaster я использовал файл [postgresql.auto.conf](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/postgresql.auto_pgsqlMaster.conf) , то файл [postgresql.conf](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/postgresql.conf) остался дефолтным. А т.к. резервное копирование на ведомый сервер pgsqlSlave выполнялось с помощью pg_basebackup, то каталог $PGDATA на обоих серверах идентичный. На pgsqlSlave одним параметром отличается только файл [postgresql.auto.conf](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/postgresql.auto.conf) и присутствует файл [recovery.conf](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/recovery.conf).

### [Скрипты:](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts)

Полная версия [README_scripts.md](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/README_scripts.md)

- [clone_pg_basebackup.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone_pg_basebackup.sh) (автоматизированный бэкап)
  В результате выполнения полностью автоматизированного скрипта резервного копирования через pg_basebackup имеем настроенную master-slave hot_standby репликацию с использованием слотов. Этот скрипт нужно выполнять на ведущем сервере pgsqlMaster от имени пользователя postgres. pg_basebackup выполняется на мастере и в качестве каталога назначения указан $PGDATA pgsqlSlave, примонтированный на pgsqlMaster с помощью fuse-sshfs.


- [clone1.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone1.sh), [clone2.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone2.sh) (полуавтоматизированный бэкап)

  В этом варианте, $PGDATA сервера pgsqlMaster архивируется с помощью tar, через конвейер распаковывается на pgsqlSlave, а новые WAL-логи с помощью rsync дозаписываются в каталог pgsqlSlave:$PGDATA/pg_wal. Все действия нужно выполнять на ведущем сервере pgsqlMaster от имени пользователя postgres.

В итоге, получаем рабочую hot_standby репликацию с использованием слотов.