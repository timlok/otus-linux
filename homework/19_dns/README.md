# Заметки к ДЗ-19

## Задача:

> настраиваем split-dns
> взять стенд https://github.com/erlong15/vagrant-bind
> добавить еще один сервер client2
> завести в зоне dns.lab
> имена
> web1 - смотрит на клиент1
> web2 смотрит на клиент2
>
> завести еще одну зону newdns.lab
> завести в ней запись
> www - смотрит на обоих клиентов
>
> настроить split-dns
> клиент1 - видит обе зоны, но в зоне dns.lab только web1
>
> клиент2 видит только dns.lab
>
> *) настроить все без выключения selinux
> Критерии оценки: 4 - основное задание сделано, но есть вопросы
> 5 - сделано основное задание
> 6 - выполнено задания со звездочкой 

## Решение:

Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/19_dns) и выполняем ```vagrant up```. 

Т.к. за основу взят [готовый проект](https://github.com/erlong15/vagrant-bind) с провижинингом с помощью ansible, то для разворачивания (простите за тавтологию) ВМ необходим ansible на хостовой машине. Так же пришлось отключить в NetworkManager возможность обновления файла resolv.conf, хотя можно было задать соответствующие параметры и через nmcli.

SELinux включён.
В качестве демона синхронизации времени использовался установленный по-умолчанию chronyd, а не предлагаемый ntpd.

В логах серверов видно, что зоны успешно передаются на slave-сервер ns02 и зона ddns обновляется с client с помощью rndc.

client:

```
[root@client ~]# nslookup web1
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web1.dns.lab
Address: 192.168.50.15

[root@client ~]# nslookup web2
Server:         192.168.50.10
Address:        192.168.50.10#53

** server can't find web2: NXDOMAIN

[root@client ~]# nslookup www
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   www.newdns.lab
Address: 192.168.50.15
Name:   www.newdns.lab
Address: 192.168.50.16
```

client2:

```
[vagrant@client2 ~]$ nslookup web1 
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web1.dns.lab
Address: 192.168.50.15

[vagrant@client2 ~]$ nslookup web2
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web2.dns.lab
Address: 192.168.50.16

[vagrant@client2 ~]$ nslookup www
Server:         192.168.50.10
Address:        192.168.50.10#53

** server can't find www: NXDOMAIN

[vagrant@client2 ~]$ nslookup www.newdns.lab
Server:         192.168.50.10
Address:        192.168.50.10#53

** server can't find www.newdns.lab: NXDOMAIN
```

```
[vagrant@client2 ~]$ rndc -c ~/rndc.conf status
version: 9.9.4-RedHat-9.9.4-74.el7_6.2 <id:8f9657aa>
CPUs found: 1
worker threads: 1
UDP listeners per interface: 1
number of zones: 208
debug level: 0
xfers running: 0
xfers deferred: 0
soa queries in progress: 0
query logging is OFF
recursive clients: 0/0/1000
tcp clients: 4/100
server is up and running
```


ns01:

```
Aug 21 11:48:13 ns01 named[7848]: zone 0.in-addr.arpa/IN/dns.lab-cl01: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone localhost/IN/dns.lab-cl01: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone 1.0.0.127.in-addr.arpa/IN/dns.lab-cl01: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone 1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa/IN/dns.lab-cl01: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone ddns.lab/IN/dns.lab-cl01: loaded serial 2711201407
Aug 21 11:48:13 ns01 named[7848]: zone localhost.localdomain/IN/dns.lab-cl01: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone 1.0.0.127.in-addr.arpa/IN/dns.lab-cl02: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl01: loaded serial 2711201407
Aug 21 11:48:13 ns01 named[7848]: zone newdns.lab/IN/dns.lab-cl01: loaded serial 2711201407
Aug 21 11:48:13 ns01 systemd[1]: Started Berkeley Internet Name Domain (DNS).
Aug 21 11:48:13 ns01 named[7848]: zone dns.lab/IN/dns.lab-cl01: loaded serial 2711201408
Aug 21 11:48:13 ns01 named[7848]: zone 0.in-addr.arpa/IN/dns.lab-cl02: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone dns.lab/IN/dns.lab-cl02: loaded serial 2711201408
Aug 21 11:48:13 ns01 named[7848]: zone 1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa/IN/dns.lab-cl02: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl02: loaded serial 2711201407
Aug 21 11:48:13 ns01 named[7848]: zone localhost.localdomain/IN/dns.lab-cl02: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: zone localhost/IN/dns.lab-cl02: loaded serial 0
Aug 21 11:48:13 ns01 named[7848]: all zones loaded
Aug 21 11:48:13 ns01 named[7848]: running
Aug 21 11:48:13 ns01 named[7848]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl01: sending notifies (serial 2711201407)
Aug 21 11:48:13 ns01 named[7848]: zone dns.lab/IN/dns.lab-cl01: sending notifies (serial 2711201408)
Aug 21 11:48:13 ns01 named[7848]: zone newdns.lab/IN/dns.lab-cl01: sending notifies (serial 2711201407)
Aug 21 11:48:13 ns01 named[7848]: zone ddns.lab/IN/dns.lab-cl01: sending notifies (serial 2711201407)
Aug 21 11:48:13 ns01 named[7848]: network unreachable resolving './DNSKEY/IN': 2001:500:2d::d#53
Aug 21 11:48:13 ns01 named[7848]: network unreachable resolving './NS/IN': 2001:500:2d::d#53
Aug 21 11:48:13 ns01 named[7848]: zone dns.lab/IN/dns.lab-cl02: sending notifies (serial 2711201408)
Aug 21 11:48:13 ns01 named[7848]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl02: sending notifies (serial 2711201407)
Aug 21 11:50:23 ns01 named[7848]: client 192.168.50.11#55391/key zonetransfer.key (dns.lab): view dns.lab-cl01: transfer of 'dns.lab/IN': AXFR started: TSIG zonetransfer.key
Aug 21 11:50:23 ns01 named[7848]: client 192.168.50.11#55391/key zonetransfer.key (dns.lab): view dns.lab-cl01: transfer of 'dns.lab/IN': AXFR ended
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#57253/key zonetransfer.key (ddns.lab): view dns.lab-cl01: transfer of 'ddns.lab/IN': AXFR started: TSIG zonetransfer.key
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#57253/key zonetransfer.key (ddns.lab): view dns.lab-cl01: transfer of 'ddns.lab/IN': AXFR ended
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#40878/key zonetransfer.key (newdns.lab): view dns.lab-cl01: transfer of 'newdns.lab/IN': AXFR started: TSIG zonetransfer.key
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#40878/key zonetransfer.key (newdns.lab): view dns.lab-cl01: transfer of 'newdns.lab/IN': AXFR ended
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#43528/key zonetransfer.key (50.168.192.in-addr.arpa): view dns.lab-cl01: transfer of '50.168.192.in-addr.arpa/IN': AXFR started: TSIG zonetransfer.key
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#43528/key zonetransfer.key (50.168.192.in-addr.arpa): view dns.lab-cl01: transfer of '50.168.192.in-addr.arpa/IN': AXFR ended
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#51325/key zonetransfer.key (dns.lab): view dns.lab-cl01: transfer of 'dns.lab/IN': AXFR started: TSIG zonetransfer.key
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#51325/key zonetransfer.key (dns.lab): view dns.lab-cl01: transfer of 'dns.lab/IN': AXFR ended
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#45162/key zonetransfer.key (50.168.192.in-addr.arpa): view dns.lab-cl01: transfer of '50.168.192.in-addr.arpa/IN': AXFR started: TSIG zonetransfer.key
Aug 21 11:50:24 ns01 named[7848]: client 192.168.50.11#45162/key zonetransfer.key (50.168.192.in-addr.arpa): view dns.lab-cl01: transfer of '50.168.192.in-addr.arpa/IN': AXFR ended
```

```
Aug 21 11:55:41 ns01 named[7848]: client 192.168.50.15#26099/key zonetransfer.key: view dns.lab-cl01: signer "zonetransfer.key" approved
Aug 21 11:55:41 ns01 named[7848]: client 192.168.50.15#26099/key zonetransfer.key: view dns.lab-cl01: updating zone 'ddns.lab/IN': adding an RR at 'www.ddns.lab' A
Aug 21 11:55:42 ns01 named[7848]: zone ddns.lab/IN/dns.lab-cl01: sending notifies (serial 2711201408)
Aug 21 11:55:42 ns01 named[7848]: client 192.168.50.11#34440/key zonetransfer.key (ddns.lab): view dns.lab-cl01: transfer of 'ddns.lab/IN': IXFR started: TSIG zonetransfer.key
Aug 21 11:55:42 ns01 named[7848]: client 192.168.50.11#34440/key zonetransfer.key (ddns.lab): view dns.lab-cl01: transfer of 'ddns.lab/IN': IXFR ended
```


ns02:

```
Aug 21 11:50:23 ns02 named[6927]: zone dns.lab/IN/dns.lab-cl01: Transfer started.
Aug 21 11:50:23 ns02 named[6927]: transfer of 'dns.lab/IN/dns.lab-cl01' from 192.168.50.10#53: connected using 192.168.50.11#55391
Aug 21 11:50:23 ns02 named[6927]: zone dns.lab/IN/dns.lab-cl01: transferred serial 2711201408: TSIG 'zonetransfer.key'
Aug 21 11:50:23 ns02 named[6927]: transfer of 'dns.lab/IN/dns.lab-cl01' from 192.168.50.10#53: Transfer completed: 1 messages, 7 records, 279 bytes, 0.003 secs (93000 bytes/sec)
Aug 21 11:50:23 ns02 named[6927]: zone dns.lab/IN/dns.lab-cl01: sending notifies (serial 2711201408)
Aug 21 11:50:23 ns02 named[6927]: network unreachable resolving './DNSKEY/IN': 2001:500:84::b#53
Aug 21 11:50:24 ns02 named[6927]: zone ddns.lab/IN/dns.lab-cl01: Transfer started.
Aug 21 11:50:24 ns02 named[6927]: zone newdns.lab/IN/dns.lab-cl01: Transfer started.
Aug 21 11:50:24 ns02 named[6927]: transfer of 'ddns.lab/IN/dns.lab-cl01' from 192.168.50.10#53: connected using 192.168.50.11#57253
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl01: zone transfer deferred due to quota
Aug 21 11:50:24 ns02 named[6927]: zone dns.lab/IN/dns.lab-cl02: zone transfer deferred due to quota
Aug 21 11:50:24 ns02 named[6927]: transfer of 'newdns.lab/IN/dns.lab-cl01' from 192.168.50.10#53: connected using 192.168.50.11#40878
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl02: zone transfer deferred due to quota
Aug 21 11:50:24 ns02 named[6927]: zone ddns.lab/IN/dns.lab-cl01: transferred serial 2711201407: TSIG 'zonetransfer.key'
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl01: Transfer started.
Aug 21 11:50:24 ns02 named[6927]: transfer of 'ddns.lab/IN/dns.lab-cl01' from 192.168.50.10#53: Transfer completed: 1 messages, 6 records, 273 bytes, 0.009 secs (30333 bytes/sec)
Aug 21 11:50:24 ns02 named[6927]: zone newdns.lab/IN/dns.lab-cl01: transferred serial 2711201407: TSIG 'zonetransfer.key'
Aug 21 11:50:24 ns02 named[6927]: zone dns.lab/IN/dns.lab-cl02: Transfer started.
Aug 21 11:50:24 ns02 named[6927]: transfer of 'newdns.lab/IN/dns.lab-cl01' from 192.168.50.10#53: Transfer completed: 1 messages, 8 records, 297 bytes, 0.008 secs (37125 bytes/sec)
Aug 21 11:50:24 ns02 named[6927]: zone ddns.lab/IN/dns.lab-cl01: sending notifies (serial 2711201407)
Aug 21 11:50:24 ns02 named[6927]: zone newdns.lab/IN/dns.lab-cl01: sending notifies (serial 2711201407)
Aug 21 11:50:24 ns02 named[6927]: transfer of '50.168.192.in-addr.arpa/IN/dns.lab-cl01' from 192.168.50.10#53: connected using 192.168.50.11#43528
Aug 21 11:50:24 ns02 named[6927]: transfer of 'dns.lab/IN/dns.lab-cl02' from 192.168.50.10#53: connected using 192.168.50.11#51325
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl01: transferred serial 2711201407: TSIG 'zonetransfer.key'
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl02: Transfer started.
Aug 21 11:50:24 ns02 named[6927]: transfer of '50.168.192.in-addr.arpa/IN/dns.lab-cl01' from 192.168.50.10#53: Transfer completed: 1 messages, 7 records, 305 bytes, 0.014 secs (21785 bytes/sec)
Aug 21 11:50:24 ns02 named[6927]: zone dns.lab/IN/dns.lab-cl02: transferred serial 2711201408: TSIG 'zonetransfer.key'
Aug 21 11:50:24 ns02 named[6927]: transfer of 'dns.lab/IN/dns.lab-cl02' from 192.168.50.10#53: Transfer completed: 1 messages, 7 records, 279 bytes, 0.014 secs (19928 bytes/sec)
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl01: sending notifies (serial 2711201407)
Aug 21 11:50:24 ns02 named[6927]: zone dns.lab/IN/dns.lab-cl02: sending notifies (serial 2711201408)
Aug 21 11:50:24 ns02 named[6927]: transfer of '50.168.192.in-addr.arpa/IN/dns.lab-cl02' from 192.168.50.10#53: connected using 192.168.50.11#45162
Aug 21 11:50:24 ns02 named[6927]: client 192.168.50.11#29177: view dns.lab-cl01: received notify for zone 'dns.lab'
Aug 21 11:50:24 ns02 named[6927]: zone dns.lab/IN/dns.lab-cl01: refused notify from non-master: 192.168.50.11#29177
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl02: transferred serial 2711201407: TSIG 'zonetransfer.key'
Aug 21 11:50:24 ns02 named[6927]: transfer of '50.168.192.in-addr.arpa/IN/dns.lab-cl02' from 192.168.50.10#53: Transfer completed: 1 messages, 7 records, 305 bytes, 0.015 secs (20333 bytes/sec)
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl02: sending notifies (serial 2711201407)
Aug 21 11:50:24 ns02 named[6927]: client 192.168.50.11#46264: view dns.lab-cl01: received notify for zone '50.168.192.in-addr.arpa'
Aug 21 11:50:24 ns02 named[6927]: zone 50.168.192.in-addr.arpa/IN/dns.lab-cl01: refused notify from non-master: 192.168.50.11#46264
```

```
Aug 21 11:55:42 ns02 named[6927]: client 192.168.50.10#48935/key zonetransfer.key: view dns.lab-cl01: received notify for zone 'ddns.lab': TSIG 'zonetransfer.key'
Aug 21 11:55:42 ns02 named[6927]: zone ddns.lab/IN/dns.lab-cl01: Transfer started.
Aug 21 11:55:42 ns02 named[6927]: transfer of 'ddns.lab/IN/dns.lab-cl01' from 192.168.50.10#53: connected using 192.168.50.11#34440
Aug 21 11:55:42 ns02 named[6927]: zone ddns.lab/IN/dns.lab-cl01: transferred serial 2711201408: TSIG 'zonetransfer.key'
Aug 21 11:55:42 ns02 named[6927]: transfer of 'ddns.lab/IN/dns.lab-cl01' from 192.168.50.10#53: Transfer completed: 1 messages, 5 records, 290 bytes, 0.011 secs (26363 bytes/sec)
Aug 21 11:55:42 ns02 named[6927]: zone ddns.lab/IN/dns.lab-cl01: sending notifies (serial 2711201408)
```




