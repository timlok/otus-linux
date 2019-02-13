#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Стоит прописать в crontab такую строчку, чтобы скрипт запускался, например, каждые пять минут
#*/5 *   * * *   root    /scripts/./service_check.sh



#LOG=/scripts/service_check.log
#{



# Set the ROOM_ID & AUTH_TOKEN variables below.
# Further instructions at https://www.hipchat.com/docs/apiv2/aut

# HipChat комната admin_bots
#ROOM_ID=XXXXXXX
#AUTH_TOKEN=your_auth_token



#variables
TMP_FILE=/tmp/service_check_tmp
STOP_FILE=/tmp/service_check_stop
SERVICE='teamviewer'
SERVICE_FULL='teamviewerd.service'
#HUDSON_TMP_FILE=/tmp/hudson_update_tmp
HOST='localhost'
RECIPIENTS='@timur'
RECIP_MAILS=('timur@localhost' 'root@localhost')



#functions
date_func ()
{
        DATE=`date "+%Y-%m-%d_%H-%M-%S"`
}

#hipchat ()
#{
#        curl -H "Content-Type: application/json" \
#        -X POST \
#        -d "{\"color\": \"red\", \"notify\": \"yes\", \"message_format\": \"text\", \"message\": \"$MESSAGE\" }" \
#        https://api.hipchat.com/v2/room/$ROOM_ID/notification?auth_token=$AUTH_TOKEN
#}

service_start ()
{
        systemctl start $SERVICE_FULL
}


mail_message_bad ()
{
        for MAIL in "${RECIP_MAILS[@]}"
        do
            echo -e "$MESSAGE" | mail -s "$SERVICE_FULL не работает" "$MAIL"
        done
}

mail_message_good ()
{
        for MAIL in "${RECIP_MAILS[@]}"
        do
            echo -e "$MESSAGE" | mail -s "$SERVICE_FULL работает" "$MAIL"
        done
}

cleanup ()
{
        RETURN_VALUE=$?
        rm -rf "$TMP_FILE"
        exit $RETURN_VALUE
}

trap 'echo "Удаляю временный файл, работа скрипта была прервана"; cleanup' SIGHUP SIGINT SIGQUIT SIGTERM

# Проверка, что не идёт обновление. Этот файл создает hudson, но это надо настроить в соответствующей таске.
#if [ ! -f $HUDSON_TMP_FILE ]
#then

# Проверка, что не выполняется предыдущий экземпляр скрипта.
if [ ! -f $TMP_FILE ]
then
    echo "Предыдущий экземпляр скрипта не выполняется, продолжаю работу..."

# Проверка, что предыдущий запуск $SERVICE_FULL с помощью этого скрипта не завершился неудачей.
if [ ! -f $STOP_FILE ]
then
    echo "Предыдущий запуск $SERVICE_FULL с помощью этого скрипта завершился удачно"

if ! ps aux | grep -v grep | grep -i $SERVICE > /dev/null
then
        touch $TMP_FILE
        date_func
        MESSAGE="$RECIPIENTS На http://$HOST не работает $SERVICE_FULL! Всё плохо! Жду 30 секунд и запускаю $SERVICE_FULL. $DATE"
        #hipchat
        echo $MESSAGE
        mail_message_bad
        sleep 30

        if ps aux | grep -v grep | grep -i $SERVICE > /dev/null
        then
                date_func
                TMP_PID=`ps aux | grep $SERVICE | grep -v grep | awk '{print $2}'`
                MESSAGE="$RECIPIENTS На http://$HOST обнаружен процесс $SERVICE_FULL с PID=$TMP_PID. НЕ запускаю $SERVICE_FULL и завершаю выполнение скрипта. $DATE"
                #hipchat
                echo $MESSAGE
                mail_message_good
        else
#               date_func
#               MESSAGE="$RECIPIENTS На http://$HOST запускаю $SERVICE. $DATE"
#               #hipchat
                service_start
                sleep 20

                if ! ps ax | grep -v grep | grep -i $SERVICE > /dev/null
                then
                        touch $STOP_FILE
                        date_func
                        MESSAGE="$RECIPIENTS На http://$HOST НЕ запустился $SERVICE_FULL! Всё очень плохо! Требуется внимание человека! Чтобы продолжить работу скрипта, удали файл $STOP_FILE. $DATE"
                        #hipchat
                        echo $MESSAGE
                        mail_message_bad
                else
                        date_func
                        TMP_PID=`ps aux | grep $SERVICE | grep -v grep | awk '{print $2}'`
                        MESSAGE="$RECIPIENTS На http://$HOST $SERVICE_FULL с PID=$TMP_PID стартовал удачно. $DATE"
                        #hipchat
                        echo $MESSAGE
                        mail_message_good
                fi
        fi

        rm -f $TMP_FILE

else
    TMP_PID=`ps aux | grep $SERVICE | grep -v grep | awk '{print $2}'`
    echo "Обнаружен процесс $SERVICE_FULL c PID=$TMP_PID. Расслабься. ;)"
fi

else
    echo "Предыдущий запуск $SERVICE_FULL с помощью этого скрипта завершился НЕудачно. Требуется внимание человека! Чтобы продолжить работу скрипта, удали файл $STOP_FILE."
fi

else
    echo "Присутствует временный файл $TMP_FILE. Предыдущий экземпляр скрипта ещё выполняется?"
fi
#fi

#} 2>&1 | tee -a $LOG > /dev/null
