FROM centos:7
COPY screenrc /root/.screenrc
COPY cluster_reconfigure.sh /opt/cluster_reconfigure.sh

RUN rpm --import https://www.percona.com/downloads/RPM-GPG-KEY-percona; \
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
percona-release setup ps80; \
yum -y install bash net-tools nmap screen percona-mysql-router percona-server-client percona-mysql-shell; \
yum clean all; \
rm -rf /etc/mysqlrouter/*; \
chmod +x /opt/cluster_reconfigure.sh

CMD ["/usr/bin/bash"]
