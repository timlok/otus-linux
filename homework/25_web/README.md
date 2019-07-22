# Заметки к ДЗ-25

В каталоге [docker](https://github.com/timlok/otus-linux/tree/master/homework/25_web/docker) располагаются совершенно необязательные файлы из которых собран образ.

Стенд для ДЗ взят из репозитория [https://gitlab.com/otus_linux/nginx-antiddos-example](https://gitlab.com/otus_linux/nginx-antiddos-example). Там же и описание ДЗ, в котором указано: "после чего клиент будет обратно отправлен (редирект) на **запрашиваемый** ресурс".
И там же в инструкциях указан конкретный файл [http://localhost/otus.txt](http://localhost/otus.txt), что не совсем корректно, т.к. "запрашиваемый ресурс" может быть любым другим (пусть даже сервер его и не сможет отдать).
Реализация отдачи заранее определённого статичного файла была несложной, хоть и конфиг получался немного больше. Обращу внимание, что в конфигах nginx нельзя использовать кастомные переменные. Таким образом, первоначально запрошенный URI невозможно сохранить в свою переменную, а ```$request_uri``` перезаписывается после перехода по первому же редиректу. В связи с этим, пришлось записать первоначальный ```$request_uri``` в cookie и потом его использовать для возврата на запрашиваемый URI. Т.е. после выдачи cookie nginx вернёт не только [http://localhost/otus.txt](http://localhost/otus.txt), но и корректный ответ на любой другой запрошенный URI (даже если его нет). Не знаю, насколько это правильно, но такой способ работает. :-)

Для того, чтобы проверить ДЗ необходимо запустить образ из моего репозитория на [https://hub.docker.com/](https://hub.docker.com/)

```bash
docker run -p 80:80 timlok/otus:latest
```

и выполнить две команды

```bash
curl http://localhost/otus.txt -i -L
```

```bash
curl http://localhost/otus.txt -i -L -b cookie -c cookie
```

Или открыть в браузере адрес [http://localhost/otus.txt](http://localhost/otus.txt).

## Работа с docker

Собираем образ

```bash
docker build -t otus-nginx-ddos-protection .
```

Запускаем контейнер

```bash
docker run --rm -d -p 80:80 otus-nginx-ddos-protection
```

Проверяем, что docker слушает на 80м порту

```bash
[root@web ~]# netstat -lptun | grep 80
tcp6       0      0 :::80                   :::*                    LISTEN      7131/docker-proxy-c
```

Логинимся на [https://hub.docker.com/](https://hub.docker.com/)

```bash
docker login
```

Задаём тэг latest полученному образу

```bash
docker tag otus-nginx-ddos-protection:latest timlok/otus:latest
```

Пушим образ на [https://hub.docker.com/](https://hub.docker.com/)

```bash
docker push timlok/otus:latest
```

## Результат самопроверки выполнения ДЗ

Проверяем, что образ выкачивается и запускается так, как указано в требованиях к ДЗ

```docker run -p 80:80 your_account/your_repo:latest```

```bash
[root@web ~]# docker run -p 80:80 timlok/otus:latest
Unable to find image 'timlok/otus:latest' locally
Trying to pull repository docker.io/timlok/otus ...
latest: Pulling from docker.io/timlok/otus
e7c96db7181b: Pull complete
3fb6217217ef: Pull complete
fb2a6166c0f2: Pull complete
2cf8a381ed2d: Pull complete
Digest: sha256:fbac16b291c6df0d5c63495ddb1943f34a408a27bfefb8e311ad046b653dd899
Status: Downloaded newer image for docker.io/timlok/otus:latest
172.17.0.1 - - [22/Jul/2019:14:51:01 +0000] "GET /otus.txt HTTP/1.1" 302 145 "-" "curl/7.29.0" "-"
172.17.0.1 - - [22/Jul/2019:14:51:01 +0000] "GET /addcookie HTTP/1.1" 302 145 "-" "curl/7.29.0" "-"
172.17.0.1 - - [22/Jul/2019:14:51:41 +0000] "GET /otus.txt HTTP/1.1" 302 145 "-" "curl/7.29.0" "-"
172.17.0.1 - - [22/Jul/2019:14:51:41 +0000] "GET /addcookie HTTP/1.1" 302 145 "-" "curl/7.29.0" "-"
172.17.0.1 - - [22/Jul/2019:14:51:41 +0000] "GET /otus.txt HTTP/1.1" 200 12 "-" "curl/7.29.0" "-"
```

Проверяем без cookie
```bash
[root@web ~]# curl http://localhost/otus.txt -i -L
HTTP/1.1 302 Moved Temporarily
Server: nginx/1.17.1
Date: Mon, 22 Jul 2019 14:51:01 GMT
Content-Type: text/html
Content-Length: 145
Connection: keep-alive
Location: http://localhost/addcookie
Set-Cookie: first_uri=/otus.txt

HTTP/1.1 302 Moved Temporarily
Server: nginx/1.17.1
Date: Mon, 22 Jul 2019 14:51:01 GMT
Content-Type: text/html
Content-Length: 145
Connection: keep-alive
Location:
Set-Cookie: access=secretkey

<html>
<head><title>302 Found</title></head>
<body>
<center><h1>302 Found</h1></center>
<hr><center>nginx/1.17.1</center>
</body>
</html>
```

Проверяем с cookie

```bash
[root@web ~]# curl http://localhost/otus.txt -i -L -b cookie -c cookie
HTTP/1.1 302 Moved Temporarily
Server: nginx/1.17.1
Date: Mon, 22 Jul 2019 14:51:41 GMT
Content-Type: text/html
Content-Length: 145
Connection: keep-alive
Location: http://localhost/addcookie
Set-Cookie: first_uri=/otus.txt

HTTP/1.1 302 Moved Temporarily
Server: nginx/1.17.1
Date: Mon, 22 Jul 2019 14:51:41 GMT
Content-Type: text/html
Content-Length: 145
Location: http://localhost/otus.txt
Connection: keep-alive
Set-Cookie: access=secretkey

HTTP/1.1 200 OK
Server: nginx/1.17.1
Date: Mon, 22 Jul 2019 14:51:41 GMT
Content-Type: text/plain
Content-Length: 12
Last-Modified: Mon, 22 Jul 2019 14:03:51 GMT
Connection: keep-alive
ETag: "5d35c247-c"
Accept-Ranges: bytes

timlok/otus
```
