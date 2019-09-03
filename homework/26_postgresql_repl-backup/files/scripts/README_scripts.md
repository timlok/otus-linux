### [Скрипты:](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts)

На витуальных машинах скрипты распологаются по очевидному пути /vagrant/files/scripts/.

- [clone_barman.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone_barman.sh) (автоматизированный бэкап)
  Скрипт  создания бэкапа сервера pgsqlMaster и его разворачивание на сервере pgsqlSlave. Выполняется от имени пользователя root на pgsqlSlave и не требует подключения по ssh, т.к. используется потоковая передача информации (т.н., "streaming backup"). Конечно, для работы этого скрипта сервера pgsqlMaster и pgsqlSlave и barman на pgsqlSlave уже должны быть соответствующим образом настроены, что и выполняется в плейбуке [02_pgsql.yml](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/02_pgsql/tasks/main.yml) В результате выполнения полностью автоматизированного скрипта резервного копирования через с помощью barman имеем настроенную master-slave hot_standby репликацию с использованием слотов.
  
  Вывод работы скрипта clone_barman.sh:

```bash
[root@pgsqlSlave ~]# bash -xeu /vagrant/files/scripts/./clone_barman.sh
+ PGDATA=/var/lib/pgsql/11/data/
+ WAL_ARCH=/var/lib/pgsql/11/wal_bck/
+ PGDATA_TMP=/tmp/pgsqlMaster/data/
+ PG_RECOVERY=/var/lib/pgsql/11/data/recovery.conf
+ su -l barman -c 'barman switch-xlog --force --archive pgsqlMaster'
The WAL file 000000010000000000000014 has been closed on server 'pgsqlMaster'
Waiting for the WAL file 000000010000000000000014 from server 'pgsqlMaster' (max: 30 seconds)
Processing xlog segments from streaming for pgsqlMaster
          000000010000000000000014
+ sleep 5
+ echo 'форсируем запуск потоковой передачи WAL-логов и ждём 30 секунд'
форсируем запуск потоковой передачи WAL-логов и ждём 30 секунд
+ su -l barman -c 'barman receive-wal pgsqlMaster'
Starting receive-wal for server pgsqlMaster
Another receive-wal process is already running for server pgsqlMaster.
+ sleep 30
+ su -l barman -c 'barman backup pgsqlMaster'
Starting backup using postgres method for server pgsqlMaster in /var/lib/barman/pgsqlMaster/base/20190903T065708
Backup start at LSN: 0/15000060 (000000010000000000000015, 00000060)
Starting backup copy via pg_basebackup for 20190903T065708
Copy done (time: 4 seconds)
Finalising the backup.
Backup size: 310.0 MiB
Backup end at LSN: 0/17000000 (000000010000000000000016, 00000000)
Backup completed (start time: 2019-09-03 06:57:08.316247, elapsed time: 4 seconds)
Processing xlog segments from streaming for pgsqlMaster
          000000010000000000000015
+ echo 'ждём 60 секунд, чтобы WAL-файлы окончательно синхронизировались'
ждём 60 секунд, чтобы WAL-файлы окончательно синхронизировались
+ sleep 60
++ barman list-backup --minimal pgsqlMaster
++ grep -v FAILED
++ sort -r
++ head -1
+ BACKUP_ID=20190903T065708
+ su -l barman -c 'barman recover pgsqlMaster 20190903T065708 /tmp/pgsqlMaster/data/'
Starting local restore for server pgsqlMaster using backup 20190903T065708
Destination directory: /tmp/pgsqlMaster/data/
Copying the base backup.
Copying required WAL segments.
Generating archive status files
Identify dangerous settings in destination directory.

IMPORTANT
These settings have been modified to prevent data losses

postgresql.auto.conf line 27: archive_command = false

Recovery completed (start time: 2019-09-03 06:58:13.360830, elapsed time: 4 seconds)

Your PostgreSQL server has been successfully prepared for recovery!
+ systemctl stop postgresql-11.service
+ rm -rf '/var/lib/pgsql/11/wal_bck/*'
+ rm -rf /var/lib/pgsql/11/data/
+ mv /tmp/pgsqlMaster/data/ /var/lib/pgsql/11/data/
+ touch /var/lib/pgsql/11/data/recovery.conf
+ echo 'primary_conninfo = '\''host=pgsqlMaster port=5432 user=repluser'\'''
+ echo 'primary_slot_name = '\''standby_slot'\'''
+ echo 'standby_mode = '\''on'\'''
+ sed -i 's/^#hot_standby =/hot_standby =/g' /var/lib/pgsql/11/data/postgresql.auto.conf
+ chown -R postgres. /var/lib/pgsql/11/data/
+ systemctl start postgresql-11.service
```

- [clone_pg_basebackup.sh](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/files/scripts/clone_pg_basebackup.sh) (автоматизированный бэкап)
  Результат выполнения этого скрипта такой же, что и предыдущего -  настроенная master-slave hot_standby репликация с использованием слотов. Этот скрипт нужно выполнять на ведущем сервере pgsqlMaster от имени пользователя postgres. pg_basebackup выполняется на мастере и в качестве каталога назначения указан $PGDATA pgsqlSlave, примонтированный на pgsqlMaster с помощью fuse-sshfs.
  
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

#### Результат:

В итоге, получаем рабочую hot_standby репликацию с использованием слотов.
На pgsqlMaster статус репликации при использовании pg_basebackup или полуавтоматического способа:

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
