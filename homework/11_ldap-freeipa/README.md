Готовый и самодостаточный стэнд в виде [Vagrantfile](Vagrantfile) для проверки ДЗ-11 по LDAP-freeIPA.

Как обычно, нужно скопировать себе содержимое [текущего каталога](https://github.com/timlok/otus-linux/tree/master/homework/11_ldap-freeipa) и просто запустить `vagrant up`. И как обычно, в конце вывода провижининга будет информация с результатами работы.

В этом [Vagrantfile](Vagrantfile) две ВМ - ipaserver и ipaclient и внутренней сетью между ними и одним сетевым адаптером в бридже на ipaserver (мне так было удобнее работать). В результате провижининга ansible выполнит два соответствующих простеньких плэйбука с неинтерактивной установкой и настройкой ipa-server и ipa-client. На ipaserver дополнительно устанавливается X11 и firefox, чтобы по завершению провижининга можно было подключиться с пробросом X в ipaserver, запустить firefox и открыть админку freeIPA.
