# ДЗ-31 (MySQL cluster)

## Задача:

> развернуть InnoDB кластер в docker
> * в docker swarm
>
> в качестве ДЗ принимает репозиторий с docker-compose
> который по кнопке разворачивает кластер и выдает порт наружу

Помимо указанного ДЗ так же было выполнено [альтернативное ДЗ](https://github.com/timlok/ansible-role-xtradb-cluster).

## Решение:

В Docker Swarm + Docker Stack собран кластер MySQL InnoDB на основе Percona Server for MySQL 8.0.16.

При подготовке ДЗ использованы технологии Docker Compose, Docker Swarm и Docker Stack.

Все подготовленные мною образы основаны на официальном docker-образе centos:7.

Для удобной проверки ДЗ достаточно выкачать всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/31_mysql_cluster/) и запустить ```vagrant up```. В результате будет развернута виртуальная машина, на которую с помощью ansible помимо других полезных пакетов будет установлен последний стабильный релиз docker, docker-compose, percona-server-client, percona-mysql-shell, а так же будет выполнен деплой [docker-compose_swarm.yml](/homework/31_mysql_cluster/flies/innodb_nosystemd/swarm/docker-compose_swarm.yml).

К сожалению, тесты деплоя на только что развернутую ВМ в Vagrant показали, что двух минут, указанных в скрипте [пересборки кластера](/homework/31_mysql_cluster/flies/innodb_nosystemd/mysqlRouter/cluster_reconfigure.sh) бывает недостаточно для завершения GTID репликации между нодами. Лог ноды mysqlrouter будет таким:
```bash
[root@dockermysql ~]# docker logs -f -t percona-mysql8-innodb_mysqlrouter.1.veacu68x6i8g3ydk422uu1u8b
2019-09-18T16:31:23.100242518Z
2019-09-18T16:31:23.100267932Z #########################################################
2019-09-18T16:31:23.100272588Z ##### The cluster reconfiguration script is running #####
2019-09-18T16:31:23.100275675Z #########################################################
2019-09-18T16:31:23.100278762Z
2019-09-18T16:31:23.100281632Z Waiting 120 seconds before starting work
2019-09-18T16:31:23.100284590Z
2019-09-18T16:33:22.763246081Z WARNING: Using a password on the command line interface can be insecure.
2019-09-18T16:33:22.945518030Z Dba.rebootClusterFromCompleteOutage: Cannot perform operation while group replication is starting up (RuntimeError)
2019-09-18T16:33:22.945604342Z  at (command line):1:18
2019-09-18T16:33:22.945620816Z in var cluster = dba.rebootClusterFromCompleteOutage();
2019-09-18T16:33:22.945631281Z                      ^
2019-09-18T16:33:22.981999818Z
2019-09-18T16:33:22.982080588Z !!! mysql01 is NOT RW !!!
2019-09-18T16:33:22.982130766Z
2019-09-18T16:33:22.982143051Z Trying mysql02
2019-09-18T16:33:22.982152222Z
2019-09-18T16:33:23.081054349Z WARNING: Using a password on the command line interface can be insecure.
2019-09-18T16:33:23.219703362Z Dba.rebootClusterFromCompleteOutage: Cannot perform operation while group replication is starting up (RuntimeError)
2019-09-18T16:33:23.219783780Z  at (command line):1:18
2019-09-18T16:33:23.219798571Z in var cluster = dba.rebootClusterFromCompleteOutage();
2019-09-18T16:33:23.219807717Z                      ^
2019-09-18T16:33:23.239326022Z
2019-09-18T16:33:23.239399013Z !!! mysql02 is NOT RW !!!
2019-09-18T16:33:23.239411976Z
2019-09-18T16:33:23.239420592Z trying mysql03
2019-09-18T16:33:23.239428755Z
2019-09-18T16:33:23.343867406Z WARNING: Using a password on the command line interface can be insecure.
2019-09-18T16:33:23.474253965Z Dba.rebootClusterFromCompleteOutage: Cannot perform operation while group replication is starting up (RuntimeError)
2019-09-18T16:33:23.474322021Z  at (command line):1:18
2019-09-18T16:33:23.474335115Z in var cluster = dba.rebootClusterFromCompleteOutage();
2019-09-18T16:33:23.474344034Z                      ^
2019-09-18T16:33:23.497849714Z
2019-09-18T16:33:23.497922987Z !!! mysql03 is NOT RW !!!
2019-09-18T16:33:23.497935614Z
2019-09-18T16:33:23.497943772Z WARNING! All servers is NOT RW!
2019-09-18T16:33:23.497952037Z
2019-09-18T16:33:27.518665854Z #########################################################
2019-09-18T16:33:27.518752919Z #####   Cluster reconfiguration script completed    #####
2019-09-18T16:33:27.518927141Z #####             SCRIPT EXIT CODE = 1              #####
2019-09-18T16:33:27.518968315Z #####               RW SERVER ABSENT!               #####
2019-09-18T16:33:27.519002570Z #########################################################
```

В этом случае, необходимо передеплоить кластер или через пару минут повторно запустить скрипт переконфигурирования кластера вручную, например, таким образом:
```bash
[root@dockermysql ~]# docker exec -ti percona-mysql8-innodb_mysqlrouter.1.veacu68x6i8g3ydk422uu1u8b bash /opt/cluster_reconfigure.sh

#########################################################
##### The cluster reconfiguration script is running #####
#########################################################

Waiting 120 seconds before starting work

WARNING: Using a password on the command line interface can be insecure.
Reconfiguring the default cluster from complete outage...

The instance 'mysql02:3306' was part of the cluster configuration.

The instance 'mysql03:3306' was part of the cluster configuration.


The cluster was successfully rebooted.

Fine! mysql01 is RW
#########################################################
#####   Cluster reconfiguration script completed    #####
#####             SCRIPT EXIT CODE = 0              #####
#####               RW SERVER mysql01               #####
#########################################################
```

