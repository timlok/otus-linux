# Установка zfs со снапшотами и диском под кеш на centos7

устанавливаем нужное

    yum -y install epel-release kernel-devel

[отсюда](https://github.com/zfsonlinux/zfs/wiki/RHEL-and-CentOS) выбираем правильный репозиторий и устанавливаем из него zfs

    yum install http://download.zfsonlinux.org/epel/zfs-release.el7_5.noarch.rpm

в файле /etc/yum.repos.d/zfs.repo выключаем репозиторий zfs и включаем zfs-kmod

устанавливаем zfs
    
    yum -y install zfs zfs-dracut


загружаем модуль ядра и проверяем, что он загрузился

    modprobe zfs && lsmod | grep zfs

смотрим, какие диски мы можем использовать

    lsblk
    NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    sda                       8:0    0   40G  0 disk 
    ├─sda1                    8:1    0    1M  0 part 
    ├─sda2                    8:2    0    1G  0 part /boot
    └─sda3                    8:3    0   39G  0 part 
    ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
    └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
    sdb                       8:16   0   10G  0 disk 
    sdc                       8:32   0    2G  0 disk 
    sdd                       8:48   0    1G  0 disk 
    sde                       8:64   0    1G  0 disk 

создаем пул из трех дисков с именем otuszpool с включенными снапшотами и кешкем на диске /dev/sde

    zpool create -o listsnapshots=on otuszpool /dev/sdb /dev/sdc /dev/sdd cache /dev/sde

смотрим, что у нас получилось
    
    zpool list
    NAME        SIZE  ALLOC   FREE  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
    otuszpool  12.9G   106K  12.9G         -     0%     0%  1.00x  ONLINE  -
    
    zpool status
    pool: otuszpool
    state: ONLINE
    scan: none requested
    config:
    
        NAME        STATE     READ WRITE CKSUM
        otuszpool   ONLINE       0     0     0
          sdb       ONLINE       0     0     0
          sdc       ONLINE       0     0     0
          sdd       ONLINE       0     0     0
        cache
          sde       ONLINE       0     0     0
    
    errors: No known data errors

посмотрим список файловых систем zfs

    zfs list
    NAME        USED  AVAIL  REFER  MOUNTPOINT
    otuszpool  85.5K  12.5G    24K  /otuszpool

создадим файловую систему otuszpool/opt в пуле

    zfs create otuszpool/opt
    
    zfs list
    NAME            USED  AVAIL  REFER  MOUNTPOINT
    otuszpool       114K  12.5G  25.5K  /otuszpool
    otuszpool/opt    24K  12.5G    24K  /otuszpool/opt


изменим точку монтирования otuszpool/opt на с /otuszpool/opt на /opt

    zfs get mountpoint /otuszpool/opt
    NAME           PROPERTY    VALUE           SOURCE
    otuszpool/opt  mountpoint  /otuszpool/opt  default
    
    zfs set mountpoint=/opt otuszpool/opt
    
    zfs get mountpoint /otuszpool/opt
    /otuszpool/opt: No such file or directory
    
    zfs list
    NAME            USED  AVAIL  REFER  MOUNTPOINT
    otuszpool       124K  12.5G    24K  /otuszpool
    otuszpool/opt    24K  12.5G    24K  /opt

посмотреть параметры файловых систем или пула можно так

    zfs get all otuszpool
    zfs get all otuszpool/opt
    zfs get otuszpool

для файловых систем otuszpool и otuszpool/opt включим сжатие и выключим проверку контрольных сумм

    zfs set compression=gzip otuszpool
    zfs set compression=gzip otuszpool/opt
    zfs set checksum=off otuszpool
    zfs set checksum=off otuszpool/opt

примонтируем файловую систему otuszpool/opt в /opt, если она еще не примонтирована

    zfs mount otuszpool/opt

перезагружаемся и проверяем, что otuszpool/opt монтируется в /opt
    
    reboot
    
    mount | grep opt
    otuszpool/opt on /opt type zfs (rw,seclabel,xattr,noacl)

смотрим, что нет ни одного снапшота
    
    zfs list -t snapshot


создаем 20 файлов в /opt

    touch /opt/file{1..20}

создадим снапшот

    zfs snapshot -r otuszpool/opt@snap1

посмотрим список снапшотов
    
    zfs list -t snapshot
    NAME                  USED  AVAIL  REFER  MOUNTPOINT
    otuszpool/opt@snap1     0B      -    28K  -

удалим часть файлов

    rm -f /opt/file{11..20}
    
    ll /opt/
    total 5
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file1
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file10
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file2
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file3
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file4
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file5
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file6
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file7
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file8
    -rw-r--r--. 1 root root 0 Feb 10 11:11 file9

восстановим снапшот

    zfs rollback otuszpool/opt@snap1

и посмотрим, что файлы восстановились
    
    ls /opt
    file1  file10  file11  file12  file13  file14  file15  file16  file17  file18  file19  file2  file20  file3  file4  file5  file6  file7  file8  file9

удалим снапшот
    
    zfs destroy otuszpool/opt@snap1
    
    zfs list -t snapshot
    no datasets available
