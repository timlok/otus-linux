FROM local/c7-systemd
COPY my.cnf /root/.my.cnf

RUN rpm --import https://www.percona.com/downloads/RPM-GPG-KEY-percona; \
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
percona-release setup ps80; \
yum -y install bash percona-server-server percona-mysql-shell; \
yum clean all; \
chmod 600 /root/.my.cnf;\
chown root. /root/.my.cnf;\
systemctl enable mysqld;

CMD ["/usr/sbin/init"]

