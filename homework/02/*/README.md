# Создание программного рейда mdadm raid6

зануляем суперблоки

mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}

создаем рейд

mdadm --create --verbose /dev/md0 --level=6 --raid-devices=5 /dev/sd{b,c,d,e,f}

создаем mdadm.conf

mkdir /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
ln -s /etc/mdadm/mdadm.conf /etc/

на raid6 создаем таблицу разделов GPT (в методичке написано "раздел", что неправильно) и пять разделов

parted -s /dev/md0 mklabel gpt
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%

создаем файловые системы и монтируем по каталогам

for i in $(seq 1 5); do mkfs.ext4 /dev/md0p$i; done
mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5); do mount -v /dev/md0p$i /raid/part$i; done

при включенном SELinux необходимо выполнить восстановление контекста безопасности для новых разделов с файловыми системами, чтобы эти разделы могли успешно монтироваться при загрузке ОС
restorecon -Rv /

получаем UUIDы новых разделов и прописываем их в fstab
for i in $(seq 1 5); do TMP_UUID=$(ll /dev/disk/by-uuid/ | grep md0p$i | awk  '{print $9}'); echo "UUID=$TMP_UUID /raid/part$i ext4 defaults 0 0" >> /etc/fstab; done


