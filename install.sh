#!/bin/bash
# show commands being executed, per debug

set -x
exec > >(sudo tee install.log)
exec 2>&1

INSTALL_SPLUNK=1
INSTALL_JAVA=1
INSTALL_DBX=1
INSTALL_MYSQL=1
PLUNK_PASSWORD="password"
UNINSTALL_MYSQL=1
UNINSTALL_DBX=1

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ "$INSTALL_SPLUNK" == "1" ]]; then
wget -O splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.3&product=splunk&filename=splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb&wget=true'
dpkg -i splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb
cd /opt/splunk/bin
./splunk start --accept-license --answer-yes --no-prompt --seed-passwd ${PLUNK_PASSWORD}
./splunk enable boot-start
./splunk restart
fi

if [[ "$INSTALL_JAVA" == "1" ]]; then
sudo apt-get update -y && sudo apt-get upgrade  -y
sudo add-apt-repository ppa:webupd8team/java  -y
sudo apt-get update -y
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections
sudo apt-get install oracle-java8-installer -y
#sudo update-alternatives --config java
echo 'JAVA_HOME="/usr/lib/jvm/java-8-oracle"' >>/etc/environment
source /etc/environment
export JAVA_HOME="/usr/lib/jvm/java-8-oracle"
fi

if [[ "$UNINSTALL_DBX" == "1" ]]; then
cd /opt/splunk/bin
./splunk remove app  splunk_app_db_connect -auth admin:${PLUNK_PASSWORD}
./splunk restart
rm -rf /opt/splunk/etc/apps/splunk_app_db_connect/drivers/mysql-connector-java-8.0.13.jar
fi


if [[ "$INSTALL_DBX" == "1" ]]; then
cd /opt/splunk/bin
wget https://www.dropbox.com/s/djjn9to4b4r3fy6/splunk-db-connect_314.tgz

./splunk install app splunk-db-connect_314.tgz -auth admin:${PLUNK_PASSWORD}

./splunk restart
cd /opt/splunk/etc/apps/splunk_app_db_connect/drivers/
wget https://www.dropbox.com/s/gpardxaqelw136t/mysql-connector-java-8.0.13.jar

#cat << EOF > /opt/splunk/etc/apps/splunk_app_db_connect/local/identities.conf
#[root]
#disabled = 0
#password = U2FsdGVkX1+0/vH7kO/ah3+gmob9Ij4R2MXHgLB0TmQ=
#use_win_auth = 0
#username = root
#EOF

curl -k -X POST -u admin:password https://localhost:8089/servicesNS/nobody/splunk_app_db_connect/db_connect/dbxproxy/identities -d "{\"name\":\"root\",\"username\":\"root\",\"password\":\"password\"}"

cat << EOF > /opt/splunk/etc/apps/splunk_app_db_connect/local/db_connections.conf
[mysql]
connection_type = mysql
database = world
disabled = 0
host = localhost
identity = root
jdbcUseSSL = false
localTimezoneConversionEnabled = false
port = 3306
readonly = false
timezone = America/Los_Angeles
EOF

cd /opt/splunk/bin
./splunk restart

fi

if [[ "$UNINSTALL_MYSQL" == "1" ]]; then
sudo systemctl stop mysql.service
sudo apt-get remove --purge mysql-server mysql-client mysql-common -y
sudo apt-get autoremove -y
sudo apt-get autoclean
sudo rm -rf /etc/mysql
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/lib/mysql-keyring
sudo rm -rf /var/lib/mysql-files
fi

if [[ "$INSTALL_MYSQL" == "1" ]]; then
# define database connectivity
_db="world"
_db_user="root"
_db_password="password"
_db_sample_file="world.sql"
cd ${DIR}
wget https://www.dropbox.com/s/j39s3baatjgf6c8/world.sql
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server || exit 1
sudo mysqladmin -u root password ${_db_password} || exit 1

sudo mysql -u${_db_user} -p${_db_password}  -e "ALTER USER '${_db_user}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${_db_password}';"
sudo systemctl restart mysql.service
sudo mysql -u${_db_user} -p${_db_password}  < ${_db_sample_file}
sudo systemctl restart mysql.service

fi

echo "completed"
exit
