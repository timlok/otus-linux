#!/usr/bin/env bash
set -x
PGDATA=/var/lib/pgsql/11/data/
PG_WAL="$PGDATA"pg_wal/
PG_RECOVERY=/var/lib/pgsql/11/data/recovery.conf

# дописываем новые wal-файлы с pgsqlMaster на pgsqlSlave
rsync --partial --append-verify --progress -avz -e ssh $PG_WAL postgres@pgsqlSlave:"$PG_WAL"


##### РЕПЛИКАЦИЯ - не нужно для простого резервного копирования или создания копии сервера
#
#
# на pgsqlSlave создаём файл recovery.conf для работы в режиме репликации
ssh postgres@pgsqlSlave -t "echo "standby_mode = "\'"on"\'"" > "$PG_RECOVERY""
ssh postgres@pgsqlSlave -t "echo "primary_conninfo = "\'"host=192.168.11.150 port=5432 user=repluser"\'"" >> "$PG_RECOVERY""

# если нужна реплика в режиме hot_standby (разрешен доступ на чтение), то:
ssh postgres@pgsqlSlave -t "sed -i 's/^#hot_standby =/hot_standby =/g' "$PGDATA"/postgresql.auto.conf"

# если нужна репликация со слотами, то:
ssh postgres@pgsqlSlave -t "echo "primary_slot_name = "\'"standby_slot"\'"" >> "$PG_RECOVERY""
#
#
##### конец блока РЕПЛИКАЦИЯ #####


#на pgsqlSlave запускаем postgresql
ssh postgres@pgsqlSlave -t "sudo systemctl start postgresql-11.service"