#!/usr/bin/env bash

echo "----------------------------------------"
echo "Start 01_watchlog.sh"
echo "----------------------------------------"

SRC_DIR="/vagrant/01_watchlog_files/"
SRC1="$SRC_DIR"watchlog
SRC2="$SRC_DIR"watchlog.log
SRC3="$SRC_DIR"watchlog.sh
SRC4="$SRC_DIR"watchlog.service
SRC5="$SRC_DIR"watchlog.timer

DEST1=/etc/sysconfig/watchlog
DEST2=/var/log/watchlog.log
DEST3=/opt/watchlog.sh
DEST4=/usr/lib/systemd/system/watchlog.service
DEST5=/usr/lib/systemd/system/watchlog.timer


echo "Copying files
$SRC1 to $DEST1
$SRC2 to $DEST2
$SRC3 to $DEST3
$SRC4 to $DEST4
$SRC5 to $DEST5
"

cp $SRC1 $DEST1
cp $SRC2 $DEST2
cp $SRC3 $DEST3
cp $SRC4 $DEST4
cp $SRC5 $DEST5

echo "Set access rights for $DEST4 $DEST5"
chmod 644 $DEST4 $DEST5

echo "Rebuilding dependency tree"
systemctl daemon-reload

echo "Start watchlog.timer"
systemctl enable --now watchlog.timer


echo "------------------------------------------------------"
echo "01_watchlog.sh finished"
echo "Please start command "tail -n 20 -f /var/log/messages" for view result"
echo "------------------------------------------------------"

