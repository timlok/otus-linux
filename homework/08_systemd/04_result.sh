#!/usr/bin/env bash

echo ""
echo "--------------------------------------------------------"
echo "start 04_result.sh"
echo "--------------------------------------------------------"
echo ""
echo "------PLEASE WAIT------"

TIMEOUT=35
while [ $TIMEOUT -ge 0 ];do
    tput sc
    printf '%3s' $TIMEOUT
    tput rc
    sleep 1
    let "TIMEOUT=TIMEOUT-1"
done

echo ""
echo ""
echo "------watchlog is working!------"
grep "I found word, Master\!" /var/log/messages | tail -n 5

echo ""
echo "------spawn-fcgi.service is running------"
systemctl status spawn-fcgi

echo ""
echo "------both web servers are running------"
ss -lptun | grep 80

echo ""
echo "--------------------------------------------------------"
echo "04_result.sh finised"
echo "--------------------------------------------------------"
echo ""
