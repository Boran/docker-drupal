#!/bin/bash
# /start.sh

www=${DRUPAL_DOCROOT}

if [ ! -f $www/sites/default/settings.php ]; then

	## mysql
	echo "-- setup mysql"
	# Start mysql
	/usr/bin/mysqld_safe --skip-syslog & 
	sleep 5s
	# Generate random passwords 
	DRUPAL_DB="drupal"
	MYSQL_PASSWORD=`pwgen -c -n -1 12`
	DRUPAL_PASSWORD=`pwgen -c -n -1 12`
	# If needed to show passwords in ther logs. 
	#echo mysql root password: $MYSQL_PASSWORD, drupal password: $DRUPAL_PASSWORD
     	echo "Generated mysql root + drupal password, see /mysql-root-pw.txt /drupal-db-pw.txt"
	echo $MYSQL_PASSWORD > /mysql-root-pw.txt
	echo $DRUPAL_PASSWORD > /drupal-db-pw.txt
	mysqladmin -u root password $MYSQL_PASSWORD 
	mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE drupal; GRANT ALL PRIVILEGES ON drupal.* TO 'drupal'@'localhost' IDENTIFIED BY '$DRUPAL_PASSWORD'; FLUSH PRIVILEGES;"

	echo "-- setup apache"
	a2enmod rewrite vhost_alias headers
	#12.04 sed -i 's/AllowOverride None/AllowOverride All/' $defaultsite


        ## Drupal
	echo "-- setup drupal"
	if [[ ${DRUPAL_MAKE_DIR} ]]; then
	  echo "-- Build Drupal from makefile in /opt/drush-make"
	  mv $www $www.$$                 # will be created new by drush make
	  mkdir /opt/drush-make
	  cd /opt/drush-make
	  echo "git clone -q ${DRUPAL_MAKE_REPO} ${DRUPAL_MAKE_DIR}"
	  git clone -q ${DRUPAL_MAKE_REPO} ${DRUPAL_MAKE_DIR}
	  #git clone -q ${DRUPAL_MAKE_REPO} ${DRUPAL_MAKE_DIR}
	  #echo "make command: ${DRUPAL_MAKE_CMD}"
	  #${DRUPAL_MAKE_CMD}
	  drush make ${DRUPAL_MAKE_DIR}/${DRUPAL_MAKE_DIR}.make $www
	  if [ $? -ne 0 ] ; then
	    echo ">>>>> ERROR: drush make failed, aborting <<<<<<"
	    exit -1;
	  fi;
	  #todo: if $www does not exist, then make did not work

	else 
	  # Download drupal, specified version
	  cd /var/www && mv html html.orig && drush -q dl drupal ${DRUPAL_VERSION}; mv drupal* html;
	  chmod 755 html/sites/default; mkdir html/sites/default/files; chown -R www-data:www-data html/sites/default/files;
	fi

	#  - get customer profile
	if [[ ${DRUPAL_INSTALL_REPO} ]]; then
	  cd $www/profiles 
	  # todo: allow for private repos, https and authentication
	  echo "git clone -q ${DRUPAL_INSTALL_REPO} ${DRUPAL_INSTALL_PROFILE}"
	  git clone -q ${DRUPAL_INSTALL_REPO} ${DRUPAL_INSTALL_PROFILE}
        fi

	# - run the drupal installer 
	cd $www/sites/default
	echo "Installing Drupal with profile ${DRUPAL_INSTALL_PROFILE} site-name=${DRUPAL_SITE_NAME} "
	#drush site-install standard -y --account-name=admin --account-pass=admin --db-url="mysqli://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal"
	echo drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass="${DRUPAL_ADMIN_PW}" --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal"
	drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass="${DRUPAL_ADMIN_PW}" --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal"

	echo "chown -R www-data $www/sites/default/files"
	chown -R www-data $www/sites/default/files

	if [[ ${DRUPAL_USER1} ]]; then
          echo "Drupal add second user ${DRUPAL_USER1} ${DRUPAL_USER1_EMAIL}"
	  drush -y user-create ${DRUPAL_USER1} --mail="${DRUPAL_USER1_EMAIL}" --password="${DRUPAL_USER1_PW}"
	  drush -y user-add-role administrator ${DRUPAL_USER1}
        fi;

	# todo: really needed?
	killall mysqld
	sleep 2s
	echo "Drupal site installed"
else 
	echo "drupal already installed, starting lamp"
fi

# Start any stuff in rc.local
echo "starting /etc/rc.local"
/etc/rc.local &
# Start lamp, but make sure apache not blocked
rm /var/run/apache2/apache2.pid 2>/dev/null
supervisord -c /etc/supervisord.conf -n


