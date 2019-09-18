FROM centos:7
COPY my.cnf /root/.my.cnf
COPY screenrc /root/.screenrc

RUN rpm --import https://www.percona.com/downloads/RPM-GPG-KEY-percona; \
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
percona-release setup ps80; \
yum -y install bash net-tools nmap screen percona-server-server percona-mysql-shell; \
yum clean all; \
chmod 600 /root/.my.cnf; \
chown root. /root/.my.cnf

CMD ["/usr/sbin/mysqld", "--user=mysql"]
#CMD ["/usr/bin/bash"]
