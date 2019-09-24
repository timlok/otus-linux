# ДЗ-33 (SMB, NFS)

## Задача:
> Vagrant стенд для NFS или SAMBA
> NFS или SAMBA на выбор:
>
> vagrant up должен поднимать 2 виртуалки: сервер и клиент
> на сервер должна быть расшарена директория
> на клиента она должна автоматически монтироваться при старте (fstab или autofs)
> в шаре должна быть папка upload с правами на запись
> \- требования для NFS: NFSv3 по  UDP, включенный firewall
>
> \* Настроить аутентификацию через KERBEROS

## Решение:

Для проверки ДЗ выкачиваем всё содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/33_fileserver/) и выполняем ```vagrant up```. В результате будет развернут простейший стенд из двух виртуальных машин - файлового сервера fileServer и клиента fileClient.

После настройки samba и NFS на файловом сервере fileServer включается firewalld и создаются правила для соответствующих сервисов. Соответственно, провижининг fileClient происходит с уже включённым firewalld.
На fileClient общие каталоги монтируются средствами systemd с помощью записей в /etc/fstab.
```bash
[vagrant@fileClient ~]$ systemctl list-units --type=automount
UNIT                              LOAD   ACTIVE SUB     DESCRIPTION
mnt-nfs.automount                 loaded active running mnt-nfs.automount
mnt-samba.automount               loaded active waiting mnt-samba.automount
proc-sys-fs-binfmt_misc.automount loaded active waiting Arbitrary Executable File Formats File System Automount Point

LOAD   = Reflects whether the unit definition was properly loaded.
ACTIVE = The high-level unit activation state, i.e. generalization of SUB.
SUB    = The low-level unit activation state, values depend on unit type.

3 loaded units listed. Pass --all to see loaded but inactive units, too.
```

### SMB

Настроен общий ресурс с полным гостевым доступом, но все клиентские подключения будут разрешены только для подсети 192.168.11.0/24.

На клиенте (fileClient) samba-шара автоматически монтируется при загрузке ОС с правами на чтение и запись пользователю vagrant. Собственно, создание каталога upload, указанного в задании, происходит c машины fileClient от имени пользователя vagrant в [соответствующем плейбуке](https://github.com/timlok/otus-linux/tree/master/homework/33_fileserver/provisioning/02_samba_client/tasks/main.yml).

На сервере (fileServer) в каталоге /var/log/samba сохраняются системные логи samba и логи клиентов в формате NetBIOS_name.log. Но надо иметь в виду, что файл лога клиента будет создан только в случае обращения клиента с помощью какого-либо ПО samba-клиента. Например, в результате выполнения такой команды на клиенте:
```bash
[vagrant@fileClient /]$ smbclient \\\\fileServer\\guest -U nobody% -c "mkdir upload2; ls"
Unable to initialize messaging context
  .                                   D        0  Mon Sep 23 20:04:14 2019
  ..                                  D        0  Sun Sep 22 21:09:30 2019
  upload                              D        0  Mon Sep 23 19:52:50 2019
  upload2                             D        0  Mon Sep 23 20:04:14 2019

                41921540 blocks of size 1024. 38771240 blocks available
```
Если шара примонтирована на клиенте, то файл лога NetBIOS_name.log создан не будет.

При всём при этом, в journald пишутся события аудита при любом типе подключения клиента:
```bash
[root@fileServer ~]# journalctl -b -n 0 -f | grep smbd
Sep 23 19:52:19 fileServer smbd[5836]: [2019/09/23 19:52:19.904417,  0] ../lib/util/become_daemon.c:138(daemon_ready)
Sep 23 19:52:19 fileServer smbd[5836]:   daemon_ready: STATUS=daemon 'smbd' finished starting up and ready to serve connections
Sep 23 19:52:21 fileServer smbd_audit[5841]: nobody|192.168.11.151|connect|ok|guest
Sep 23 19:52:21 fileServer smbd_audit[5841]: nobody|192.168.11.151|realpath|ok|/share/samba/guest
Sep 23 19:52:21 fileServer smbd_audit[5841]: nobody|192.168.11.151|connect|ok|IPC$
Sep 23 19:52:21 fileServer smbd_audit[5841]: nobody|192.168.11.151|realpath|ok|/tmp
Sep 23 19:52:29 fileServer smbd_audit[5841]: nobody|192.168.11.151|chdir|ok|chdir|/share/samba/guest
Sep 23 19:52:30 fileServer smbd_audit[5841]: nobody|192.168.11.151|open|ok|r|/share/samba/guest
Sep 23 19:52:30 fileServer smbd_audit[5841]: nobody|192.168.11.151|close|ok|/share/samba/guest
```

### NFS

NFSv3 работает по протоколу UDP, протокол версии 4 отключён на fileServer.
```bash
[root@fileClient ~]# mount -v fileServer:/share/nfs /mnt/nfs/
mount.nfs: timeout set for Sat Sep 21 23:23:23 2019
mount.nfs: trying text-based options 'vers=4.1,addr=192.168.11.150,clientaddr=192.168.11.151'
mount.nfs: mount(2): Protocol not supported
mount.nfs: trying text-based options 'vers=4.0,addr=192.168.11.150,clientaddr=192.168.11.151'
mount.nfs: mount(2): Protocol not supported
mount.nfs: trying text-based options 'addr=192.168.11.150'
mount.nfs: prog 100003, trying vers=3, prot=6
mount.nfs: trying 192.168.11.150 prog 100003 vers 3 prot TCP port 2049
mount.nfs: prog 100005, trying vers=3, prot=17
mount.nfs: trying 192.168.11.150 prog 100005 vers 3 prot UDP port 20048
```
```bash
[vagrant@fileClient ~]$ mount | grep nfs
sunrpc on /var/lib/nfs/rpc_pipefs type rpc_pipefs (rw,relatime)
systemd-1 on /mnt/nfs type autofs (rw,relatime,fd=23,pgrp=1,timeout=60,minproto=5,maxproto=5,direct,pipe_ino=44180)
fileServer:/share/nfs on /mnt/nfs type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=tcp,timeo=14,retrans=2,sec=sys,mountaddr=192.168.11.150,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.11.150)
```
Настроенный общий ресурс /share/nfs разрешён к монтированию только для машины с именем fileClient.
```bash
[root@fileClient ~]# showmount -e fileServer
Export list for fileServer:
/share/nfs fileClient
```
Uid и gid пользователя машины, которая монтирует ресурс мапятся в uid и gid пользователя vagrant на файловом сервере fileServer.

На клиенте (fileClient):
 - NFS-ресурс будет монтироваться только при обращении к точке монтирования и отмонтироваться через 60 секунд неактивности.
 - NFS-шара монтируется с правами на чтение и запись пользователю vagrant. Собственно, создание каталога upload, указанного в задании, происходит c машины fileClient от имени пользователя vagrant в [соответствующем плейбуке](https://github.com/timlok/otus-linux/tree/master/homework/33_fileserver/provisioning/03_nfs_client/tasks/main.yml).