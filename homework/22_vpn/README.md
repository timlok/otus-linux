# Заметки к ДЗ-22

Т.к. провижининг ВМ выполняется с помощью ansible, то  ansible необходим на хостовой машине. Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/22_vpn) и выполняем ```vagrant up```. По дефолту выполняется провижининг ВМ с tap и tcp. Для выполнения провижининга с tun и udp необходимо в [Vagrantfile](Vagrantfile) закомментировать плейбук с именем ```_tcp``` и раскомментировать плейбук с именем ```_udp```.

Логическая схема коммутации интерфейсов:
![](https://github.com/timlok/otus-linux/blob/master/homework/22_vpn/scheme/scheme.png)

Клиентам доступна сеть своего физического сетевого адаптера и сеть 10.10.150.0/24 на openvpn-интерфейсе.
Openvpn работает в качестве сервиса systemd и его запуск на openvpnServer выглядит так:

```
systemctl start openvpn@vpn-server
```

На openvpnClient1 и openvpnClient2, соответственно, так:

```
systemctl start openvpn@vpn-client
```

На openvpnServer один из интерфейсов настроен в режиме моста. Соответственно, чтобы проверить работу RAS (Remote Access Server) со своего хоста нужно скопировать себе на хост файлы из каталога [host]() и с их помощью создать на своём хосте клиентское подключение openvpn. При этом, в файле [22_vpn_host_tap-tcp.conf]() или [22_vpn_host_tun-udp.conf]() необходимо заменить ```ip_openvpnServer``` на ip-адрес ВМ openvpnServer на соответствующем интерфейсе.


На openvpnServer установлен Easy-RSA 3, поэтому с помощью него можно полноценно управлять всеми сертификатами и ключами. При этом, пароль для корневого сертификата удостоверяющего центра - 1234.

Например, так можно сгенерировать ключ и сертификат для нового openvpn-клиента client111:

```
cd /usr/share/easy-rsa/3.0.3
. ./vars
./easyrsa gen-req client111 nopass
./easyrsa sign-req client client111
```

В результате, получаем файлы:

```
/usr/share/easy-rsa/3.0.3/pki/private/client111.key
/usr/share/easy-rsa/3.0.3/pki/issued/client111.crt
```

**Тестирование пропускной способности** (tcp) показало, что самый медленный вариант работы openvpn, это связка tap и tcp, а самый быстрый tun и udp.

tup и tcp:

```
[root@openvpnServer ~]# iperf3 -s
Server listening on 5201
Accepted connection from 10.10.150.10, port 49480
[  5] local 10.10.150.1 port 5201 connected to 10.10.150.10 port 49482
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec  17.7 MBytes   148 Mbits/sec
[  5]   1.00-2.00   sec  18.8 MBytes   158 Mbits/sec
[  5]   2.00-3.01   sec  20.5 MBytes   171 Mbits/sec
[  5]   3.01-4.01   sec  20.6 MBytes   172 Mbits/sec
[  5]   4.01-5.00   sec  18.5 MBytes   157 Mbits/sec
[  5]   5.00-6.00   sec  20.8 MBytes   175 Mbits/sec
[  5]   6.00-7.01   sec  20.6 MBytes   171 Mbits/sec
[  5]   7.01-8.00   sec  18.9 MBytes   160 Mbits/sec
[  5]   8.00-9.00   sec  21.4 MBytes   179 Mbits/sec
[  5]   9.00-10.00  sec  22.0 MBytes   185 Mbits/sec
[  5]  10.00-10.14  sec  2.08 MBytes   124 Mbits/sec

------

[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-10.14  sec  0.00 Bytes  0.00 bits/sec                  sender
[  5]   0.00-10.14  sec   202 MBytes   167 Mbits/sec                  receiver
```

```
[root@openvpnClient1 ~]# iperf3 -c 10.10.150.1
Connecting to host 10.10.150.1, port 5201
[  4] local 10.10.150.10 port 49482 connected to 10.10.150.1 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-1.00   sec  20.1 MBytes   168 Mbits/sec    0    396 KBytes
[  4]   1.00-2.00   sec  18.6 MBytes   157 Mbits/sec    0    680 KBytes
[  4]   2.00-3.00   sec  20.9 MBytes   175 Mbits/sec    0    876 KBytes
[  4]   3.00-4.01   sec  20.8 MBytes   173 Mbits/sec    0    876 KBytes
[  4]   4.01-5.00   sec  18.3 MBytes   154 Mbits/sec    0    876 KBytes
[  4]   5.00-6.00   sec  20.5 MBytes   172 Mbits/sec    0    876 KBytes
[  4]   6.00-7.00   sec  20.4 MBytes   171 Mbits/sec    0    876 KBytes
[  4]   7.00-8.00   sec  18.8 MBytes   158 Mbits/sec    0    876 KBytes
[  4]   8.00-9.00   sec  21.7 MBytes   182 Mbits/sec    0    876 KBytes
[  4]   9.00-10.01  sec  22.3 MBytes   186 Mbits/sec    0    876 KBytes

------

[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.01  sec   202 MBytes   170 Mbits/sec    0             sender
[  4]   0.00-10.01  sec   202 MBytes   169 Mbits/sec                  receiver

iperf Done.
```


tun и udp:

```
[root@openvpnServer ~]# iperf3 -s
Server listening on 5201
Accepted connection from 10.10.150.10, port 36140
[  5] local 10.10.150.1 port 5201 connected to 10.10.150.10 port 36142
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec  35.3 MBytes   296 Mbits/sec
[  5]   1.00-2.00   sec  36.3 MBytes   304 Mbits/sec
[  5]   2.00-3.00   sec  38.6 MBytes   323 Mbits/sec
[  5]   3.00-4.00   sec  37.3 MBytes   312 Mbits/sec
[  5]   4.00-5.00   sec  37.0 MBytes   312 Mbits/sec
[  5]   5.00-6.00   sec  37.3 MBytes   313 Mbits/sec
[  5]   6.00-7.00   sec  36.9 MBytes   310 Mbits/sec
[  5]   7.00-8.00   sec  36.5 MBytes   306 Mbits/sec
[  5]   8.00-9.00   sec  38.0 MBytes   319 Mbits/sec
[  5]   9.00-10.00  sec  35.5 MBytes   298 Mbits/sec
[  5]  10.00-10.05  sec  1.68 MBytes   283 Mbits/sec

------

[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-10.05  sec  0.00 Bytes  0.00 bits/sec                  sender
[  5]   0.00-10.05  sec   370 MBytes   309 Mbits/sec                  receiver
```

```
[root@openvpnClient1 ~]# iperf3 -c 10.10.150.1
Connecting to host 10.10.150.1, port 5201
[  4] local 10.10.150.10 port 36142 connected to 10.10.150.1 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-1.01   sec  37.7 MBytes   314 Mbits/sec   20    320 KBytes
[  4]   1.01-2.00   sec  36.9 MBytes   312 Mbits/sec   35    184 KBytes
[  4]   2.00-3.00   sec  38.1 MBytes   320 Mbits/sec   32    158 KBytes
[  4]   3.00-4.00   sec  37.2 MBytes   312 Mbits/sec   11    208 KBytes
[  4]   4.00-5.00   sec  37.8 MBytes   316 Mbits/sec   50    171 KBytes
[  4]   5.00-6.01   sec  37.5 MBytes   313 Mbits/sec    2    219 KBytes
[  4]   6.01-7.00   sec  36.0 MBytes   304 Mbits/sec   18    257 KBytes
[  4]   7.00-8.00   sec  36.4 MBytes   304 Mbits/sec   12    225 KBytes
[  4]   8.00-9.00   sec  38.5 MBytes   324 Mbits/sec    8    256 KBytes
[  4]   9.00-10.00  sec  35.6 MBytes   298 Mbits/sec   26    205 KBytes

------

[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec   372 MBytes   312 Mbits/sec  214             sender
[  4]   0.00-10.00  sec   370 MBytes   311 Mbits/sec                  receiver

iperf Done.
```



