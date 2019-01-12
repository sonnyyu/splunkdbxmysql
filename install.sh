#!/bin/bash
# show commands being executed, per debug

set -x
exec > >(sudo tee install.log)
exec 2>&1

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ "$INSTALL_SPLUNK" == "1" ]]; then
wget -O splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.3&product=splunk&filename=splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb&wget=true'
dpkg -i splunk-7.2.3-06d57c595b80-linux-2.6-amd64.deb
cd /opt/splunk/bin
./splunk start --accept-license
./splunk enable boot-start
./splunk restart
fi

if [[ "$INSTALL_SPLUNK" == "1" ]]; then
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

cd /opt/splunk/bin
wget https://www.dropbox.com/s/djjn9to4b4r3fy6/splunk-db-connect_314.tgz
./splunk install app splunk-db-connect_314.tgz
./splunk restart

cd /opt/splunk/etc/apps/splunk_app_db_connect/drivers/
wget https://www.dropbox.com/s/gpardxaqelw136t/mysql-connector-java-8.0.13.jar

# define database connectivity
_db="world"
_db_user="root"
_db_password="password"
_db_sample_file="world.sql"

cd ${DIR}

wget https://www.dropbox.com/s/j39s3baatjgf6c8/world.sql

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server || exit 1
sudo mysqladmin -u root password ${_db_password} || exit 1
sudo mysql -u${_db_user} -p  -e "ALTER USER '${_db_user}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${_db_password}';"
sudo systemctl restart mysql.service

sudo mysql -u${_db_user} -p${_db_password}  < ${_db_sample_file}
sudo systemctl restart mysql.service

echo "completed"
exit
