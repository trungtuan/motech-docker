#!/bin/bash
set -e

chown -R mysql:mysql /var/lib/mysql
mysql_install_db --user mysql > /dev/null

MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-""}
MYSQL_DATABASE=${MYSQL_DATABASE:-""}
MYSQL_USER=${MYSQL_USER:-""}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}
MYSQLD_ARGS=${MYSQLD_ARGS:-""}

tfile=`mktemp`
if [[ ! -f "$tfile" ]]; then
    return 1
fi

cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
UPDATE user SET password=PASSWORD("$MYSQL_ROOT_PASSWORD") WHERE user='root';
EOF

if [[ $MYSQL_DATABASE != "" ]]; then
    echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile

    if [[ $MYSQL_USER != "" ]]; then
        echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $tfile
    fi
fi

echo "***************** First"
/usr/sbin/mysqld --bootstrap --verbose=0 $MYSQLD_ARGS < $tfile
#rm -f $tfile

echo "***************** Start"
/usr/sbin/mysqld $MYSQLD_ARGS &
sleep 5s

echo "***************** Second"
/usr/bin/mysql -u root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < /tmp/create_db_schema_quartz_v2.1.sql
echo "CREATE DATABASE IF NOT EXISTS motech_data_services CHARACTER SET utf8 COLLATE utf8_general_ci;" | /usr/bin/mysql -u root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE

echo "***************** Stop"
/usr/bin/mysqladmin -u root --password=$MYSQL_ROOT_PASSWORD shutdown

echo "***************** Third"
exec /usr/sbin/mysqld $MYSQLD_ARGS