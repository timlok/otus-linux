#!/usr/bin/env bash

#set -x

#устанавливаем epel и pam_script
yum install epel-release -y && yum install pam_script -y

#включаем ssh-аутентификацию по паролю
sed -i 's/^PasswordAuthentication no/#PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
#и по RSA-ключам
#sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
systemctl reload sshd.service


#создаем группу admin
groupadd admin && gpasswd -a vagrant admin

#создаем пользователей и добавляем четвертого пользователя в группу admin
for I in {1..4}
    do
PASS=user"$I"pass
#useradd -p $PASS user$I
useradd user$I

chpasswd <<END
user$I:$PASS
END

        if [ "$I" -eq "4" ]
            then
                gpasswd -a user$I admin
                echo "создан пользователь user$I с паролем $PASS, пользователь добавлен в группу admin"
            else
                echo "создан пользователь user$I с паролем $PASS"
        fi
done

#подкладываем файл скрипта
cp /vagrant/files/pam_script_auth /etc/pam-script.d/pam_script_auth
chown root:root /etc/pam-script.d/pam_script_auth && chmod 755 /etc/pam-script.d/pam_script_auth

#добавляем строку с модулем pam_script.so в файлы login и sshd
cp /etc/pam.d/sshd /etc/pam.d/sshd_bck
cp /etc/pam.d/login /etc/pam.d/login_bck
sed '/#%PAM-1.0/a auth required  pam_script.so dir=/etc/pam-script.d/' /etc/pam.d/sshd > /etc/pam.d/sshd_tmp
sed '/#%PAM-1.0/a auth required  pam_script.so dir=/etc/pam-script.d/' /etc/pam.d/login > /etc/pam.d/login_tmp
mv -f /etc/pam.d/sshd_tmp /etc/pam.d/sshd
mv -f /etc/pam.d/login_tmp /etc/pam.d/login
