# Перенос работающей ОС на программный raid1

отключаем selinux в файле /etc/sysconfig/selinux (через sed почему-то не работает) или просто временно отключаем

    setenforce Permissive

устанавливаем необходимые пакеты

    yum install -y mdadm rsync

подготавливаем разделы для mdraid - затираем суперблоки, создаем таблицу разделов, сами разделы и выставляем нужные флаги
    
    mdadm --zero-superblock --force /dev/sd{b,c}
    for SDX in sd{b,c}; do dd if=/dev/zero of=/dev/$SDX count=1 bs=512; done
    for SDX in sd{b,c}; do parted -s -a optimal /dev/$SDX; done
    for SDX in sd{b,c}; do parted -s /dev/$SDX mktable msdos; done
    for SDX in sd{b,c}; do parted -s /dev/$SDX mkpart primary 0% 100%; done
    for SDX in sd{b,c}; do parted -s /dev/$SDX set 1 "raid" on; done
    for SDX in sd{b,c}; do parted -s /dev/$SDX set 1 boot on; done

создаем рейд и файловую систему на нем

    mdadm --create --verbose --assume-clean --metadata=0.90 /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1
    mkfs.ext4 /dev/md0

монтируем рейд, копируем на него содержимое корневой файловой системы и чрутимся

    mount -v /dev/md0 /mnt/
    rsync -av -A --exclude="- dev/" --exclude="- sys/" --exclude="- proc/" --exclude="- run/" --exclude="- mnt/" / /mnt/
    RAID=/mnt; mkdir $RAID/sys $RAID/proc $RAID/dev $RAID/run $RAID/mnt
    mount --bind /proc /mnt/proc && mount --bind /dev /mnt/dev && mount --bind /sys /mnt/sys && mount --bind /run /mnt/run && chroot /mnt/


в chroot подставляем UUID коневого раздела на mdraid (swap-файла нет в данной установке ОС)

    TMP_UUID=$(ls -l /dev/disk/by-uuid/ | grep md0 | awk '{print $9}'); echo "UUID=$TMP_UUID / ext4 defaults 0 0" > /etc/fstab

создаем файл mdadm.conf

    echo "DEVICE partitions" > /etc/mdadm.conf
    mdadm --detail --scan >> /etc/mdadm.conf

пересобираем ораз начальной загрузки и добавляем в него модуль для mdraid

    dracut --mdadmconf --add="mdraid" --force -v

добавляем в загрузчик опцию rd.auto=1 для того, чтобы включить в ядре автообнаржение рейдов и добавляем модуль для mdraid

    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="rd.auto=1 /g' /etc/default/grub
    echo "GRUB_PRELOAD_MODULES="mdraid1x"" >> /etc/default/grub

устанавливаем загрузчик

    grub2-mkconfig -o /boot/grub2/grub.cfg && grub2-install --force --recheck --no-floppy /dev/sdb
    grub2-mkconfig -o /boot/grub2/grub.cfg && grub2-install --force --recheck --no-floppy /dev/sdc

в корне создаем этот файл и вынуждаем после перезагрузки selinux расставить метки на все нужные файлы

    touch /.autorelabel

выходим из chroot-окружения
    
    exit

после выхода из chroot отмонтируем ранее примонтированное
    
    umount /mnt/*

перезагружаемся, в BIOS выставляем загружку с любого из накопителей входяшего в raid1 и радуемся
    
    reboot
