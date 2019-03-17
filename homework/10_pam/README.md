В моих скриптах есть комментарии. В этом файле будут только заметки и описание особенностей при выполнении ДЗ. Просто запускаете `vagrant up` и в выводе всё будет написано. Конечно, перед запуском нужно скопировать себе всё содержимое этого [каталога](https://github.com/timlok/otus-linux/tree/master/homework/10_pam).

# Первая часть ДЗ (модули PAM)

Внимание! Если будете тестировать возможность логина в ВМ по ssh, то в [Vagrantfile](Vagrantfile) укажите сетевой интерфейс своего хоста для работы в режиме моста!

Для определения праздничный день или выходной я использовал сервис [isDayOff()](https://isdayoff.ru/). В связи с этим, каждый раз при логине пользователя скрипт [pam_script_auth](files/pam_script_auth) обращается через интернет к этому сервису. Конечно, использовать какой-либо локальный вариант (например, pam_time.so и файл со списком праздничных дат) было бы гораздо быстрее. Можно было сделать кеширование результата хотя бы с сегодняшней датой или выкачивать БД сервиса локально и с ней и работать. Из-за всех этих нюансов не стоит использовать мой  [pam_script_auth](files/pam_script_auth) в реальной практике, но задачи поставленные в ДЗ он выполняет. ;)

Как выяснилось, есть определенные нюансы в моей версии centos и в пакете pam_script:

```
[root@otuspam ~]# cat /etc/redhat-release
CentOS Linux release 7.6.1810 (Core)
```

```
[root@otuspam ~]# rpm -qa | grep pam_script
pam_script-1.1.8-1.el7.x86_64
```

```
[root@otuspam ~]# rpm -ql pam_script
/etc/pam-script.d
/etc/pam_script
/etc/pam_script_acct
/etc/pam_script_auth
/etc/pam_script_passwd
/etc/pam_script_ses_close
/etc/pam_script_ses_open
/lib64/security/pam_script.so
/usr/share/doc/pam_script-1.1.8
/usr/share/doc/pam_script-1.1.8/AUTHORS
/usr/share/doc/pam_script-1.1.8/COPYING
/usr/share/doc/pam_script-1.1.8/ChangeLog
/usr/share/doc/pam_script-1.1.8/NEWS
/usr/share/doc/pam_script-1.1.8/README
/usr/share/doc/pam_script-1.1.8/README.pam_script
/usr/share/man/man7/pam-script.7.gz
```

Если в файле с именем демона пишем такое:

```
auth required  pam_script.so
```

то будет исполняться скрипт `pam_script_auth`, а ни как не `pam_script`

И так для каждого модуля.

Соответственно, если указываем свой каталог со скриптами:

```
auth required  pam_script.so dir=/etc/pam-script.d/
```

то (и это очевидно) в этом указанном каталоге будут искаться скрипты для каждого модуля (pam_script_auth, pam_script_acct, pam_script_passwd, pam_script_ses_open, pam_script_ses_close), а ни как не скрипт pam_script.

# Вторая часть ДЗ (capabilities)

Мой [скрипт](files/02_capabilities.sh) применяет возможности (capabilities) к бинарникам, в наследуемом режиме. Это позволяет задействовать эти возможности только пользователю с такими же эффективными возможностями. Пользователь без установленных возможностей сможет запускать бинарники только со своими правами и не более того. Теоретически  (с высоты моих знаний), такая логика должна быть вполне безопасна. Как результат, пользователь user3 может успешно выполнить команду `cat /etc/shadow` или перейти в домашний каталог пользователя root, другие пользователи этого сделать не могут.

Так и не удалось настроить применение возможностей (capabilities) сразу же при логине пользователя user3 по ssh. Поэтому, чтобы возможности применились после успешного логина по ssh нужно выполнить `su user3`. 