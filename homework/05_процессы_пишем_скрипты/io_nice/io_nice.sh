#!/usr/bin/env bash

UID_ROOT=0
HDD=sda
LOG=ionice.log
OUTPUT=/home/hdd/timur/Downloads/_tmp

if [ "$UID" -ne "$UID_ROOT" ]
then
    echo "Для запуска скрипта требуются права root"
  exit 1
fi

log() {
  echo "$1" >> "$LOG"
}

ionice_high() {
    log "ionice1 started `date`"
    dd if=/dev/$HDD of=$OUTPUT/ionice1 bs=100M count=100 oflag=direct
    log "ionice1 finished `date`"
}

ionice_low() {
    log "ionice3 started `date`"
    dd if=/dev/$HDD of=$OUTPUT/ionice3 bs=100M count=100 oflag=direct
    log "ionice3 finished `date`"
}

echo "проверяем планировщик для выбраного диска"
cat /sys/block/$HDD/queue/scheduler

echo "чистим дисковые кеши"
sync && echo 3 > /proc/sys/vm/drop_caches

echo "запускаем оба процесса чтения-записи"
ionice_high &
ionice_low &

echo "ищем их PID и меняем им классы ввода-вывода"
# такая штука отлично работает с планировщиком bfq ;)
PID1=$(ps aux | grep ionice1 | grep -v grep | awk '{ print $2 }')
ionice --class 1 -p $PID1
echo "Для PID=$PID1 установлен класс ввода-вывода "real time""

PID3=$(ps aux | grep ionice3 | grep -v grep | awk '{ print $2 }')
ionice --class 3 -p $PID3
echo "Для PID=$PID3 установлен класс ввода-вывода "idle""