[Ручная проверка ДЗ](/homework/31_mysql_cluster/flies/innodb_nosystemd/_info/проверка_кластера.md)

Ниже будет приведено короткое описание проделанной работы. Ссылки на интересующие файлы и листинги указаны в соответствующих заголовках.

### [Файлы и описание работы с systemd (только Docker Compose)](/homework/31_mysql_cluster/flies/innodb_systemd/)

[docker-compose.yml](/homework/31_mysql_cluster/flies/innodb_systemd/compose/docker-compose.yml)

Первоначально были подготовлены образы с использованием systemd, но из-за ограничений технологии такие образы оказались мало пригодны для использования в Docker Swarm. В частности, для полноценного запуска systemd в контейнере, контейнер должен быть запущен, как привилегированный, т.к. systemd требуется возможность (capability) CAP_SYS_ADMIN, но Docker отбрасывает эту возможность в непривилегированных контейнерах, чтобы повысить безопасность. В свою очередь, в Docker Swarm нельзя запустить контейнер в привилегированном режиме.

Так же, на этапе создания кластера в ipWhitelist я указал конкретные имена хостов mysql01, mysql02, mysql03. А в этом случае, InnoDB кластер должен уметь разрешать имена в ip-адреса. При этом, после перезапуска контейнера с какой-нибудь нодой, docker присваивает этому контейнеру новый ip-адрес, но кластер помнит старое сопоставление имени и ip-адреса и не пускает ноду в кластер. В этом случае, встроенный в docker своеобразный DNS тоже повёл себя не идеально и не сразу после запуска нового контейнера отдавал корректные сопоставления. В связи с этим, проблема была решена жёстким присваиванием ip-адресов контейнерам и прописыванием ip-адресов и имён в файл /etc/hosts на каждой ноде.

После запуска (или перезапуска) всех нод кластер оказывается в неработоспособном состоянии и требует переконфигурирования. И это нормально. Задача ожидания и пересборки кластера после запуска docker-compose решена созданием systemd-таймера, который срабатывает при запуске контейнера с mysqlrouter. Конечно, для использования в продуктивной среде стоит добавить проверку доступности нужных портов или выполнять пересборку только после успешного подключения по порту tcp:3306 ко всем трём нодам, но в данном случае я обошёлся банальным ожиданием в 10 секунд.

Таймер выполняет такой скрипт:

```bash
#!/usr/bin/env bash
sleep 10
echo -e "y\ny\n"| /usr/bin/mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "var cluster = dba.rebootClusterFromCompleteOutage();"
sleep 10
```

Не смотря на всё выше сказанное, привожу описание работы и файл [docker-compose.yml](/homework/31_mysql_cluster/flies/innodb_systemd/compose/docker-compose.yml). Кластер развёрнутый с помощью команды ```docker-compose up``` из этого файла отлично работает.

В принципе, использование контейнеров с systemd достаточно удобно, т.к. в Dockerfile указываем просто 

```bash
CMD ["/usr/sbin/init"]
```

и включаем в systemd все необходимые сервисы, таймеры и т.д. Правда, такой подход не совсем соответствует концепции использования docker, где для каждого сервиса (задачи) подразумевается свой образ. Фактически, при использовании systemd docker-образ по своему функционалу превращается в своеобразную виртуальную машину. А это уже контейнеры LXC, LXD и т.д. и т.п.

Из очевидных минусов использования systemd в docker можно отметить невозможность использовать таких образов в Docker Swarm и небольшое увеличение размера образа.

### [Файлы и описание работы без systemd (Docker Swarm, Docker Stack)](/homework/31_mysql_cluster/flies/innodb_nosystemd/)

[docker-compose_swarm.yml](/homework/31_mysql_cluster/flies/innodb_nosystemd/swarm/docker-compose_swarm.yml)

Помимо необходимы пакетов от percona в образы установлены bash, net-tools, nmap, screen. Это не способствует уменьшению размера образа, но благоприятствует комфортной работе внутри контейнера. ;)

Второй вариант образов подготовлен без использования systemd и с docker-compose даже не тестировался. Тем не менее, работает в оркестраторе Docker Swarm через Docker Stack. Для простоты все контейнеры MySQL InnoDB кластера разворачиваются на одной manager-ноде docker swarm.

При подготовке этого варианта я учёл описанные ранее проблемы.

На этапе создания кластера в ipWhitelist мною указана вся подсеть 172.20.20.0/24 выделенная для работы запущенных контейнеров. Но этого можно было и не делать, т.к. если ничего не указать в ipWhitelist, то MySQL сам укажет всю локальную сеть.

Переконфигурирование кластера после запуска всех нод происходит там, же на ноде mysqlrouter, но с помощью скрипта [cluster_reconfigure.sh](/homework/31_mysql_cluster/flies/innodb_nosystemd/mysqlRouter/cluster_reconfigure.sh) прописанного в качестве ENTRYPOINT. На этот раз, скрипт ждёт две минуты и до первого удачного результата по очереди подключается к каждой ноде и запускает процесс пересборки кластера. Причина такого подхода - пересборка кластера должна выполняться только на RW-ноде. Результат работы скрипта можно увидеть в логе контейнера mysqlrouter (будет приведён далее).

На этапе финального тестирования заметил, что если увеличить количество реплик mysqlrouter, например, до двух, то скрипт переконфигурирования кластера запускается одновременно на обоих репликах и кластер не может собраться. В связи с этим, становится очевидно, что задачу переконфигурирования кластера необходимо вынести на отдельную ноду.