#!/usr/bin/env bash
PGDATA=/var/lib/pgsql/11/data/
WAL_ARCH=/var/lib/pgsql/11/wal_bck/
PGDATA_TMP=/tmp/pgsqlMaster/data/
PG_RECOVERY="$PGDATA"recovery.conf

#форсируем проверку архивации WAL-логов и ждём 5 секунд
su -l barman -c "barman switch-xlog --force --archive pgsqlMaster"
sleep 5

#форсируем запуск потоковой передачи WAL-логов и ждём 30 секунд, чтобы WAL-файлы окончательно синхронизировались
echo "форсируем запуск потоковой передачи WAL-логов и ждём 30 секунд"
su -l barman -c "barman receive-wal pgsqlMaster"
sleep 30

#создаём актуальную резервную копию pgsqlMaster
su -l barman -c "barman backup pgsqlMaster"

#ждём минуту, чтобы WAL-файлы окончательно синхронизировались
echo "ждём 60 секунд, чтобы WAL-файлы окончательно синхронизировались"
sleep 60

#получаем backup_id последней резервной копии
BACKUP_ID=$(barman list-backup --minimal pgsqlMaster | grep -v FAILED | sort -r | head -1)

#получаем backup_id и восстанавливаем полученный бэкап БД во временный каталог
su -l barman -c "barman recover pgsqlMaster $BACKUP_ID $PGDATA_TMP"

#останавливаем postgresql, очищаем каталог архива wal-файлов
systemctl stop postgresql-11.service
rm -rf "$WAL_ARCH"*
rm -rf "$PGDATA"

mv $PGDATA_TMP $PGDATA


#редактируем recovery.conf и postgresql.auto.conf для последующей работы pgsqlSlave
#в качестве реплики с работающей hot_standby репликацией с использованием слотов
touch $PG_RECOVERY
echo "primary_conninfo = "\'"host=pgsqlMaster port=5432 user=repluser"\'"" >> $PG_RECOVERY
echo "primary_slot_name = "\'"standby_slot"\'"" >> $PG_RECOVERY
echo "standby_mode = "\'"on"\'"" >> $PG_RECOVERY

#sed -i 's/^archive_command =/#archive_command =/g' "$PGDATA"postgresql.auto.conf
#echo "archive_command = false" >> "$PGDATA"postgresql.auto.conf
sed -i 's/^#hot_standby =/hot_standby =/g' "$PGDATA"postgresql.auto.conf


chown -R postgres. $PGDATA

#запускаем postgresql
systemctl start postgresql-11.service
