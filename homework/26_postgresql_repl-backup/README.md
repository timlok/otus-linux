# ДЗ-26 (PostgreSQL - резервное копирование и репликация)

## Задача:

>\- Настроить hot_standby репликацию с использованием слотов
>\- Настроить правильное резервное копирование
>
>Для сдачи присылаем postgresql.conf, pg_hba.conf и recovery.conf
>А так же конфиг barman, либо скрипт резервного копирования

## Решение:

Т.к. провижининг ВМ выполняется с помощью ansible и мной использован модуль postgresql_query, то на хостовой машине необходим ansible >= 2.8.

[Конфигурационные файлы](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf) и [скрипты](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts) для проверки ДЗ расположены в [соответствующих каталогах](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files). Тем не менее, можно выкачать всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup) и выполнить ```vagrant up```. 

Разворачивание стенда полностью автоматизировано. В результате получаем полностью рабочий тандем серверов мастер-слэйв на PostgreSQL 11.5 в режиме hot_stanby репликации с использованием слотов.

Плейбук для получения клона на выбор - через [pg_basebackup](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/provisioning/03_clone_with_pg_basebackup.yml) или через [barman](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/provisioning/03_clone_with_barman.yml).

При использовании плейбука [03_clone_with_pg_basebackup](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/03_clone_with_pg_basebackup/tasks/main.yml) в процессе выполнения провижининга pg_basebackup выполняется на ведомом сервере pgsqlSlave, но я применял и [другой вариант](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/03_clone_with_pg_basebackup/tasks/main.yml_with_delegate), где pg_basebackup запускается на ведущем сервере (используется fuse-sshfs).

Основная работы с barman логика достаточно простая:
  1. Настраиваем синхронизацию (архивацию) WAL-файлов. В [оффициальной документации](http://docs.pgbarman.org/release/2.9/) есть много способов для этого. Я настраивал с помощью "Streaming backup".
  2. Делаем бэкап.
  3. Восстанавливаем бэкап куда нужно.


Плейбук клонирования ведущего сервера с помощью barman [03_clone_with_barman](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/03_clone_with_barman/tasks/main.yml) выполняется на ведомом сервере pgsqlSlave. Бэкап выполняется на сервер pgsqlSlave и там же и хранится. Конечно, в продуктивной среде стоит задействовать отдельный сервер для barman и хранения резервных копий. Данный плейбук повторяет функционал скрипта [clone_barman.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone_barman.sh).

В ansibe для исполнения плейбуков и их заданий в определённом порядке я использовал делегирование. В частности, [плейбук](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/04_test_replication/tasks/main.yml) с тестированием репликации запускается на pgsqlSlave, но все таски делегированы на pgsqlMaster. В частности, новая [тестовая БД demo](https://edu.postgrespro.ru/demo_small.zip) скачивается и разворачивается на ведущем сервере и с помощью репликации попадает на ведомый сервер. Возможно это не очень оптимально, но это работает.

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

На pgsqlMaster статус репликации при использовании только pg_basebackup:

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

На pgsqlMaster при использовании barman видим две репликации - одна для синхронизации WAL-файлов с помощью barman, вторая для синхронизации БД средствами самой postgresql:

```sql
postgres=# select * from pg_stat_replication;
-[ RECORD 1 ]----+------------------------------
pid              | 5332
usesysid         | 16388
usename          | streaming_barman
application_name | barman_receive_wal
client_addr      | 192.168.11.151
client_hostname  | pgsqlSlave
client_port      | 41474
backend_start    | 2019-09-01 13:22:02.598421+00
backend_xmin     |
state            | streaming
sent_lsn         | 0/90001E0
write_lsn        | 0/90001E0
flush_lsn        | 0/9000000
replay_lsn       |
write_lag        | 00:00:03.813227
flush_lag        | 01:51:12.858936
replay_lag       | 02:43:39.35082
sync_priority    | 0
sync_state       | async
-[ RECORD 2 ]----+------------------------------
pid              | 14490
usesysid         | 16385
usename          | repluser
application_name | walreceiver
client_addr      | 192.168.11.151
client_hostname  | pgsqlSlave
client_port      | 41494
backend_start    | 2019-09-01 16:04:23.835459+00
backend_xmin     |
state            | streaming
sent_lsn         | 0/90001E0
write_lsn        | 0/90001E0
flush_lsn        | 0/90001E0
replay_lsn       | 0/90001E0
write_lag        |
flush_lag        |
replay_lag       |
sync_priority    | 0
sync_state       | async
```

### [Конфигурационные файлы:](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf)

Для настройки ведущего сервера pgsqlMaster я использовал файл [postgresql.auto.conf](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/postgresql.auto_pgsqlMaster.conf) , поэтому файл [postgresql.conf](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/postgresql.conf) остался дефолтным. А т.к. резервное копирование на ведомый сервер pgsqlSlave выполнялось с помощью pg_basebackup и barrman, то каталог $PGDATA на обоих серверах практически идентичный. На pgsqlSlave одним параметром отличается только файл [postgresql.auto.conf](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/postgresql.auto.conf) и присутствует файл [recovery.conf](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/recovery_pg_basebackup.conf) или его версия с использованием [barman](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/conf/recovery_barman.conf).

### [Скрипты:](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts)

На витуальных машинах скрипты распологаются по очевидному пути /vagrant/files/scripts/.

Полная версия [README_scripts.md](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/README_scripts.md)

- [clone_barman.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone_barman.sh) (автоматизированный бэкап)
  Скрипт  создания бэкапа сервера pgsqlMaster и его разворачивание на сервере pgsqlSlave. Выполняется от имени пользователя root на pgsqlSlave и не требует подключения по ssh, т.к. используется потоковая передача информации (т.н., "streaming backup"). Конечно, для работы этого скрипта сервера pgsqlMaster и pgsqlSlave и barman на pgsqlSlave уже должны быть соответствующим образом настроены, что и выполняется в плейбуке [02_pgsql.yml](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/02_pgsql/tasks/main.yml) В результате выполнения полностью автоматизированного скрипта резервного копирования через с помощью barman имеем настроенную master-slave hot_standby репликацию с использованием слотов.

- [clone_pg_basebackup.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone_pg_basebackup.sh) (автоматизированный бэкап)
  Результат выполнения этого скрипта такой же, что и предыдущего -  настроенная master-slave hot_standby репликация с использованием слотов. Этот скрипт нужно выполнять на ведущем сервере pgsqlMaster от имени пользователя postgres. pg_basebackup выполняется на мастере и в качестве каталога назначения указан $PGDATA pgsqlSlave, примонтированный на pgsqlMaster с помощью fuse-sshfs.


- [clone1.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone1.sh), [clone2.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone2.sh) (полуавтоматизированный бэкап)

  В этом варианте, $PGDATA сервера pgsqlMaster архивируется с помощью tar, через конвейер распаковывается на pgsqlSlave, а новые WAL-логи с помощью rsync дозаписываются в каталог pgsqlSlave:$PGDATA/pg_wal. Все действия нужно выполнять на ведущем сервере pgsqlMaster от имени пользователя postgres.

В итоге, получаем рабочую hot_standby репликацию с использованием слотов.