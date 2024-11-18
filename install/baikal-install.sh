#!/usr/bin/env bash

# Copyright (c) 2021-2024 community-scripts ORG
# Author: community-scripts ORG
# CO-Author: snow2k9
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Installing Dependencies, these 3 dependencies are our core dependencies and should always be present! 
# All others are supplemented with \ 
msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y \
  apache2 \
  mariadb-server \
  libapache-mod-php \
  php-{fpm,xml,curl,mysql} \
  composer \
msg_ok "Installed Dependencies"

# Setting up Mysql-DB (MariaDB):
msg_info "Setting up MariaDB"
DB_NAME=baikal
DB_USER=baikal
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
PROJECT_SECRET="$(openssl rand -base64 32 | cut -c1-24)" # if needed
$STD sudo mysql -u root -e "CREATE DATABASE $DB_NAME;"
$STD sudo mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password AS PASSWORD('$DB_PASS');"
$STD sudo mysql -u root -e "GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
{
    echo "Baikal-Credentials"
    echo "Baikal Database User: $DB_USER"
    echo "Baikal Database Password: $DB_PASS"
    echo "Baikal Database Name: $DB_NAME"
    echo "Baikal Secret: $PROJECT_SECRET"
} >> ~/baikal.creds
msg_ok "Set up MariaDB"
# _______________________________________________________________________________________________________________________________________________

msg_info "Baikal Setup  (Patience)"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/sabre-io/baikal/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/sabre-io/baikal/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv baikal-${RELEASE} /opt/baikal
#cd /opt/baikal
$STD sudo chown -R www-data:www-data /opt/baikal

# if you need to change an .env, please use sed -i, for example:
#cp .env.example .env
#sudo sed -i \
#    -e "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" \
#    -e "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" \
#    -e "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" \
#    /opt/projectname/.env
	
# Rest of build code
# Rest of build code
# Rest of build code

echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Installed Baikal"

msg_info "Creating Service"
cat <<EOF > /etc/apache2/sites-available/baikal.conf
<VirtualHost *:80>
    DocumentRoot /opt/baikal
    ServerName _

    RewriteEngine on
    # Generally already set by global Apache configuration
    # RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
    RewriteRule /.well-known/carddav /dav.php [R=308,L]
    RewriteRule /.well-known/caldav  /dav.php [R=308,L]

    <Directory "/opt/baikal/html">
        Options None
        # If you install cloning git repository, you may need the following
        # Options +FollowSymlinks
        AllowOverride None
        # Configuration for apache-2.4:
        Require all granted
        # Configuration for apache-2.2:
        # Order allow,deny
        # Allow from all
    </Directory>

    <IfModule mod_expires.c>
        ExpiresActive Off
    </IfModule>
</VirtualHost>
EOF
$STD a2ensite baikal.conf
$STD a2dissite 000-default.conf
$STD systemctl reload apache2
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /opt/v${RELEASE}.zip
$STD apt -y autoremove
$STD apt -y autoclean
msg_ok "Cleaned"
