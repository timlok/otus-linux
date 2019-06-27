Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/21_firewalld-iptables) и выполняем ```vagrant up```.

Схема коммутации серверов:

![](https://github.com/timlok/otus-linux/blob/master/homework/21_firewalld-iptables/scheme/scheme.png)

## Port Knocking

Port Knocking на inetRouter реализован с помощью iptables и чтобы проверить его работу логинимся на centralRouter и выполняем:

```
[vagrant@centralRouter ~]$ ./knock.sh 192.168.255.1 8881 7777 9991 && ssh 192.168.255.1
```



## Port Mapping

Т.к. необходимо проверить с хостовой машины доступность nginx на inetRouter2:8080, то, судя по всему, в 4м пункте ДЗ "4) пробросить 80й порт на inetRouter2 8080" подразумевалось направление трафика: inetRouter2:8080 > centralRouter > centralServer:80. Что я и реализовал в ДЗ с помощью firewalld.

Как и требовалось, на ВМ interRouter2 создал дополнительный сетевой интерфейс в режиме моста. В связи с этим, в (Vagrantfile)[] необходимо будет заменить его на сетевой интерфейс своего хоста и после полного запуска стенда, каким-либо образом узнать ip-адрес eth2 ВМ interRouter2. После чего, для проверки ДЗ на хосте открыть в браузере ссылку http://ip_ВМ_interRouter2:8080.
Так же, с помощью vagrant для удобства прокинул порт 8080 с ВМ interRouter2 на localhost:8081 хостовой машины. Таким образом, проверить работу проброса портов и nginx можно и вторым способом, обратившись на хосте в браузере по адресу [http://localhost:8081](http://localhost:8081).

