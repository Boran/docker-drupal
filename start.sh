#!/bin/bash
#
# /start.sh
# Start drupal and related processes, install Drupal+co if not yet available
# https://github.com/Boran/webfact
#####


www=${DRUPAL_DOCROOT}
buildstat="/var/log/start.sh.log";   # allow build tracking outside this script

echo "---------- /start.sh image=boran/drupal REFRESHED_AT=$REFRESHED_AT, https://github.com/Boran/webfact, Build status in $buildstat -----------"
#env

# First time, No drupal or mysql yet?
if [ ! -f $www/sites/default/settings.php -a ! -f /drupal-db-pw.txt ]; then
  echo "01. Website not installed (there is no $www/sites/default/settings.php)"
  echo "1" > $buildstat

  echo "02. setup apache"
  echo "2" > $buildstat
  mkdir /var/log/apache2 2>/dev/null
  chown -R www-data /var/log/apache2 2>/dev/null
  a2enmod rewrite vhost_alias headers
  a2ensite 000-default

  if [[ ${DRUPAL_SSL} ]]; then
    a2enmod ssl
    # regenerate certificate to have a different one on each machine
    make-ssl-cert generate-default-snakeoil --force-overwrite
    a2ensite default-ssl
  fi

  echo "03. setup mysql"
  echo "3" > $buildstat
  if [[ ${MYSQL_HOST} ]]; then
    # A mysql server has been specified, do not activate locally
    if [[ ${MYSQL_DATABASE} ]] && [[ ${MYSQL_USER} ]]; then
      echo "Using mysql server:$MYSQL_HOST db:$MYSQL_DATABASE user:$MYSQL_USER (presuming DB already created)"
      echo "disabling local mysql: mv /etc/supervisord.d/mysql.conf /etc/supervisord.d/.mysql.conf"
      mv /etc/supervisord.d/mysql.conf /etc/supervisord.d/.mysql.conf
    else 
     echo "ERROR: Mysql spec incomplete: server:$MYSQL_HOST db:$MYSQL_DATABASE user:$MYSQL_USER "
     exit;
    fi

  else
    echo "-- setup mysql inside the container"
    mkdir /var/log/mysql 2>/dev/null
    chown -R mysql /var/log/mysql 2>/dev/null
    ## mysql: start, make passwords, create DBs
    /usr/bin/mysqld_safe --skip-syslog & 
    if [[ $? -ne 0 ]]; then
      echo "ERROR: mysql will not start";
      exit;
    fi
    sleep 5s
    MYSQL_HOST="localhost"
    MYSQL_USER="drupal"
    MYSQL_DATABASE="drupal"
    # Generate random passwords 
    MYSQL_ROOT_PASSWORD=`pwgen -c -n -1 12`
    MYSQL_PASSWORD=`pwgen -c -n -1 12`
    # If needed to show passwords in the logs: 
    #echo mysql root password: $MYSQL_ROOT_PASSWORD, drupal password: $MYSQL_PASSWORD
    echo "Generated mysql root + drupal password, see /root/.my.cnf /mysql-root-pw.txt /drupal-db-pw.txt"
    echo $MYSQL_PASSWORD > /drupal-db-pw.txt
    echo $MYSQL_ROOT_PASSWORD > /mysql-root-pw.txt
    chmod 400 /mysql-root-pw.txt /drupal-db-pw.txt
    mysqladmin -u root password $MYSQL_ROOT_PASSWORD 
    #echo "CREATE DATABASE $MYSQL_DATABASE; GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO $MYSQL_USER@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; FLUSH PRIVILEGES;"
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $MYSQL_DATABASE; GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO $MYSQL_USER@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; FLUSH PRIVILEGES;"
    # allow mysql cli for root
    mv /root/.my.cnf.sample /root/.my.cnf
    sed -i "s/ADDED_BY_START.SH/$MYSQL_ROOT_PASSWORD/" /root/.my.cnf
  fi 

  if [[ ${DRUPAL_NONE} ]]; then
    echo "-- DRUPAL_NONE is set: do not install a drupal site"
  else
    echo "04. setup drupal"
    echo "4" > $buildstat
    # a very long else now follows...
    # <drupal>
   
    # Is a proxy needed for the following steps?
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


    # - get custom profile
    if [[ ${DRUPAL_INSTALL_REPO} ]]; then
      echo "-- download drupal custom profile"
      cd $www/profiles 
      # todo: INSTALL_REPO: allow for private repos, https and authentication
      echo "git clone -q ${DRUPAL_INSTALL_REPO} ${DRUPAL_INSTALL_PROFILE}"
      git clone -q ${DRUPAL_INSTALL_REPO} ${DRUPAL_INSTALL_PROFILE}
    fi

    # - run the drupal installer 
    cd $www/sites/default
    echo "-- Installing Drupal with profile ${DRUPAL_INSTALL_PROFILE} site-name=${DRUPAL_SITE_NAME} "
    #drush site-install standard -y --account-name=admin --account-pass=admin --db-url="mysqli://drupal:${MYSQL_PASSWORD}@localhost:3306/drupal"
    #echo drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass=HIDDEN --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://drupal:HIDDEN@localhost:3306/drupal"
    drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass="${DRUPAL_ADMIN_PW}" --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:3306/${MYSQL_DATABASE}"
    if [[ $? -ne 0 ]]; then
      echo "ERROR: drush site-install failed";
      exit;
    fi

    # permissions: Minimal write access for apache:
    mkdir -p $www/sites/default/files  $www/sites/all/libraries/composer /var/lib/drupal-private
    chown -R www-data $www/sites/default/files /var/lib/drupal-private
    # D7 only, d8 will give an error
    # permissions: Allow modules/themes to be uploaded
    chown -R www-data $www/sites/all 2>/dev/null

    if [[ ${DRUPAL_MAKE_FEATURE_REVERT} ]]; then
      echo "Drupal revert features"
      cd $www/sites/default
      drush -y fra
    fi;

  cd $www
  echo "05. drupal finalising"
  echo "5" > $buildstat
  if [[ ${DRUPAL_USER1} ]]; then
    echo "-- Drupal add second user ${DRUPAL_USER1} ${DRUPAL_USER1_EMAIL} "
    drush -y user-create ${DRUPAL_USER1} --mail="${DRUPAL_USER1_EMAIL}" --password="${DRUPAL_USER1_PW}"
    if [[ ${DRUPAL_USER1_ROLE} ]]; then
      drush -y user-add-role ${DRUPAL_USER1_ROLE} ${DRUPAL_USER1}
    else
      drush -y user-add-role administrator ${DRUPAL_USER1}
    fi;
    # todo: Send onetime login to user, but email must work first!
    #drush -y user-login ${DRUPAL_USER1}
  fi;

  # Create a default status script
  cp /tmp/webfact_status.sh webfact_status.sh && chmod 755 webfact_status.sh

  if [[ ${DRUPAL_FINAL_CMD} ]]; then
    echo "-- Run custom comand DRUPAL_FINAL_CMD:"
    # todo security discussion: allows ANY command to be executed, giving power!
    # alternatively one could prefix it with drush and strip dodgy characters 
    # e.g. "!$|;&", but then it wont be as flexible!
    echo "${DRUPAL_FINAL_CMD}"
    eval ${DRUPAL_FINAL_CMD} 
  fi;

  if [[ ${DRUPAL_FINAL_SCRIPT} ]]; then
    echo "-- Run custom script DRUPAL_FINAL_SCRIPT: ${DRUPAL_FINAL_SCRIPT} "
    # todo security discussion: allows ANY command to be executed, giving power!
    if [[ -x "${DRUPAL_FINAL_SCRIPT}" ]] ; then
      ${DRUPAL_FINAL_SCRIPT}
    else
      echo "File '${DRUPAL_FINAL_SCRIPT}' is not executable or found"
    fi
  fi;


  echo "06. Drupal site installation finished. Starting processes via supervisor."
  echo "6" > $buildstat
  ## </drupal>
  fi

  # Stop mysql, will be restarted by supervisor below
  killall mysqld
  sleep 5s

else 
  echo "98. Drupal already installed."
  echo "98" > $buildstat
fi

# Is a custom script visible (can be added by inherited images)
if [ -x /custom.sh ] ; then
  . /custom.sh
fi

# Create log that can be written to in the running container, and visible in the
# docker log (stdout) and thus the webfact UI.
# todo: could this be done by supervisord, but it must send the tail to stdout?
webfactlog=/tmp/webfact.log;
echo "`date '+%Y-%m-%d %H:%M'` Create new $webfactlog" > $webfactlog
tail -f $webfactlog &

# Start any stuff in rc.local
echo "starting /etc/rc.local"
/etc/rc.local &
echo "99. Starting processes via supervisor."
echo "99" > $buildstat
# Start lamp, make sure no PIDs lying around
rm /var/run/apache2/apache2.pid /var/run/rsyslog.pid /var/run/mysqld/mysqld.pid /var/run/crond.pid 2>/dev/null 2>/dev/null
supervisord -c /etc/supervisord.conf -n

