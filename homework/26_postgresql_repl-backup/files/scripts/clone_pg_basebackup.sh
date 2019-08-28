#!/usr/bin/env bash
set -x
PGDATA=/var/lib/pgsql/11/data/
WAL_ARCH=/var/lib/pgsql/11/wal_bck/
PGDATA_TMP=/tmp/pgsqlSlave
PG_RECOVERY=$PGDATA_TMP/recovery.conf

#на pgsqlSlave останавливаем postgresql, очищаем каталог архива wal-файлов
ssh postgres@pgsqlSlave -t "sudo systemctl stop postgresql-11.service"
ssh postgres@pgsqlSlave -t "rm -rf "$WAL_ARCH"*"

#создаём точку монтирования на pgsqlMaster, монтируем в неё каталог $PGDATA
# с pgsqlSlave и удаляем всё его содержимое
mkdir $PGDATA_TMP
sshfs postgres@pgsqlSlave:$PGDATA $PGDATA_TMP
rm -rf "$PGDATA_TMP"/*


#создаём резервную копию каталога $PGDATA сервера pgsqlMaster в точку указанную ранее монтирования
pg_basebackup --wal-method=stream --format=plain --host localhost --port=5432 -U repluser --no-password --write-recovery-conf --progress --verbose --checkpoint=fast -D $PGDATA_TMP

#редактируем recovery.conf и postgresql.auto.conf для последующей работы pgsqlSlave
#в качестве реплики с работающей hot_standby репликацией с использованием слотов
sed -i 's/^primary_conninfo =/#primary_conninfo =/g' $PG_RECOVERY
echo "primary_conninfo = "\'"host=pgsqlMaster port=5432 user=repluser"\'"" >> $PG_RECOVERY
echo "primary_slot_name = "\'"standby_slot"\'"" >> $PG_RECOVERY
sed -i 's/^#hot_standby =/hot_standby =/g' $PGDATA_TMP/postgresql.auto.conf

#отмонтируем примонтированный удаённый $PGDATA и удаляем точку монтирования
fusermount -u $PGDATA_TMP
rm -rf $PGDATA_TMP

#на pgsqlSlave запускаем postgresql
ssh postgres@pgsqlSlave -t "sudo systemctl start postgresql-11.service"
