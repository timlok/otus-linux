### [Скрипты:](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts)

- [clone_pg_basebackup.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone_pg_basebackup.sh) (автоматизированный бэкап)
  В результате выполнения полностью автоматизированного скрипта резервного копирования через pg_basebackup имеем настроенную master-slave hot_standby репликацию с использованием слотов. Этот скрипт нужно выполнять на ведущем сервере pgsqlMaster от имени пользователя postgres. pg_basebackup выполняется на мастере и в качестве каталога назначения указан $PGDATA pgsqlSlave, примонтированный на pgsqlMaster с помощью fuse-sshfs.
  
  Вывод работы скрипта clone_pg_basebackup.sh:

```bash
-bash-4.2$ ./clone_pg_basebackup.sh
+ PGDATA=/var/lib/pgsql/11/data/
+ WAL_ARCH=/var/lib/pgsql/11/wal_bck/
+ PGDATA_TMP=/tmp/pgsqlSlave
+ PG_RECOVERY=/tmp/pgsqlSlave/recovery.conf
+ ssh postgres@pgsqlSlave -t 'sudo systemctl stop postgresql-11.service'
Connection to pgsqlslave closed.
+ ssh postgres@pgsqlSlave -t 'rm -rf /var/lib/pgsql/11/wal_bck/*'
Connection to pgsqlslave closed.
+ mkdir /tmp/pgsqlSlave
+ sshfs postgres@pgsqlSlave://var/lib/pgsql/11/data/ /tmp/pgsqlSlave
+ rm -rf /tmp/pgsqlSlave/backup_label /tmp/pgsqlSlave/base /tmp/pgsqlSlave/current_logfiles /tmp/pgsqlSlave/global /tmp/pgsqlSlave/log /tmp/pgsqlSlave/pg_commit_ts /tmp/pgsqlSlave/pg_dynshmem /tmp/pgsqlSlave/pg_hba.conf /tmp/pgsqlSlave/pg_ident.conf /tmp/pgsqlSlave/pg_logical /tmp/pgsqlSlave/pg_multixact /tmp/pgsqlSlave/pg_notify /tmp/pgsqlSlave/pg_replslot /tmp/pgsqlSlave/pg_serial /tmp/pgsqlSlave/pg_snapshots /tmp/pgsqlSlave/pg_stat /tmp/pgsqlSlave/pg_stat_tmp /tmp/pgsqlSlave/pg_subtrans /tmp/pgsqlSlave/pg_tblspc /tmp/pgsqlSlave/pg_twophase /tmp/pgsqlSlave/PG_VERSION /tmp/pgsqlSlave/pg_wal /tmp/pgsqlSlave/pg_xact /tmp/pgsqlSlave/postgresql.auto.conf /tmp/pgsqlSlave/postgresql.conf /tmp/pgsqlSlave/recovery.conf
+ pg_basebackup --wal-method=stream --format=plain --host localhost --port=5432 -U repluser -w --write-recovery-conf --progress --verbose --checkpoint=fast -D /tmp/pgsqlSlave
pg_basebackup: начинается базовое резервное копирование, ожидается завершение контрольной точки
pg_basebackup: контрольная точка завершена
pg_basebackup: стартовая точка в журнале предзаписи: 0/10000028 на линии времени 1
pg_basebackup: запуск фонового процесса считывания WAL
pg_basebackup: создан временный слот репликации "pg_basebackup_29720"
31490/31490 КБ (100%), табличное пространство 1/1
pg_basebackup: конечная точка в журнале предзаписи: 0/10000130
pg_basebackup: ожидание завершения потоковой передачи фоновым процессом...
pg_basebackup: базовое резервное копирование завершено
+ sed -i 's/^primary_conninfo =/#primary_conninfo =/g' /tmp/pgsqlSlave/recovery.conf
+ echo 'primary_conninfo = '\''host=pgsqlMaster port=5432 user=repluser'\'''
+ echo 'primary_slot_name = '\''standby_slot'\'''
+ sed -i 's/^#hot_standby =/hot_standby =/g' /tmp/pgsqlSlave/postgresql.auto.conf
+ fusermount -u /tmp/pgsqlSlave
+ rm -rf /tmp/pgsqlSlave
+ ssh postgres@pgsqlSlave -t 'sudo systemctl start postgresql-11.service'
Connection to pgsqlslave closed.
```

- [clone1.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone1.sh), [clone2.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone2.sh) (полуавтоматизированный бэкап)

В этом варианте, $PGDATA сервера pgsqlMaster архивируется с помощью tar, через конвейер распаковывается на pgsqlSlave, а новые WAL-логи с помощью rsync дозаписываются в каталог pgsqlSlave:$PGDATA/pg_wal. Все действия нужно выполнять на ведущем сервере pgsqlMaster от имени пользователя postgres.

Порядок действий и вывод консоли:

1. создаём чекпоинт - запускаем сессию psql и после выполнения запроса не закрываем её!

```bash
su - postgres
psql
```
```sql
postgres=# SELECT pg_start_backup('otus_label', true, false); 
pg_start_backup
-----------------
 0/4000028 
(1 строка)
```

2. выполняем скрипт [clone1.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone1.sh) (путь на pgsqlMaster /vagrant/files/scripts/clone1.sh)

