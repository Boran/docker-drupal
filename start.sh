#!/bin/bash
# /start.sh

# todo: change automatically depending on OS or just work with Ubuntu 14.04 and later?
#defaultsite=/etc/apache2/sites-available/default
#defaultsite=/etc/apache2/sites-available/000-default.conf
#www=/var/www
www=/var/www/html
www=${DRUPAL_DOCROOT}


if [ ! -f $www/sites/default/settings.php ]; then

	# Start mysql
	/usr/bin/mysqld_safe & 
	sleep 5s
	# Generate random passwords 
	DRUPAL_DB="drupal"
	MYSQL_PASSWORD=`pwgen -c -n -1 12`
	DRUPAL_PASSWORD=`pwgen -c -n -1 12`
	# This is so the passwords show up in logs. 
	#echo mysql root password: $MYSQL_PASSWORD
	#echo mysql drupal password: $DRUPAL_PASSWORD
     	echo "mysql root and drupal password, see /mysql-root-pw.txt /drupal-db-pw.txt"
	echo $MYSQL_PASSWORD > /mysql-root-pw.txt
	echo $DRUPAL_PASSWORD > /drupal-db-pw.txt
	mysqladmin -u root password $MYSQL_PASSWORD 
	mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE drupal; GRANT ALL PRIVILEGES ON drupal.* TO 'drupal'@'localhost' IDENTIFIED BY '$DRUPAL_PASSWORD'; FLUSH PRIVILEGES;"

	# Apache
	a2enmod rewrite vhost_alias headers
	#12.04 sed -i 's/AllowOverride None/AllowOverride All/' $defaultsite

        # Drupal
	echo "Installing Drupal with profile ${DRUPAL_INSTALL_PROFILE} site-name=${DRUPAL_SITE_NAME} "
	cd $www
	#drush site-install standard -y --account-name=admin --account-pass=admin --db-url="mysqli://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal"
	drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass="${DRUPAL_ADMIN_PW}" --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal"
	echo "Drupal add second user ${DRUPAL_USER1} ${DRUPAL_USER1_EMAIL}"
	drush -y user-create ${DRUPAL_USER1} --mail="${DRUPAL_USER1_EMAIL}" --password="${DRUPAL_USER1_PW}"
	drush -y user-add-role administrator ${DRUPAL_USER1}

	# todo: really needed?
	killall mysqld
	sleep 2s
	echo "Drupal site installed"
else 
	echo drupal already installed, starting lamp
fi
supervisord -c /etc/supervisord.conf -n

