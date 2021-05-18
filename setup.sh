#!/bin/bash

echo "Updating and Upgrading"
apt-get -qq -y update


export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< 'mysql-server-10.0 mysql-server/root_password password #MYSQL_ROOT_PASSWORD'
debconf-set-selections <<< 'mysql-server-10.0 mysql-server/root_password_again password #MYSQL_ROOT_PASSWORD'
echo "Installing MariaDB, Docker, and ldapscripts"
apt-get install -y -q mysql-server docker.io ldapscripts jq

sed -i 's/bind-address/# bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf
service mysql restart

echo 'Setting up Test LDAP'
docker pull rroemhild/test-openldap
docker run --restart always --name=ldap -p 10389:10389 -p 10636:10636 -d rroemhild/test-openldap

sed -i 's/MATTERMOST_PASSWORD/#MATTERMOST_PASSWORD/' /vagrant/db_setup.sql
echo "Setting up database"
mysql -uroot -p#MYSQL_ROOT_PASSWORD < /vagrant/db_setup.sql

rm -rf /opt/mattermost

if [ "$1" != "" ]; then
    mattermost_version="$1"
else
	echo "Mattermost version is required"
    exit 1
fi

echo /vagrant/mattermost-$mattermost_version-linux-amd64.tar.gz

if [[ ! -f /vagrant/mattermost-$mattermost_version-linux-amd64.tar.gz ]]; then
	echo "Downloading Mattermost"
	wget -P /vagrant/ https://releases.mattermost.com/$mattermost_version/mattermost-$mattermost_version-linux-amd64.tar.gz
fi

cp /vagrant/mattermost-$mattermost_version-linux-amd64.tar.gz ./

tar -xzf mattermost*.gz

rm mattermost*.gz
mv mattermost /opt

mkdir /opt/mattermost/data
mv /opt/mattermost/config/config.json /opt/mattermost/config/config.orig.json
jq -s '.[0] * .[1]' /opt/mattermost/config/config.orig.json /vagrant/config.json > /opt/mattermost/config/config.json

cp /vagrant/e20license.txt /opt/mattermost/license.txt

useradd --system --user-group mattermost
chown -R mattermost:mattermost /opt/mattermost
chmod -R g+w /opt/mattermost

cp /vagrant/mattermost.service /lib/systemd/system/mattermost.service
systemctl daemon-reload

cd /opt/mattermost

bin/mattermost user create --email admin@planetexpress.com --username admin --password admin --system_admin
bin/mattermost team create --name stussy --display_name "Stussy" --email "admin@planetexpress.com"
bin/mattermost team create --name undefeated --display_name "Undefeated" --email "admin@planetexpress.com"
bin/mattermost team create --name supreme --display_name "Supreme" --email "admin@planetexpress.com"

bin/mattermost team add stussy admin@planetexpress.com
bin/mattermost team add undefeated admin@planetexpress.com
bin/mattermost team add supreme admin@planetexpress.com

bin/mattermost team modify stussy --public
bin/mattermost team modify undefeated --public
bin/mattermost team modify supreme --public

service mysql start
service mattermost start

# IP_ADDR=`/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`

printf '=%.0s' {1..80}
echo 
echo '                     VAGRANT UP!'
echo "GO TO http://127.0.0.1:8065 and log in with \`professor\`"
echo
printf '=%.0s' {1..80}