```bash
-bash-4.2$ ./clone1.sh
+ PGDATA=/var/lib/pgsql/11/data/
+ WAL_ARCH=/var/lib/pgsql/11/wal_bck/
+ ssh postgres@pgsqlSlave -t 'sudo systemctl stop postgresql-11.service'
Connection to pgsqlslave closed.
+ ssh postgres@pgsqlSlave -t 'rm -rf /var/lib/pgsql/11/data/*'
Connection to pgsqlslave closed.
+ ssh postgres@pgsqlSlave -t 'rm -rf /var/lib/pgsql/11/wal_bck/*'
Connection to pgsqlslave closed.
+ cd /var/lib/pgsql/11/data/
+ tar cfO - --exclude=postmaster.pid ./
+ lbzip2 -n 2 -5
+ ssh postgres@pgsqlSlave 'lbunzip2 -c -n 2 | tar xf - -C /var/lib/pgsql/11/data/'
```

3. создаём новый сегмент WAL
ВНИМАНИЕ! Выполнять в той же psql-сессии, что и пункт 1

```sql
postgres=# SELECT * FROM pg_stop_backup(false, true);
ЗАМЕЧАНИЕ:  команда pg_stop_backup завершена, все требуемые сегменты WAL заархивированы
    lsn    |                           labelfile                           | spcmapfile
-----------+---------------------------------------------------------------+------------
 0/4000130 | START WAL LOCATION: 0/4000028 (file 000000010000000000000004)+|
           | CHECKPOINT LOCATION: 0/4000060                               +|
           | BACKUP METHOD: streamed                                      +|
           | BACKUP FROM: master                                          +|
           | START TIME: 2019-08-26 10:59:02 UTC                          +|
           | LABEL: otus_label                                            +|
           | START TIMELINE: 1                                            +|
           |                                                               |
(1 строка)
```

4. выполняем скрипт [clone2.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone2.sh) (путь на pgsqlMaster /vagrant/files/scripts/clone2.sh)
```bash
-bash-4.2$ ./clone2.sh
+ PGDATA=/var/lib/pgsql/11/data/
+ PG_WAL=/var/lib/pgsql/11/data/pg_wal/
+ PG_RECOVERY=/var/lib/pgsql/11/data/recovery.conf
+ rsync --partial --append-verify --progress -avz -e ssh /var/lib/pgsql/11/data/pg_wal/ postgres@pgsqlSlave:/var/lib/pgsql/11/data/pg_wal/
sending incremental file list
./
000000010000000000000004.00000028.backup
            322 100%    0.00kB/s    0:00:00 (xfr#1, to-chk=7/13)
000000010000000000000005
     16,777,216 100%  141.59MB/s    0:00:00 (xfr#2, to-chk=6/13)
archive_status/
archive_status/000000010000000000000004.00000028.backup.done
              0 100%    0.00kB/s    0:00:00 (xfr#3, to-chk=1/13)
archive_status/000000010000000000000004.done
              0 100%    0.00kB/s    0:00:00 (xfr#4, to-chk=0/13)

sent 17,110 bytes  received 103 bytes  11,475.33 bytes/sec
total size is 83,886,402  speedup is 4,873.43
+ ssh postgres@pgsqlSlave -t 'echo standby_mode' = '\'\''on\'\'' > /var/lib/pgsql/11/data/recovery.conf'
Connection to pgsqlslave closed.
+ ssh postgres@pgsqlSlave -t 'echo primary_conninfo' = '\'\''host=192.168.11.150' port=5432 'user=repluser\'\'' >> /var/lib/pgsql/11/data/recovery.conf'
Connection to pgsqlslave closed.
+ ssh postgres@pgsqlSlave -t 'sed -i '\''s/^#hot_standby =/hot_standby =/g'\'' /var/lib/pgsql/11/data//postgresql.auto.conf'
Connection to pgsqlslave closed.
+ ssh postgres@pgsqlSlave -t 'echo primary_slot_name' = '\'\''standby_slot\'\'' >> /var/lib/pgsql/11/data/recovery.conf'
Connection to pgsqlslave closed.
+ ssh postgres@pgsqlSlave -t 'sudo systemctl start postgresql-11.service'
Connection to pgsqlslave closed.
```

В итоге, получаем рабочую hot_standby репликацию с использованием слотов.
Проверяем на pgsqlMaster:
```sql
postgres=# \x
Расширенный вывод включён.
postgres=# select * from pg_stat_replication;
-[ RECORD 1 ]----+------------------------------
pid              | 5451
usesysid         | 16385
usename          | repluser
application_name | walreceiver
client_addr      | 192.168.11.151
client_hostname  |
client_port      | 58048
backend_start    | 2019-08-26 10:59:59.924546+00
backend_xmin     |
state            | streaming
sent_lsn         | 0/5000060
write_lsn        | 0/5000060
flush_lsn        | 0/5000060
replay_lsn       | 0/5000060
write_lag        |
flush_lag        |
replay_lag       |
sync_priority    | 0
sync_state       | async
```
И на pgsqlSlave увидим БД otus_test, которая была только на pgsqlMaster:
```
-bash-4.2$ psql -l
                                  Список баз данных
    Имя    | Владелец | Кодировка | LC_COLLATE  |  LC_CTYPE   |     Права доступа     
-----------+----------+-----------+-------------+-------------+-----------------------
 otus_test | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | 
 postgres  | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | 
 template0 | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | =c/postgres          +
           |          |           |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | =c/postgres          +
           |          |           |             |             | postgres=CTc/postgres
(4 строки)
```
