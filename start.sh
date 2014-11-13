#!/bin/bash
# /start.sh

www=${DRUPAL_DOCROOT}
echo "---------- /start.sh -----------"

if [ ! -f $www/sites/default/settings.php ]; then

	## mysql: start, make passwords, create DBs
	echo "-- setup mysql"
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

	if [[ ${PROXY} ]]; then
	  echo "-- enable proxy ${PROXY} "
          export http_proxy=${PROXY}
          export https_proxy=${PROXY}
          export ftp_proxy=${PROXY}
        fi

	echo "-- download drupal"
	if [[ ${DRUPAL_MAKE_DIR} && ${DRUPAL_MAKE_REPO} ]]; then
	  echo "-- DRUPAL_MAKE_DIR/REPO set, build Drupal from makefile in /opt/drush-make"
	  mv $www $www.$$ 2>/dev/null             # will be created new by drush make
	  mkdir /opt/drush-make 2>/dev/null
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
	  #todo: if $www does not exist, then make does not work

	elif [[ ${DRUPAL_GIT_REPO} && ${DRUPAL_GIT_BRANCH} ]]; then
          cd /var/www && mv html html.orig
          if [[ ${DRUPAL_GIT_SSH} ]]; then
	    echo "-- pull the drupal site from ${DRUPAL_GIT_REPO} with ssh keys, branch ${DRUPAL_GIT_BRANCH}"
            # pull via ssh /gitwrap.sh and /root/.ssh must be mounted as volumes
            echo "GIT_SSH=${DRUPAL_GIT_SSH} git clone -b ${DRUPAL_GIT_BRANCH} -q ${DRUPAL_GIT_REPO} html"
            GIT_SSH=${DRUPAL_GIT_SSH} git clone -b ${DRUPAL_GIT_BRANCH} -q ${DRUPAL_GIT_REPO} html
            #todo:  "undetached head" when tags are used
          else
            # todo: hide password from echoed URL
	    #echo "-- pull the drupal site from git ${DRUPAL_GIT_REPO}, branch ${DRUPAL_GIT_BRANCH}"
	    echo "-- pull the drupal site from git, branch ${DRUPAL_GIT_BRANCH}"
            #git clone -q https://USER:PASSWORD@example.org/path/something html
            git clone -b ${DRUPAL_GIT_BRANCH} -q ${DRUPAL_GIT_REPO} html
          fi

	elif [[ ${DRUPAL_VERSION} ]]; then
	  cd /var/www && mv html html.orig 2>/dev/null
	  echo "-- download ${DRUPAL_VERSION} with drush"
          echo "drush dl ${DRUPAL_VERSION} --drupal-project-rename=html"
          drush dl ${DRUPAL_VERSION} --drupal-project-rename=html
          #mv drupal* html;
	  chmod 755 html/sites/default; mkdir html/sites/default/files; chown -R www-data:www-data html/sites/default/files;

	else 
          # quickest: pull in drupal already at the image stage
	  echo "-- download drupal: use the drupal version included with this image "
	  cd /var/www && mv html html.orig 
          mv /tmp/drupal /var/www/html
	  chmod 755 html/sites/default; mkdir html/sites/default/files; chown -R www-data:www-data html/sites/default/files;
	fi


	#  - get custom profile
	if [[ ${DRUPAL_INSTALL_REPO} ]]; then
	  echo "-- download drupal custom profile"
	  cd $www/profiles 
	  # todo: allow for private repos, https and authentication
	  echo "git clone -q ${DRUPAL_INSTALL_REPO} ${DRUPAL_INSTALL_PROFILE}"
	  git clone -q ${DRUPAL_INSTALL_REPO} ${DRUPAL_INSTALL_PROFILE}
        fi

	# - run the drupal installer 
	cd $www/sites/default
	echo "-- Installing Drupal with profile ${DRUPAL_INSTALL_PROFILE} site-name=${DRUPAL_SITE_NAME} "
	#drush site-install standard -y --account-name=admin --account-pass=admin --db-url="mysqli://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal"
	#echo drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass=HIDDEN --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://drupal:HIDDEN@localhost:3306/drupal"
	drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass="${DRUPAL_ADMIN_PW}" --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://drupal:${DRUPAL_PASSWORD}@localhost:3306/drupal"


	# permissions: Minimal write access for apache:
	chown -R www-data $www/sites/default/files
        # D7 only, d8 will give an error
	# permissions: Allow modules/themes to be uploaded
	chown -R www-data $www/sites/all 2>/dev/null

	if [[ ${DRUPAL_MAKE_FEATURE_REVERT} ]]; then
	  echo "Drupal revert features"
          cd $www/sites/default
          drush -y fra
        fi;

	if [[ ${DRUPAL_USER1} ]]; then
          echo "Drupal add second user ${DRUPAL_USER1} ${DRUPAL_USER1_EMAIL} "
	  drush -y user-create ${DRUPAL_USER1} --mail="${DRUPAL_USER1_EMAIL}" --password="${DRUPAL_USER1_PW}"
	  if [[ ${DRUPAL_USER1_ROLE} ]]; then
	    echo "drush -y user-add-role ${DRUPAL_USER1_ROLE} ${DRUPAL_USER1}"
	    drush -y user-add-role ${DRUPAL_USER1_ROLE} ${DRUPAL_USER1}
          else
	    drush -y user-add-role administrator ${DRUPAL_USER1}
          fi;
          # todo: Send onetime login to user, but email must work first!
          #drush -y user-login ${DRUPAL_USER1}
        fi;

	# todo: really needed?
	killall mysqld
	sleep 3s
	echo "Drupal site installed"
else 
	echo "Drupal already installed, starting lamp"
fi

# Is a custom script visible (can be added by inherited images)
if [ -x /custom.sh ] ; then
  . /custom.sh
fi

# Start any stuff in rc.local
echo "starting /etc/rc.local"
/etc/rc.local &
# Start lamp, make sure no PIDs lying around
rm /var/run/apache2/apache2.pid /var/run/rsyslog.pid /var/run/mysqld/mysqld.pid /var/run/crond.pid 2>/dev/null 2>/dev/null
supervisord -c /etc/supervisord.conf -n

