#!/usr/bin/env bash

echo "--------------------------------------------------------"
echo "start 03_httpd_twice.sh"
echo "--------------------------------------------------------"

echo "------add template in httpd.service------"
cp /usr/lib/systemd/system/httpd.service /usr/lib/systemd/system/httpd@.service
sed -i 's/sysconfig\/httpd/sysconfig\/httpd-%I/g' /usr/lib/systemd/system/httpd@.service

echo "------create and edit two files with environments------"
cp /etc/sysconfig/httpd /etc/sysconfig/httpd-first && cp /etc/sysconfig/httpd /etc/sysconfig/httpd-second
sed -i 's/#OPTIONS=/OPTIONS=-f conf\/httpd-first.conf/g' /etc/sysconfig/httpd-first && sed -i 's/#OPTIONS=/OPTIONS=-f conf\/httpd-second.conf/g' /etc/sysconfig/httpd-second

echo "------create and edit two conf-files httpd------"
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd-first.conf && cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd-second.conf
sed -i 's/Listen 80/Listen 8080/g' /etc/httpd/conf/httpd-second.conf && echo "PidFile /var/run/httpd-second.pid" >> /etc/httpd/conf/httpd-second.conf

echo "------rebuilding dependency tree services and start new services------"
systemctl daemon-reload
systemctl enable --now httpd@first
systemctl enable --now httpd@second

#echo "------check that both web servers are running------"
#ss -lptun | grep 80

echo "------------------------------------------------------"
echo "03_httpd_twice.sh finished"
echo "------------------------------------------------------"
