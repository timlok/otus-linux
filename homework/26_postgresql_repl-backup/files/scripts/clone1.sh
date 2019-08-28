#!/usr/bin/env bash
set -x
PGDATA=/var/lib/pgsql/11/data/
WAL_ARCH=/var/lib/pgsql/11/wal_bck/

#на pgsqlSlave останавливаем postgresql и очищаем каталог postgresql
ssh postgres@pgsqlSlave -t "sudo systemctl stop postgresql-11.service"
ssh postgres@pgsqlSlave -t "rm -rf "$PGDATA"*"
ssh postgres@pgsqlSlave -t "rm -rf "$WAL_ARCH"*"

#на pgsqlMaster архивируем каталог $PGDATA, копируем и распаковываем его на pgsqlSlave
cd $PGDATA && tar cfO - --exclude=postmaster.pid ./ | lbzip2 -n 2 -5 | ssh postgres@pgsqlSlave "lbunzip2 -c -n 2 | tar xf - -C $PGDATA"
