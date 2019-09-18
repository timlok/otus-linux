FROM local/c7-systemd
COPY mysqlrouter-cluster.service /etc/systemd/system/mysqlrouter-cluster.service
RUN rpm --import https://www.percona.com/downloads/RPM-GPG-KEY-percona; \
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
percona-release setup ps80; \
yum -y install bash percona-mysql-router percona-mysql-shell; \
yum clean all; \
rm -rf /etc/mysqlrouter/*
#systemctl daemon-reload; \
#systemctl enable mysqlrouter-cluster

CMD ["/usr/sbin/init"]

