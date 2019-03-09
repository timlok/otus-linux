#!/usr/bin/env bash

echo "--------------------------------------------------------"
echo "Start 02_init_to_unit.sh"
echo "--------------------------------------------------------"

echo "------install packages------"
yum install -y epel-release
yum install spawn-fcgi php php-cli mod_fcgid httpd -y

echo "------uncomment variables in /etc/sysconfig/spawn-fcgi------"
sed -i 's/#SOCKET/SOCKET/g' /etc/sysconfig/spawn-fcgi && sed -i 's/#OPTIONS/OPTIONS/g' /etc/sysconfig/spawn-fcgi

echo "------create unit service-file------"
echo "[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/spawn-fcgi.service

echo "------start systemd spawn-fcgi.service------"
systemctl enable --now spawn-fcgi
#sleep 3 && systemctl status spawn-fcgi

echo "------------------------------------------------------"
echo "02_init_to_unit.sh finished"
echo "------------------------------------------------------"
