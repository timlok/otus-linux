FROM docker.io/alpine
COPY index.php /var/www/index.php
RUN apk update \
&& apk upgrade \
&& apk add --no-cache php7 php7-fpm php7-amqp php7-cgi bash \
&& sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php7/php-fpm.conf \
&& sed -i -e "s/listen\s*=\s*127.0.0.1:9000/listen = 9000/g" /etc/php7/php-fpm.d/www.conf \
&& sed -i "s/^listen.allowed_clients/;listen.allowed_clients/g" /etc/php7/php-fpm.d/www.conf \
&& sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php7/php.ini \
&& chmod 755 /var/www \
&& chown root:root -R /var/www \
&& chmod 644 /var/www/index.php
EXPOSE 9000
CMD ["php-fpm7", "--nodaemonize"]
