# Заметки к ДЗ-19

Т.к. за основу взят Vagrantfile с провижинингом с помощью ansible, то для разворачивания (простите за тавтологию) ВМ необходим ansible на хостовой машине. Так же пришлось отключить в NetworkManager возможность обновления файла resolv.conf, хотя можно было задать соответствующие параметры и через nmcli.

SELinux отключён.