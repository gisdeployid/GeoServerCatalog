#!/bin/bash
#script for ubuntu 18.04 (bionic)
#maintance by aji19kamaludin@gmail.com
#webuzo with opengeo by boundless

# webuzo
# http://ip:2004
# username : admin
# password : admin

#varible
uname=admin
password='!Q@W#E$R'
email='admin@webgis.my.id'
domain='webgis.my.id'

#update system
export DEBIAN_FRONTEND=noninteractive
apt update && apt dist-upgrade -y

#set hostname
hostnamectl set-hostname webuzo-opengeo-$domain

#install docker
apt --no-act install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install docker-ce docker-ce-cli containerd.io -y

#build opengeo from docker
docker volume create gdp-geoserver_datadir
docker run --name "opengeo-gdp" -dit --restart unless-stopped -v gdp-geoserver_datadir:/var/lib/opengeo/geoserver -p 8080:8080 rikyperdana/ubuntu-opengeo
docker exec opengeo-gdp service postgresql start
docker exec opengeo-gdp service tomcat7 start

#make it automation in reboot : exit rc.local
printf '%s\n' '#!/bin/bash' 'exit 0' | sudo tee -a /etc/rc.local
cd /etc/systemd/system/
wget https://gist.githubusercontent.com/gisdeployid/6018e7c83f2d435544c0b14105e10c3a/raw/f7f0566dc2b81ced2dfcacf82357d1ed78e992f5/rc-local.service
systemctl enable rc-local
chmod +x /etc/rc.local
sed -i -e '$i \docker container start opengeo-gdp &\n' /etc/rc.local
sed -i -e '$i \docker exec opengeo-gdp service postgresql start &\n' /etc/rc.local
sed -i -e '$i \docker exec opengeo-gdp service tomcat7 start &\n' /etc/rc.local
sed -i -e '$i \docker container start portainer &\n' /etc/rc.local
sed -i -e '$i \systemctl start webuzo &\n' /etc/rc.local

#install portainer for console 
docker volume create portainer_data
docker run --name "portainer" -dit --restart unless-stopped -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer

#install webuzo and kill apache1, mysql is here
cd /tmp
wget -N http://files.webuzo.com/install.sh 
chmod 0755 install.sh 
./install.sh

#finishing install web based
curl -d "uname=$uname&email=$email&pass=$password&rpass=$password&domain=$domain&ns1=ns1.$domain&ns2=ns2.$domain&lic=&submit=Install+Webuzo" -X POST http://$(curl ifconfig.me):2004/install.php

#install postgresql, postgis, phppgadmin
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list
wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
apt update
apt install postgresql-11 postgresql-11-postgis-2.5  postgresql-11-postgis-2.5-scripts postgis postgresql-11-pgrouting zip unzip wget -y

su -c "psql -c 'CREATE EXTENSION adminpack;'" postgres
su -c "psql -c 'CREATE EXTENSION postgis;'" postgres
su -c "psql -c \"CREATE USER gisadmin SUPERUSER PASSWORD 'gisadmin';\"" postgres
su -c "psql -c 'ALTER USER gisadmin CREATEDB;'" postgres

sed -i "/\#listen/a listen_addresses='*'" /etc/postgresql/11/main/postgresql.conf
sed -i '$i \host all all 0.0.0.0/0 md5 \n' /etc/postgresql/11/main/pg_hba.conf
systemctl restart postgresql

#ssh2 and ufw
sed -i "/\#Port/a Port=2202 \nProtocol 2" /etc/ssh/sshd_config
ufw enable
for port in 2202 2002 2003 2004 2005 21 22 25 53 80 143 443 465 993 3306 5432 8080 8000 8081
do
ufw allow $port
done

echo "Done" > /root/README.md
reboot