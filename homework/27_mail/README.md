# ДЗ-27 (Почта: SMTP, IMAP, POP3)

## Задача:

> установка почтового сервера
>
> 1. Установить в виртуалке postfix+dovecot для приёма почты на виртуальный домен любым обсужденным на семинаре способом
> 2. Отправить почту телнетом с хоста на виртуалку
> 3. Принять почту на хост почтовым клиентом
>
> Результат
> 1. Полученное письмо со всеми заголовками
> 2. Конфиги postfix и dovecot
>
> Всё это сложить в git, ссылку прислать в "чат с преподавателем"
>

## Результат:

Все работы проводились на своей vps vdsina.timvirt.ru.
Было отправлено два письма:

1. со своего рабочего ноутбука с помощью telnet на тестовый почтовый аккаунт otus@timvirt.ru
2. со своего рабочего ноутбука через почтовый клиент Mozilla Thunderbird на ящик на mail.ru

[maillog](https://github.com/timlok/otus-linux/tree/master/homework/27_mail/maillog) - лог почты во время отправки всех писем

[mails](https://github.com/timlok/otus-linux/tree/master/homework/27_mail/mails) - каталог с письмами

[script_telnet-mail](https://github.com/timlok/otus-linux/tree/master/homework/27_mail/mails/script_telnet-mail) - отправка письма через telnet (nc) в виде результата работы утилиты script

[configs](https://github.com/timlok/otus-linux/tree/master/homework/27_mail/configs) - каталог с настройками postfix и dovecot



