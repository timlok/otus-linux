# Заметки к ДЗ-26 (динамический веб контент)

Т.к. провижининг ВМ выполняется с помощью ansible, то  ansible необходим на хостовой машине. При этом, требуется ansible => 2.8, т.к. в модуле copy используется параметр remote_src. Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/26_dynamic_web) и выполняем ```vagrant up```. 

Установлены веб-сервера и фреймворки: php-fpm, laravel, uwsgi/django и nodejs/reactjs. Всё это работает за nginx. Соответственно, внутрь гостевой ОС проброшены порты:
laravel - [http://127.0.0.1:8081](http://127.0.0.1:8081)
uwsgi/django - [http://127.0.0.1:8082](http://127.0.0.1:8082)
django-админка [http://127.0.0.1:8082/admin/](http://127.0.0.1:8082/admin/) (логин admin, пароль password)
nodejs/reactjs - [http://127.0.0.1:8083](http://127.0.0.1:8083)

Сервисы php-fpm и uwsgi взаимодействуют с nginx через соответствующие unix-сокеты.
Пока не удалось через ansible правильно создать изолированное python-окружение для последующего создания в нём тестового django-приложения. Поэтому в ВМ копируются подготовленные мною соответствующие структуры каталогов Env и firstsite.
Тестовый экземпляр uwsgi настроен на работу от имени пользователя django, для которого основная группа nginx. Так же uwsgi настроен в качестве сервиса systemd.

```bash
[root@dynweb ~]# ps aux | grep uwsgi
root      7997  0.0  0.1  25340  2052 ?        Ss   12:10   0:00 /usr/bin/uwsgi --emperor /etc/uwsgi/sites
django    7999  0.0  1.4 249644 26796 ?        S    12:10   0:00 /usr/bin/uwsgi --ini firstsite.ini
django    8078  0.0  1.4 252776 26860 ?        S    12:10   0:00 /usr/bin/uwsgi --ini firstsite.ini
django    8079  0.0  1.4 253024 27200 ?        S    12:10   0:00 /usr/bin/uwsgi --ini firstsite.ini
django    8080  0.0  1.3 252300 26264 ?        S    12:10   0:00 /usr/bin/uwsgi --ini firstsite.ini
django    8081  0.0  1.3 251620 25708 ?        S    12:10   0:00 /usr/bin/uwsgi --ini firstsite.ini
django    8082  0.0  1.3 251508 25464 ?        S    12:10   0:00 /usr/bin/uwsgi --ini firstsite.ini
```

```bash
[root@dynweb ~]# systemctl status uwsgi
● uwsgi.service - uWSGI Emperor service
   Loaded: loaded (/etc/systemd/system/uwsgi.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2019-07-29 12:35:32 UTC; 5s ago
  Process: 8684 ExecStartPre=/usr/bin/bash -c mkdir -p /run/uwsgi; chown django:nginx /run/uwsgi (code=exited, status=0/SUCCESS)
 Main PID: 8688 (uwsgi)
   Status: "The Emperor is governing 1 vassals"
   CGroup: /system.slice/uwsgi.service
           ├─8688 /usr/bin/uwsgi --emperor /etc/uwsgi/sites
           ├─8691 /usr/bin/uwsgi --ini firstsite.ini
           ├─8696 /usr/bin/uwsgi --ini firstsite.ini
           ├─8697 /usr/bin/uwsgi --ini firstsite.ini
           ├─8698 /usr/bin/uwsgi --ini firstsite.ini
           ├─8699 /usr/bin/uwsgi --ini firstsite.ini
           └─8700 /usr/bin/uwsgi --ini firstsite.ini

Jul 29 12:35:33 dynweb uwsgi[8688]: WSGI app 0 (mountpoint='') ready in 1 seconds on interpreter 0x119f070 pid: 8691 (default app)
Jul 29 12:35:33 dynweb uwsgi[8688]: *** uWSGI is running in multiple interpreter mode ***
Jul 29 12:35:33 dynweb uwsgi[8688]: spawned uWSGI master process (pid: 8691)
Jul 29 12:35:33 dynweb uwsgi[8688]: Mon Jul 29 12:35:33 2019 - [emperor] vassal firstsite.ini has been spawned
Jul 29 12:35:33 dynweb uwsgi[8688]: spawned uWSGI worker 1 (pid: 8696, cores: 1)
Jul 29 12:35:33 dynweb uwsgi[8688]: spawned uWSGI worker 2 (pid: 8697, cores: 1)
Jul 29 12:35:33 dynweb uwsgi[8688]: spawned uWSGI worker 3 (pid: 8698, cores: 1)
Jul 29 12:35:33 dynweb uwsgi[8688]: spawned uWSGI worker 4 (pid: 8699, cores: 1)
Jul 29 12:35:33 dynweb uwsgi[8688]: spawned uWSGI worker 5 (pid: 8700, cores: 1)
Jul 29 12:35:33 dynweb uwsgi[8688]: Mon Jul 29 12:35:33 2019 - [emperor] vassal firstsite.ini is ready to accept requests
```


