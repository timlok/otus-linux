#!/usr/bin/env bash

UID_ROOT=0
LOG=cpu_nice.log
HOME=/home/timur

if [ "$UID" -ne "$UID_ROOT" ]
then
    echo "Для запуска с отрицательным значением уступчивости (nice) требуются права root"
  exit 1
fi

log() {
  echo "$1" >> "$LOG"
}

nice_high() {
    log "nice-19 started `date`"
    nice -n -19 tar --use-compress-program=pbzip2 -cpf nice-19.tar.bz2 $HOME
    log "nice-19 finished `date`"
}

nice_low() {
    log "nice+19 started `date`"
    nice -n +19 tar --use-compress-program=pbzip2 -cpf nice+19.tar.bz2 $HOME
    log "nice+19 finished `date`"
}

nice_high &
nice_low &

