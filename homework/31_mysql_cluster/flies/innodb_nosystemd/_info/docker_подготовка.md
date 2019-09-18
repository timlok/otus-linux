# docker_подготовка

## план:

1. создать сеть
docker network create --internal --attachable --subnet=172.20.20.0/24 mysql-nosystemd-net
2. настроить каждый контейнер по отдельности с указанием сети при запуске контейнера и ip-адреса в этой сети
например,
docker run --net mysql-nosystemd-net --ip 172.20.20.151 -it ubuntu bash
3. сделать образы
4. собрать образы в compose и в нём указать эту же сеть и эти же самые ip
последним должен запускаться образ, например, с mysqlRouter или mysql-shell и он же и должен скриптом из энтрипоинт собирать кластер
5. docker swarm

## вопросы:

1. сеть и адресация
2. сделать энтрипоинт или просто в docker-compose.yml указать команду при запуске mysqlrouter
Если делать командой, то нужно будет взять исходную команду из Dockerfile и добавить к ней команду сборки кластера
command: ["bundle", "exec", "thin", "-p", "3000"]
3. зависимости
нужно, чтобы контейнер с mysqlrouter запускался после всех контейнеров mysql01-03
    depends_on:
      - mysql01
      - mysql02
      - mysql03
4. задержка запуска mysqlrouter после готовности контейнеров mysq01-03
или ожидание 20 секунд
или реальный скрипт проверки сервисов
https://docs.docker.com/compose/startup-order/

5. вольюмы под БД
volumes:
      - db-data:/var/lib/postgresql/data
описание вольюма
volumes:
         db-data:

6. при добавлении нод в кластер указать в качестве белого списка всю подсеть 172.20.20.0/24
7. установить cron на mysqlrouter, переделать и запускать пересборку кластера через cron
или запускать пересборку кластера через entrypoint в контейнере mysqlrouter
8. собрать новые контейнеры без systemd, указать в них правильные команды в строке запуска и учесть пункты 6 и 7.
Установить этим контейнерам тэг swarm, но не удалять контейнеры с тэгом v3 (они отличные примеры для контейнеров с systemd и для compose)

## Работа, собственно

на хосте с docker создаём сеть mysql-nosystemd-net
```bash
[root@docker ~]# docker network create --internal --attachable --subnet=172.20.20.0/24 mysql-nosystemd-net
d719a5d67a52c2497c12ebf5e30a8e68f569dbae2d1f603d87beb816901700e6
```
проверяем, что сеть появилась и имеет правильные параметры
```bash
[root@docker ~]# docker network ls
NETWORK ID          NAME                   DRIVER              SCOPE
18f131a77821        bridge                 bridge              local
633ecdb4cd60        compose_nginx-phpfpm   bridge              local
efb6886342f8        host                   host                local
d719a5d67a52        mysql-nosystemd-net              bridge              local
98b3c530296c        none                   null                local
```
```json
[root@docker ~]# docker network inspect mysql-nosystemd-net 
[
    {
        "Name": "mysql-nosystemd-net",
        "Id": "d719a5d67a52c2497c12ebf5e30a8e68f569dbae2d1f603d87beb816901700e6",
        "Created": "2019-09-12T13:31:21.517857157Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "172.20.20.0/24"
                }
            ]
        },
        "Internal": true,
        "Attachable": true,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {}
    }
]
```
на основе образа centos:7 создаём образ с чистой установкой percona-mysql8
Dockerfile:
```dockerfile
FROM centos:7
COPY my.cnf /root/.my.cnf
COPY screenrc /root/.screenrc

RUN rpm --import https://www.percona.com/downloads/RPM-GPG-KEY-percona; \
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
percona-release setup ps80; \
yum -y install bash net-tools nmap screen percona-server-server percona-mysql-shell; \
yum clean all; \
chmod 600 /root/.my.cnf; \
chown root. /root/.my.cnf

CMD ["/usr/sbin/mysqld", "--user=mysql"]
```
```bash
docker build -t local/c7-mysql-clean .
```