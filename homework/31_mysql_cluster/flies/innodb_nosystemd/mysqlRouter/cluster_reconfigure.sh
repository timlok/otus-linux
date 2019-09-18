#!/usr/bin/env bash
#set -x

func_mysql01 () {
cat <<MYSQL01 | sh
echo -e "y\ny\n" | /usr/bin/mysqlsh --uri cladmin@mysql01:3306 -p'StrongPassword!#1' -e "var cluster = dba.rebootClusterFromCompleteOutage();"
MYSQL01
FUNC1_EXIT=$?
}

func_mysql02 () {
cat <<MYSQL02 | sh
echo -e "y\ny\n" | /usr/bin/mysqlsh --uri cladmin@mysql02:3306 -p'StrongPassword!#1' -e "var cluster = dba.rebootClusterFromCompleteOutage();"
MYSQL02
FUNC2_EXIT=$?
}

func_mysql03 () {
cat <<MYSQL03 | sh
echo -e "y\ny\n" | /usr/bin/mysqlsh --uri cladmin@mysql03:3306 -p'StrongPassword!#1' -e "var cluster = dba.rebootClusterFromCompleteOutage();"
MYSQL03
FUNC3_EXIT=$?
}

echo -e "\n#########################################################"
echo "##### The cluster reconfiguration script is running #####"
echo -e "#########################################################\n"
echo -e "Waiting 120 seconds before starting work\n"

ping -c 120 -i 1 -q localhost > /dev/null

func_mysql01

if [ $FUNC1_EXIT -ne 0 ]; then

    #echo "mysql01 FUNC1_EXIT = $FUNC1_EXIT"
    echo -e "\n!!! mysql01 is NOT RW !!!\n"
    echo -e "Trying mysql02\n"
    RESULT_CODE=$FUNC1_EXIT

    func_mysql02

    if [ $FUNC2_EXIT -ne 0 ]; then

        #echo "mysql02 FUNC2_EXIT = $FUNC2_EXIT"
        echo -e "\n!!! mysql02 is NOT RW !!!\n"
        echo -e "trying mysql03\n"
        RESULT_CODE=$FUNC2_EXIT

        func_mysql03

        if [ $FUNC3_EXIT -ne 0 ]; then

            #echo "mysql03 FUNC3_EXIT = $FUNC3_EXIT"
            echo -e "\n!!! mysql03 is NOT RW !!!\n"
            RW_SERVER="ABSENT!"
            RESULT_CODE=$FUNC3_EXIT
            echo -e "WARNING! All servers is NOT RW!\n"

        else
            RESULT_CODE=$FUNC3_EXIT
            RW_SERVER=mysql03
            echo -e "Fine! mysql03 is RW\n"
        fi

    else
        RESULT_CODE=$FUNC2_EXIT
        RW_SERVER=mysql02
        echo -e "Fine! mysql02 is RW\n"
    fi

else
    RESULT_CODE=$FUNC1_EXIT
    RW_SERVER=mysql01
    echo -e "Fine! mysql01 is RW\n"
fi

ping -c 5 -i 1 -q localhost > /dev/null

echo "#########################################################"
echo "#####   Cluster reconfiguration script completed    #####"
echo "#####             SCRIPT EXIT CODE = $RESULT_CODE              #####"
echo "#####               RW SERVER $RW_SERVER               #####"
echo -e "#########################################################\n"

#echo -e "SCRIPT RESULT_CODE = $RESULT_CODE"
#exit $RESULT_CODE

exec "$@"
