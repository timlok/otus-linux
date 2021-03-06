# Заметки и нюансы

Т.к. провижининг ВМ выполняется с помощью ansible, то  ansible необходим на хостовой машине. Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/23_VLANs-LACP) и выполняем ```vagrant up```. 

Для того, чтобы существенно ускорить процесс провижининга всех ВМ можно в [соответствующем файле](https://github.com/timlok/otus-linux/blob/master/homework/23_VLANs-LACP/provisioning/01_tuning_OS/tasks/main.yml) плэйбука [01_tuning_OS.yml](https://github.com/timlok/otus-linux/blob/master/homework/23_VLANs-LACP/provisioning/01_tuning_OS.yml) закомментировать установку всех пакетов для всех ВМ. Но, нужно учесть, что для разрешения имён всеми ВМ в стенде, inetRouter требуется пакет dnsmasq.

В результате разворачивания стенда из [Vagrantfile](https://github.com/timlok/otus-linux/blob/master/homework/23_VLANs-LACP/Vagrantfile)  получаем схему коммутации всех ВМ (кроме inetRouter), в которой в одной внутренней VirtualBox-сети net-vlans находятся 4 VLANа и ВМ с одинаковыми ip-адресами. Собственно, сама схема:

![](https://github.com/timlok/otus-linux/blob/master/homework/23_VLANs-LACP/scheme/23_VLANs-LACP.png)

Уже сталкивался ранее с таким поведением ВМ через vagrant, но для того, чтобы на ВМ с centos 7 правильно подхватывались маршруты, пришлось в плэйбуках последовательно перезапустить сеть, отключить NetworkManager, перезагрузить ОС. Ранее, я исправлял такое удалением существующего маршрута по-умолчанию и назначением корректного маршрута по-умолчанию, но в данном случае я решил, чтобы правильные маршруты назначились сами. Как вариант можно было попробовать выполнить настройку сети через NetworkManager и, возможно, тогда не было бы проблем с маршрутами.

## Bonding и teaming

ВМ inetRouter на centos 6 и пакета teamd для этой ОС нет. Соответственно, на этой ВМ настроен bonding. На ВМ centralRouter с centos 7 интерфейсы настроены в teaming с помощью утилиты ```bond2team```.

## Выход в интернет

Доступ всех ВМ за пределы сетей данного стенда (в интернет) реализован с помощью:

- на inetRouter настроен NAT и маршруты для соответствующих локальных сетей
- на centralRouter настроена маршрутизация для соответствующих локальных сетей
- на inetRouter установлен и запущен dnsmasq
- на всех ВМ, кроме inetRouter, в качестве DNS указан inetRouter

Проверяем работу интернета, например, c ВМ testClient1:

```bash
[root@testClient1 /]# nslookup otus.ru
Server:         192.168.255.1
Address:        192.168.255.1#53

Non-authoritative answer:
Name:   otus.ru
Address: 80.87.192.10
```

```bash
[root@testClient1 ~]# traceroute otus.ru
traceroute to otus.ru (80.87.192.10), 30 hops max, 60 byte packets
 1  gateway (10.10.100.100)  0.565 ms  0.442 ms  0.304 ms
 2  192.168.255.1 (192.168.255.1)  0.692 ms  0.673 ms  0.695 ms
 3  * * *
 4  * * *
 5  * * *
 6  ae7.nvsk-rgr5.sib.ip.rostelecom.ru (213.228.109.46)  10.203 ms  6.215 ms  6.135 ms
 7  95.167.93.75 (95.167.93.75)  5.989 ms  9.403 ms  8.952 ms
 8  79.133.93.102 (79.133.93.102)  57.919 ms  56.869 ms  52.391 ms
 9  185.61.95.69 (185.61.95.69)  52.128 ms  51.976 ms  50.166 ms
10  89.22.16.155 (89.22.16.155)  49.335 ms  48.967 ms  48.723 ms
11  core.webdc.ru (92.63.108.98)  48.359 ms  51.675 ms  55.847 ms
12  otus.ru (80.87.192.10)  55.465 ms  55.146 ms  47.865 ms
```

