#!/bin/bash
#script for ubuntu 18.04 (bionic)
#maintance by aji19kamaludin@gmail.com
#geoserver

# phppgadmin
# http://ip/phppgadmin
# username : gisadmin
# password : gisadmin
# webuzo
# http://ip:2004
# username : admin
# password : admin

#varible
uname=admin
password='!Q@W#E$R'
email='user@example.com'
domain='example.com'

#update system
export DEBIAN_FRONTEND=noninteractive
apt update && apt dist-upgrade -y

#set hostname
hostnamectl set-hostname webuzo-geoserver-$domain

#install docker
apt --no-act install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install docker-ce docker-ce-cli containerd.io -y

#build geoserver from docker
docker volume create gdp-geoserver_datadir
docker run --name="geoserver" -dit --restart unless-stopped -p 8080:8080 -v gdp-geoserver_datadir:/mnt/geoserver_datadir -d ajikamaludin/geoserver:v1

#make it automation in reboot : exit rc.local
touch /etc/rc.local
chmod +x /etc/rc.local
sed -i -e '$i \docker container start geoserver &\n' /etc/rc.local
sed -i -e '$i \docker container start portainer &\n' /etc/rc.local
sed -i -e '$i \systemctl start webuzo &\n' /etc/rc.local

#install portainer for console 
docker volume create portainer_data
docker run --name "portainer" -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer

#install webuzo and kill apache1, mysql is here
cd /tmp
wget -N http://files.webuzo.com/install.sh 
chmod 0755 install.sh 
./install.sh

#finishing install web based
curl -d "uname=$uname&email=$email&pass=$password&rpass=$password&domain=$domain&ns1=ns1.$domain&ns2=ns2.$domain&lic=&submit=Install+Webuzo" -X POST http://$(curl ifconfig.me):2004/install.php

kill -9 $(ps aux | grep apache | awk '{print $2}')

mv /usr/local/apps/apache/etc/httpd.conf /usr/local/apps/apache/etc/httpd.conf.bak
#install lamp
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E5267A6C
add-apt-repository "deb http://ppa.launchpad.net/ondrej/php/ubuntu $(lsb_release -cs) main "
apt-get update
apt install apache2 php7.3 php7.3-cli php7.3-common php7.3-curl php7.3-dev php7.3-gd php7.3-imap php7.3-intl php7.3-json php7.3-mbstring php7.3-mysql php7.3-pgsql php7.3-phpdbg php7.3-sqlite3 php7.3-sybase php7.3-xml php7.3-xmlrpc php7.3-xsl php7.3-zip libapache2-mod-php7.3 zip unzip -y
a2enmod rewrite userdir
sed -i '/php_admin_flag engine Off/c\php_admin_flag engine On' /etc/apache2/mods-enabled/php7.3.conf
sed -i '/export APACHE_RUN_USER=www-data/c\export APACHE_RUN_USER='$uname /etc/apache2/envvars
sed -i '/export APACHE_RUN_GROUP=www-data/c\export APACHE_RUN_GROUP='$uname /etc/apache2/envvars
sed -i '/DocumentRoot/c\DocumentRoot /home/'$uname'/public_html\n' /etc/apache2/sites-available/000-default.conf
sed -i -e '16i \<Directory /home/'$uname'/public_html> \nOptions Indexes FollowSymlinks MultiViews \nAllowOverride All \nRequire all granted\n </Directory>\n' /etc/apache2/sites-available/000-default.conf
su -c "echo '<?php phpinfo(); ?>' > /home/$uname/public_html/index.php" $uname

#path php.ini from webuzo to /etc/php/7.3
mv /usr/local/apps/php73/etc/php.ini /usr/local/apps/php73/etc/php.ini.back
ln -s /etc/php/7.3/apache2/php.ini /usr/local/apps/php73/etc/php.ini

systemctl restart apache2

#install postgresql, postgis, phppgadmin
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list
wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
apt update
apt install postgresql-11 postgresql-11-postgis-2.5  postgresql-11-postgis-scripts postgis postgresql-11-pgrouting zip unzip wget -y

su -c "psql -c 'CREATE EXTENSION adminpack;'" postgres
su -c "psql -c 'CREATE EXTENSION postgis;'" postgres
su -c "psql -c \"CREATE USER gisadmin SUPERUSER PASSWORD 'gisadmin';\"" postgres

sed -i "/\#listen/a listen_addresses='*'" /etc/postgresql/11/main/postgresql.conf
sed -i '$i \host all all 0.0.0.0/0 md5 \n' /etc/postgresql/11/main/pg_hba.conf
systemctl restart postgresql

cd /tmp;wget https://github.com/phppgadmin/phppgadmin/archive/REL_5-6-0.zip;
wget https://gist.githubusercontent.com/ajikamaludin/2d1ae989402decad064f4d7d7ce424be/raw/60277bb5064b12e6c42993c4ecf08fd22ff5f969/phppgadmin-config.inc.php;
unzip REL_5-6-0.zip -d /usr/share
mv /usr/share/phppgadmin-REL_5-6-0 /usr/share/phppgadmin
cp /tmp/phppgadmin-config.inc.php /usr/share/phppgadmin/conf/config.inc.php
echo "Alias /phppgadmin /usr/share/phppgadmin" >> /etc/apache2/sites-enabled/000-default.conf
systemctl restart apache2
echo "Done" > /root/README.md
reboot