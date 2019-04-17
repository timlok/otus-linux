# Заметки по ДЗ-14 (сбор и анализ логов)

Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/14_%D0%BB%D0%BE%D0%B3%D0%B8) и выполняем

```
vagrant up
```

На этот раз, за неимением времени я не стал автоматизировать проверку ДЗ и его вывод при провижининге ВМ.

## Rsyslog

Эта опция конфига rsyslog-клиента

```
*.crit @log-server:514
```

должна отправлять все критичные и выше сообщения на rsyslog-сервер, но мне так и не удалось получить ни одно критичное сообщение, чтобы проверить работу этой опции. Тем не менее, более информативные уровни (debug, info и т.д.) отлично отрабатывают.

## Nginx

На web-server устанавливается nginx последней версии из репозитория mainline, т.к. только начиная с  версии 1.15.2 nginx позволяет использовать несколько директив ```error_log``` и ```access_log``` в одном контексте. Для разделения логов nginx я воспользовался именно этой возможностью.

### Проверка:

На web-server правим конфиг ```nginx.conf``` внося туда заведомую ошибку и заставляем nginx перечитать конфигурацию:

```
systemctl reload nginx.service
```

В результате на log-server в соответствующем файле увидим и лог доступа (curl в [Vagrantfile](Vagrantfile)) и лог ошибок:

```
[root@log-server ~]# cat /var/log/remote-hosts/web-server/nginx.log  
2019-04-17T15:09:32+00:00 web-server nginx: 172.17.177.22 - - [17/Apr/2019:15:09:32 +0000] "GET / HTTP/1.1" 200 3743 "-" "curl/7.29.0"
"2019-04-17T15:14:21+00:00 web-server nginx: 2019/04/17 15:14:21 [emerg] 6071#6071: unknown directive "TEST" in /etc/nginx/nginx.conf:5
```

При этом, на web-server будет только лог критических ошибок:

```
[root@web-server ~]# ll /var/log/nginx/
total 4
-rw-r-----. 1 nginx adm   0 Apr 17 15:08 access.log
-rw-r-----. 1 nginx adm 182 Apr 17 15:14 error.log
```

## Auditd

Далее проверяем лог auditd на log-server:

```
[root@log-server ~]# grep nginx_config_change /var/log/audit/audit.log   
node=web-server type=CONFIG_CHANGE msg=audit(1555513772.141:1986): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="**nginx_config_change**" list=4 res=1
node=web-server type=SYSCALL msg=audit(1555513990.064:2040): arch=c000003e syscall=2 success=yes exit=3 a0=dcb6f0 a1=0 a2=0 a3=7ffedf9f5760 items=1 ppid=7260 pid=7295 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0
 egid=0 sgid=0 fsgid=0 tty=pts0 ses=5 comm="vi" exe="/usr/bin/vi" subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 key="**nginx_config_change**"
```

