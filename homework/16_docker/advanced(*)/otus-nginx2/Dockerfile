FROM docker.io/alpine
RUN apk update \
&& apk upgrade \
&& apk add nginx bash
RUN echo "daemon off;" >> /etc/nginx/nginx.conf \
&& mkdir -p /run/nginx && mkdir -p /var/www \
&& chmod 755 /var/www
COPY index.html /var/lib/nginx/html/index.html
COPY index.php /var/www/index.php
COPY default-php-fpm.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx"]

