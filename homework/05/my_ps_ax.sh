#!/usr/bin/env bash
#set -x

echo -e "PID\tTTY\tSTAT\tTIME (min)\tCOMMAND"


# получаем содержимое /proc/ и фильтруем на названия каталогов из цифр, результат записываем в массив
array=($(ls -1 -v /proc/ | grep -E "[0-9]+$"))


for i in ${array[@]}
do

# проверям, что каталоги по прежнему существуют
if [ -r "/proc/$i/" ]
then

# получаем PID процесса
VAR_PID=$(cat /proc/$i/status | grep "^Pid:" | awk '{ print $2}')


# получаем TTY
# проверям, что каталог доступен для чтения (нужно в случае запуска скрипта из-под ограниченной учётки)
if [ -r "/proc/$i/fd/" ]
then

# получаем управляющий терминал процесса, проверяем, что это не null, а tty или pts (начинается с p или t) и в зависимости от результата определяем переменную
VAR_TTY=$(ls -l /proc/$i/fd/ | grep lrwx | awk '{print $11}' | uniq | grep "tty\|pts" |sed 's/\/dev\///g')

if [ -n "${VAR_TTY}" ]
then
    if [[ $VAR_TTY = p* ]]
    then
	VAR_TTY=$VAR_TTY
    else
        if [[ $VAR_TTY = t* ]]
        then
            VAR_TTY=$VAR_TTY
        else
            VAR_TTY="?"
        fi
    fi
else
    #echo "VAR_TTY равно NULL!"
    VAR_TTY="?"
fi

else
    VAR_TTY="?"
fi


# STAT
# получаем очень примитивное и упрощенное значение состояния процесса
VAR_STAT=$(cat /proc/$i/status | grep "^State:" | awk '{ print $2}')



# TIME (процессорное время)
# Берем нужное нам значение, доводим его до целого, отбрасываем знаки после запятой (они все стали нулями), сравниваем с преобразованным значением одной минуты, если полученное значение переменой меньше, то приравниваем значение переменной к нулю, если больше, то отбрасываем последние 9 знаков. В результате получаем процессорное время в минутах с округлением до целого в меньшую сторону (как и делает ps).
VAR_TIME=$(grep se.sum_exec_runtime /proc/$i/sched | awk '{ print $3 }')
VAR_TIME=$(echo "$VAR_TIME*1000000" |bc)
VAR_TIME=$(echo $VAR_TIME | awk -F"." '{ print $1 }')
if [ "$VAR_TIME" -le 1000000000 ]
    then
	VAR_TIME="0"
    else
	VAR_TIME=${VAR_TIME::${#VAR_TIME}-9}
fi



# CMDLINE
# если значение пустое, то читаем название процесса из другого файла
VAR_CMDLINE=$(tr -d '\0' < /proc/$i/cmdline)
if [ ! -n "${VAR_CMDLINE}" ]
    then
	VAR_CMDLINE=$(grep "^Name:" /proc/$i/status | awk '{ print $2 }')
	VAR_CMDLINE=[$VAR_CMDLINE]
fi



echo -e "$VAR_PID\t$VAR_TTY\t$VAR_STAT\t$VAR_TIME\t\t$VAR_CMDLINE"

fi

done

