#!/usr/bin/env bash
yum install -y epel-release
yes | rpm -ivh http://ftp.tu-chemnitz.de/pub/linux/dag/redhat/el7/en/x86_64/rpmforge/RPMS/rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm
yum update
yum install -y vim redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils htop mc screen sudo iotop net-tools elinks traceroute bind-utils deltarpm lsof vim vim-enhanced
echo "------------------------------------------------------"
echo "00_updateOS.sh finished"
echo "------------------------------------------------------"
