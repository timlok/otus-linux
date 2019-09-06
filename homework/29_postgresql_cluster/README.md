# ДЗ-29 (PostgreSQL cluster: patroni+etcd+haproxy)

## Задача:

> • Развернуть кластер PostgreSQL из трех нод. Создать тестовую базу -
> проверить статус репликации
> • Сделать switchover/failover
> • Поменять конфигурацию PostgreSQL + с параметром требующим
> перезагрузки
>
> * Настроить клиентские подключения через HAProxy

## Решение:

Т.к. провижининг ВМ выполняется с помощью ansible и в модуле systemd используется параметр daemon_reload, то на хостовой машине необходим ansible >= 2.4.

Как обычно, выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/29_postgresql_cluster) и выполняем ```vagrant up```. В результате будет развёрнуто 6 виртуальных машин (haproxy, etcd, pg01, pg02, pg03, pgclient) на которых будет настроен кластер PostgreSQL11.5 на patroni+etcd+haproxy. Клиентская ВМ pgclient служит для тестирования клиентских подключений через haproxy и именно с этой ВМ в результате выполнения плейбука [05_create_database](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/05_create_database) будет скачана [демонстрационная БД](https://edu.postgrespro.ru/demo_small.zip) и импортирована в кластер.

На виртуальную машину haproxy с localhost ipv4 хоста проброшены порты 5000 и 7000. Это не обязательно, т.к. проверку ДЗ можно полноценно выполнить со специальной виртуальной машины клиента (pgclient), что и приведено ниже. Тем не менее:
http://127.0.0.1:7000/ - веб-интерфейс HAProxy
TCP:127.0.0.0.1:5000 - порт для клиентских подключений к PostgreSQL кластеру otus и для этого можно использовать логин "postgres" и пароль "gfhjkm". 


Столкнулся с проблемой - сервис etcd не запускается при старте ОС и падает с ошибкой:

```bash
сен 06 07:07:25 etcd etcd[2362]: failed to detect default host (could not find default route)
сен 06 07:07:25 etcd etcd[2362]: the server is already initialized as member before, starting as etcd member...
сен 06 07:07:25 etcd etcd[2362]: listen tcp 192.168.11.160:2380: bind: cannot assign requested address
сен 06 07:07:25 etcd systemd[1]: etcd.service: main process exited, code=exited, status=1/FAILURE
сен 06 07:07:25 etcd systemd[1]: Failed to start Etcd Server.
сен 06 07:07:25 etcd systemd[1]: Unit etcd.service entered failed state.
сен 06 07:07:25 etcd systemd[1]: etcd.service failed.
```

Это вызвано тем, что сервис etcd очень быстро включается и перезапускается, несмотря на то, что в его service-файле ```/usr/lib/systemd/system/etcd.service``` указанны директивы
```
After=network-online.target
Wants=network-online.target
```

Способов устранения этой проблемы много, я просто добавил задержку 10 секунд между перезапусками сервиса в соответствующий юнит-файл в секцию [Service]:
```RestartSec=10```

## Проверка ДЗ:

### Тестирование клиентских подключений через HAProxy

Как я писал выше:

> Клиентская ВМ pgclient служит для тестирования клиентских подключений через haproxy и именно с этой ВМ в результате выполнения плейбука [05_create_database](https://github.com/timlok/otus-linux/tree/master/homework/26_postgresql_repl-backup/provisioning/05_create_database) будет скачана [демонстрационная БД](https://edu.postgrespro.ru/demo_small.zip) и импортирована в кластер.

И именно с этой же ВМ я и проверю статус репликации и проведу короткий нагрузочный тест.

Список баз в кластере:
```
[vagrant@pgclient ~]$ psql -h haproxy -p 5000 -U postgres -c "\list"
                                  Список баз данных
    Имя    | Владелец | Кодировка | LC_COLLATE  |  LC_CTYPE   |     Права доступа     
-----------+----------+-----------+-------------+-------------+-----------------------
 demo      | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | 
 postgres  | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | 
 template0 | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | =c/postgres          +
           |          |           |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 | =c/postgres          +
           |          |           |             |             | postgres=CTc/postgres
(4 строки)
```
Список таблиц БД demo:
```
[vagrant@pgclient ~]$ psql -h haproxy -p 5000 -U postgres -d demo -c "SELECT table_name FROM information_schema.tables WHERE table_schema NOT IN ('information_schema','pg_catalog');"

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

#### Проверим статус репликации:

```
[vagrant@pgclient ~]$ psql -h haproxy -p 5000 -U postgres -x -c "select * from pg_stat_replication;"
-[ RECORD 1 ]----+------------------------------
pid              | 7533
usesysid         | 16384
usename          | replicator
application_name | pg02
client_addr      | 192.168.11.152
client_hostname  | pg02
client_port      | 36090
backend_start    | 2019-09-06 11:46:31.887052+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/240C7298
write_lsn        | 0/240C7298
flush_lsn        | 0/240C7298
replay_lsn       | 0/240C7298
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
-[ RECORD 2 ]----+------------------------------
pid              | 7941
usesysid         | 16384
usename          | replicator
application_name | pg03
client_addr      | 192.168.11.153
client_hostname  | pg03
client_port      | 38166
backend_start    | 2019-09-06 11:59:31.612186+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/240C7298
write_lsn        | 0/240C7298
flush_lsn        | 0/240C7298
replay_lsn       | 0/240C7298
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
```

Выполнение нагрузочного тестирования с помощью утилиты ```pgbench```:

Создадим служебные таблицы в базе demo для запуска pgbench:
```
[vagrant@pgclient ~]$ /usr/pgsql-11/bin/pgbench -h haproxy -p 5000 -U postgres -i demo
dropping old tables...
ЗАМЕЧАНИЕ:  таблица "pgbench_accounts" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_branches" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_history" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_tellers" не существует, пропускается
creating tables...
generating data...
100000 of 100000 tuples (100%) done (elapsed 0.05 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done.
```
Запустим простой тест, ограниченный 100 транзакциями:
```
[vagrant@pgclient ~]$ /usr/pgsql-11/bin/pgbench -h haproxy -p 5000 -U postgres -c 10 -C -t 100 demo
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 10
number of threads: 1
number of transactions per client: 100
number of transactions actually processed: 1000/1000
latency average = 144.658 ms
tps = 69.128670 (including connections establishing)
tps = 74.130792 (excluding connections establishing)
```

### Выполним ручной switchover

```
[root@pg01 ~]# patronictl -c /etc/patroni.yml switchover --master pg01 --candidate pg03 --force
Current cluster topology
+---------+--------+----------------+--------+---------+----+-----------+
| Cluster | Member |      Host      |  Role  |  State  | TL | Lag in MB |
+---------+--------+----------------+--------+---------+----+-----------+
|   otus  |  pg01  | 192.168.11.151 | Leader | running | 12 |       0.0 |
|   otus  |  pg02  | 192.168.11.152 |        | running | 12 |       0.0 |
|   otus  |  pg03  | 192.168.11.153 |        | running | 12 |       0.0 |
+---------+--------+----------------+--------+---------+----+-----------+
2019-09-06 11:42:03.68300 Successfully switched over to "pg03"
+---------+--------+----------------+--------+---------+----+-----------+
| Cluster | Member |      Host      |  Role  |  State  | TL | Lag in MB |
+---------+--------+----------------+--------+---------+----+-----------+
|   otus  |  pg01  | 192.168.11.151 |        | stopped |    |   unknown |
|   otus  |  pg02  | 192.168.11.152 |        | running | 12 |       0.0 |
|   otus  |  pg03  | 192.168.11.153 | Leader | running | 12 |           |
+---------+--------+----------------+--------+---------+----+-----------+
```
В системных логах:
```bash
сен 06 11:41:59 pg01 patroni[2379]: 2019-09-06 11:41:59,049 INFO: Lock owner: pg01; I am pg01
сен 06 11:41:59 pg01 patroni[2379]: 2019-09-06 11:41:59,068 INFO: no action.  i am the leader with the lock
сен 06 11:42:02 pg01 patroni[2379]: 2019-09-06 11:42:02,553 INFO: received switchover request with leader=pg01 candidate=pg03 scheduled_at=None
сен 06 11:42:02 pg01 patroni[2379]: 2019-09-06 11:42:02,559 INFO: Got response from pg03 http://192.168.11.153:8008/patroni: {"database_system_identifier": "6733173987368392517", "postmaster_start_time": "2019-09-06 11:24:50.439 UTC", "timeline": 12, "cluster_unlocked": false, "patroni": {"scope": "otus", "version": "1.6.0"}, "state": "running", "role": "replica", "xlog": {"received_location": 382200824, "replayed_timestamp": null, "paused": false, "replayed_location": 382200824}, "server_version": 110005}
сен 06 11:42:02 pg01 patroni[2379]: 2019-09-06 11:42:02,703 INFO: Lock owner: pg01; I am pg01
сен 06 11:42:02 pg01 patroni[2379]: 2019-09-06 11:42:02,738 INFO: Got response from pg03 http://192.168.11.153:8008/patroni: {"database_system_identifier": "6733173987368392517", "postmaster_start_time": "2019-09-06 11:24:50.439 UTC", "timeline": 12, "cluster_unlocked": false, "patroni": {"scope": "otus", "version": "1.6.0"}, "state": "running", "role": "replica", "xlog": {"received_location": 382200824, "replayed_timestamp": null, "paused": false, "replayed_location": 382200824}, "server_version": 110005}
сен 06 11:42:02 pg01 patroni[2379]: 2019-09-06 11:42:02,826 INFO: manual failover: demoting myself
сен 06 11:42:03 pg01 patroni[2379]: 2019-09-06 11:42:03,047 INFO: Leader key released
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05,072 INFO: Local timeline=12 lsn=0/16C7ECA0
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05,085 INFO: master_timeline=13
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05,087 INFO: master: history=1        0/5000140        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 2        0/5029B30        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 3        0/5048540        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 4        0/50486C0        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 5        0/5048840        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 6        0/50489C0        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 7        0/5048B40        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 8        0/5048CC0        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 9        0/5048E40        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 10        0/162D7C78        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 11        0/16C7DA98        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 12        0/16C7ED10        no recovery target specified
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05,089 INFO: closed patroni connection to the postgresql cluster
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05,127 INFO: postmaster pid=7383
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05.135 UTC [7383] СООБЩЕНИЕ:  для приёма подключений по адресу IPv4 "192.168.11.151" открыт порт 5432
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05.138 UTC [7383] СООБЩЕНИЕ:  для приёма подключений открыт Unix-сокет "./.s.PGSQL.5432"
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05.147 UTC [7383] СООБЩЕНИЕ:  передача вывода в протокол процессу сбора протоколов
сен 06 11:42:05 pg01 patroni[2379]: 2019-09-06 11:42:05.147 UTC [7383] ПОДСКАЗКА:  В дальнейшем протоколы будут выводиться в каталог "log".
сен 06 11:42:05 pg01 patroni[2379]: 192.168.11.151:5432 - отвергает подключения
сен 06 11:42:05 pg01 patroni[2379]: 192.168.11.151:5432 - отвергает подключения
сен 06 11:42:06 pg01 patroni[2379]: 192.168.11.151:5432 - принимает подключения
сен 06 11:42:12 pg01 patroni[2379]: 2019-09-06 11:42:12,707 INFO: Lock owner: pg03; I am pg01
сен 06 11:42:12 pg01 patroni[2379]: 2019-09-06 11:42:12,707 INFO: does not have lock
сен 06 11:42:12 pg01 patroni[2379]: 2019-09-06 11:42:12,707 INFO: establishing a new patroni connection to the postgres cluster
сен 06 11:42:12 pg01 patroni[2379]: 2019-09-06 11:42:12,734 INFO: no action.  i am a secondary and i am following a leader
```

### Автоматический failover

Теперь, выключим сетевой интерфейс на pg03 и опять проверим статус кластера:
```
[root@pg03 ~]# ip link set eth1 down
[root@pg03 ~]# ip link show eth1
3: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc pfifo_fast state DOWN mode DEFAULT group default qlen 1000
    link/ether 08:00:27:e5:05:aa brd ff:ff:ff:ff:ff:ff
```
```
[root@pg01 ~]# patronictl -c /etc/patroni.yml list
+---------+--------+----------------+--------+---------+----+-----------+
| Cluster | Member |      Host      |  Role  |  State  | TL | Lag in MB |
+---------+--------+----------------+--------+---------+----+-----------+
|   otus  |  pg01  | 192.168.11.151 | Leader | running | 14 |       0.0 |
|   otus  |  pg02  | 192.168.11.152 |        | running | 14 |       0.0 |
+---------+--------+----------------+--------+---------+----+-----------+
```
В системных логах, соответственно:
```bash
сен 06 11:46:04 pg01 patroni[2379]: 2019-09-06 11:46:04,680 INFO: no action.  i am a secondary and i am following a leader
сен 06 11:46:14 pg01 patroni[2379]: 2019-09-06 11:46:14,641 INFO: Selected new etcd server http://192.168.11.160:2379
сен 06 11:46:14 pg01 patroni[2379]: 2019-09-06 11:46:14,659 INFO: Lock owner: pg03; I am pg01
сен 06 11:46:14 pg01 patroni[2379]: 2019-09-06 11:46:14,659 INFO: does not have lock
сен 06 11:46:14 pg01 patroni[2379]: 2019-09-06 11:46:14,669 INFO: no action.  i am a secondary and i am following a leader
сен 06 11:46:24 pg01 patroni[2379]: 2019-09-06 11:46:24,637 INFO: Got response from pg02 http://192.168.11.152:8008/patroni: {"database_system_identifier": "6733173987368392517", "postmaster_start_time": "2019-09-06 11:42:05.247 UTC", "timeline": 13, "cluster_unlocked": true, "patroni": {"scope": "otus", "version": "1.6.0"}, "state": "running", "role": "replica", "xlog": {"received_location": 382201376, "replayed_timestamp": null, "paused": false, "replayed_location": 382201376}, "server_version": 110005}
сен 06 11:46:26 pg01 patroni[2379]: 2019-09-06 11:46:26,622 WARNING: Request failed to pg03: GET http://192.168.11.153:8008/patroni (HTTPConnectionPool(host='192.168.11.153', port=8008): Max retries exceeded with url: /patroni (Caused by ConnectTimeoutError(<urllib3.connection.HTTPConnection object at 0x7fdab0377550>, 'Connection to 192.168.11.153 timed out. (connect timeout=2)')))
сен 06 11:46:26 pg01 patroni[2379]: 2019-09-06 11:46:26,654 INFO: promoted self to leader by acquiring session lock
сен 06 11:46:26 pg01 patroni[2379]: сервер повышается
сен 06 11:46:26 pg01 patroni[2379]: 2019-09-06 11:46:26,663 INFO: cleared rewind state after becoming the leader
сен 06 11:46:27 pg01 patroni[2379]: 2019-09-06 11:46:27,712 INFO: Lock owner: pg01; I am pg01
сен 06 11:46:27 pg01 patroni[2379]: 2019-09-06 11:46:27,751 INFO: no action.  i am the leader with the lock
```

### Изменение конфигурации PostgreSQL

Изменим параметр max_connections, требующий перезапуска postgresql:
```diff
[root@pg01 ~]# patronictl -c /etc/patroni.yml edit-config
"/tmp/otus-config-k_iGst.yaml" 8L, 146C written
--- 
+++
@@ -2,5 +2,7 @@
 maximum_lag_on_failover: 1048576
 postgresql:
   use_pg_rewind: true
+  parameters:
+    max_connections: 110
 retry_timeout: 10
 ttl: 30

Apply these changes? [y/N]: y
Configuration changed
```
При обзоре кластера видим, что требуется перезапуск кластера otus:
```[root@pg01 ~]# patronictl -c /etc/patroni.yml list
+---------+--------+----------------+--------+---------+----+-----------+-----------------+
| Cluster | Member |      Host      |  Role  |  State  | TL | Lag in MB | Pending restart |
+---------+--------+----------------+--------+---------+----+-----------+-----------------+
|   otus  |  pg01  | 192.168.11.151 | Leader | running | 12 |       0.0 |        *        |
|   otus  |  pg02  | 192.168.11.152 |        | running | 12 |       0.0 |        *        |
|   otus  |  pg03  | 192.168.11.153 |        | running | 12 |       0.0 |        *        |
+---------+--------+----------------+--------+---------+----+-----------+-----------------+
```
В системных логах тоже видим, что требуется перезапуск:
```bash
сен 06 11:17:58 pg01 patroni[2379]: 2019-09-06 11:17:58,113 INFO: Changed max_connections from 100 to 110 (restart required)
```
Успешно перезапускаем кластер otus:
```
[root@pg01 ~]# patronictl -c /etc/patroni.yml restart otus --force
+---------+--------+----------------+--------+---------+----+-----------+-----------------+
| Cluster | Member |      Host      |  Role  |  State  | TL | Lag in MB | Pending restart |
+---------+--------+----------------+--------+---------+----+-----------+-----------------+
|   otus  |  pg01  | 192.168.11.151 | Leader | running | 12 |       0.0 |        *        |
|   otus  |  pg02  | 192.168.11.152 |        | running | 12 |       0.0 |        *        |
|   otus  |  pg03  | 192.168.11.153 |        | running | 12 |       0.0 |        *        |
+---------+--------+----------------+--------+---------+----+-----------+-----------------+
Success: restart on member pg01
Success: restart on member pg02
Success: restart on member pg03
```
