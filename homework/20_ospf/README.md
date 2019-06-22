Т.к. провижининг ВМ выполняется с помощью ansible, то  ansible необходим на хостовой машине. VLANы еще не были мною изучены, поэтому ДЗ выполнено без VLANов. Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/20_ospf) и выполняем ```vagrant up```. По дефолту выполняется провижининг ВМ с симметричной маршрутизацией. Для выполнения провижининга с асимметричной маршрутизацией необходимо в [Vagrantfile](Vagrantfile) закомментировать плейбук с симметричной маршрутизацией и раскомментировать плейбук с асимметричной маршрутизацией.

После поднятия всех ВМ получаем такую схему коммутации серверов

СХЕМА

## Симметричная маршрутизация

СХЕМА

**Симметричная маршрутизация** получена увеличением cost на сервере abr02 на интерфейсе eth2 и увеличением cost на сервере br03 на интерфейсе eth2. В этом можно убедиться, залогинившись на br03 и отправив ICMP-ping на 5.5.5.5 (abr02) и прослушав интерфейсы с помощью tcpdump. Трафик пойдёт только через интерфейс eth1 (172.16.20.13):

```
[root@br03 ~]# tcpdump -i eth1 -p icmp -n
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
10:47:48.911440 IP 172.16.16.13 > 5.5.5.5: ICMP echo request, id 6513, seq 13, length 64
10:47:48.912925 IP 5.5.5.5 > 172.16.16.13: ICMP echo reply, id 6513, seq 13, length 64
```

Таблица маршрутизации на abr02:

```
abr02# show  ip route
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, A - Babel,
       > - selected route, * - FIB route
K>* 0.0.0.0/0 via 10.0.2.2, eth0
O>* 1.1.1.1/32 [110/60] via 172.16.12.11, eth1, 01:27:15
O   5.5.5.5/32 [110/10] is directly connected, lo, 02:48:32
C>* 5.5.5.5/32 is directly connected, lo
C>* 10.0.2.0/24 is directly connected, eth0
C>* 127.0.0.0/8 is directly connected, lo
O   172.16.12.0/24 [110/50] is directly connected, eth1, 01:27:15
C>* 172.16.12.0/24 is directly connected, eth1
O>* 172.16.16.0/24 [110/100] via 172.16.12.11, eth1, 00:06:44
O   172.16.20.0/24 [110/1000] is directly connected, eth2, 00:06:44
C>* 172.16.20.0/24 is directly connected, eth2
```

Таблица маршрутизации на br03:

```
br03# show  ip route
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, A - Babel,
       > - selected route, * - FIB route
K>* 0.0.0.0/0 via 10.0.2.2, eth0
O>* 1.1.1.1/32 [110/60] via 172.16.16.11, eth1, 02:48:43
O>* 5.5.5.5/32 [110/110] via 172.16.16.11, eth1, 01:27:33
C>* 10.0.2.0/24 is directly connected, eth0
C>* 127.0.0.0/8 is directly connected, lo
O>* 172.16.12.0/24 [110/100] via 172.16.16.11, eth1, 01:27:33
O   172.16.16.0/24 [110/50] is directly connected, eth1, 02:48:48
C>* 172.16.16.0/24 is directly connected, eth1
O   172.16.20.0/24 [110/1000] is directly connected, eth2, 00:07:53
C>* 172.16.20.0/24 is directly connected, eth2
```



## Асимметричная маршрутизация

СХЕМА

**Асимметричная маршрутизация** получена увеличением cost на интерфейсе eth2 (172.16.20.13) только на сервере br03. В этом можно убедиться, например, залогинившись на br03 и отправив ICMP-ping на 5.5.5.5 (abr02) и прослушав интерфейсы с помощью tcpdump. Трафик пойдёт abr01 (172.16.16.11 > 172.16.12.11) > abr02 (172.16.12.12 > 172.16.20.12) > br03 (172.16.20.13).

Вот результат такого пинга:

```
[root@br03 ~]# tcpdump -i eth1 -p icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
10:20:02.364723 IP br03 > 5.5.5.5: ICMP echo request, id 6413, seq 15, length 64
10:20:03.367022 IP br03 > 5.5.5.5: ICMP echo request, id 6413, seq 16, length 64
```

```
[root@br03 ~]# tcpdump -i eth2 -p icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth2, link-type EN10MB (Ethernet), capture size 262144 bytes
10:20:18.416860 IP 5.5.5.5 > br03: ICMP echo reply, id 6413, seq 31, length 64
10:20:19.419484 IP 5.5.5.5 > br03: ICMP echo reply, id 6413, seq 32, length 64
```

Таблица маршрутизации на br03:

```
br03# show  ip route
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, A - Babel,
       > - selected route, * - FIB route
K>* 0.0.0.0/0 via 10.0.2.2, eth0
O>* 1.1.1.1/32 [110/60] via 172.16.16.11, eth1, 02:30:26
O>* 5.5.5.5/32 [110/110] via 172.16.16.11, eth1, 01:09:16
C>* 10.0.2.0/24 is directly connected, eth0
C>* 127.0.0.0/8 is directly connected, lo
O>* 172.16.12.0/24 [110/100] via 172.16.16.11, eth1, 01:09:16
O   172.16.16.0/24 [110/50] is directly connected, eth1, 02:30:31
C>* 172.16.16.0/24 is directly connected, eth1
O   172.16.20.0/24 [110/150] via 172.16.16.11, eth1, 01:09:16
C>* 172.16.20.0/24 is directly connected, eth2
```

