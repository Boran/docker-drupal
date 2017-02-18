#!/bin/bash
#
# /start.sh
# Start drupal and related processes, install Drupal+co if not yet available
# https://github.com/Boran/webfact
#####

if [[ ${DRUPAL_DEBUG} ]]; then
  echo "====== DRUPAL_DEBUG enabled : echo all commands. Warning: some passwords will be visible! ===="
  echo "----- debug: environment ----"
  env
  echo "----- /environment ----"
  set -x
fi

www=${DRUPAL_DOCROOT}

# allow build tracking outside this script/container
# only updated during building, not running.
buildstat="/var/www/html/.start.sh.stat";   
# Keep legacy path for compatability 2015.12.04
ln -s $buildstat /var/log/start.sh.log 2>/dev/null

echo "00. -- /start.sh run date=`date '+%Y%m%d-%H%M'` base image=boran/drupal Image date=$REFRESHED_AT, https://github.com/Boran/webfact, build status in $buildstat -----"
#env


echo "01. setup apache"
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

# Ensure /var/lib/drupal-private is there
  mkdir -p /var/lib/drupal-private
  chown -R www-data /var/lib/drupal-private

echo "02. check mysql"
  if [[ ${MYSQL_HOST} ]]; then
    if [[ -f /etc/supervisord.d/mysql.conf ]]; then
      echo "02. DB is outside the container on $MYSQL_HOST "
      #echo "    So delete mysql-server within the container: apt-get remove mysql-server; rm /etc/supervisord.d/mysql.conf "
      rm /etc/supervisord.d/mysql.conf
      # 2015.10.17: no longer remove these, slows down creation
      #apt-get -qqy remove mysql-server
      #apt-get -qy autoremove
    fi

    # is a external DB already available? Note: must use eval to avoid docker run aborting if not 0
    #db_already=0;
    #if [[ ${MYSQL_DATABASE} ]] && [[ ${MYSQL_USER} ]] && [[ ${MYSQL_PASSWORD} ]]; then
    #  eval "echo 'select count(*) from watchdog' | mysql -NAbqs -h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE"
    #  ret=$?
    #  if [[ $ret -eq 0 ]]; then
    #    echo "External DB $MYSQL_DATABASE on $MYSQL_HOST already there. $res";
    #    db_already=1;
    #  else 
    #    echo "External DB $MYSQL_DATABASE on $MYSQL_HOST drupal tables do not yet exist.";
    #  fi
    #fi
  fi


# is drupal already installed, or an internal or external DB?
#if [[ ! -f $www/sites/default/settings.php ]] && [[ ! -f /drupal-db-pw.txt ]] && [[ $db_already -eq 0 ]]; then
if [[ ! -f $www/sites/default/settings.php ]] && [[ ! -f /drupal-db-pw.txt ]]                           ; then

  echo "03. Website not installed: there is no $www/sites/default/settings.php and no DB"
  echo "30" > $buildstat

  echo "04. check mysql environment"
  if [[ ${MYSQL_HOST} ]]; then
    # A mysql server has been specified, do not activate locally
    if [[ ${MYSQL_DATABASE} ]] && [[ ${MYSQL_USER} ]]; then
      echo "Using mysql server:$MYSQL_HOST db:$MYSQL_DATABASE user:$MYSQL_USER (presuming DB already created)"
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
  echo "35" > $buildstat


  echo "     "
  if [[ ${DRUPAL_NONE} ]]; then
    echo "-- DRUPAL_NONE is set: do not install a drupal site"
  else
    echo "04. setup drupal"
    echo "40" > $buildstat
    # a very long else now follows...
    # <drupal>
   
    # Is a proxy needed for the following steps?
    if [[ ${PROXY} ]]; then
      echo "-- enable proxy ${PROXY} "
      export http_proxy=${PROXY}
      export https_proxy=${PROXY}
      export ftp_proxy=${PROXY}
    fi
    # Proxy exceptions
    if [[ ${NO_PROXY} ]]; then
      echo "-- add proxy exceptions for ${NO_PROXY} "
      export no_proxy=${NO_PROXY}
    fi

    echo "-- download drupal"
    mkdir -p $www                             # ensure it exists
    if [[ ${DRUPAL_MAKE_DIR} && ${DRUPAL_MAKE_REPO} ]]; then
      echo "41" > $buildstat
      echo "-- DRUPAL_MAKE_DIR/REPO set, build Drupal from makefile in /opt/drush-make"
      mkdir /opt/drush-make 2>/dev/null
      cd /opt/drush-make
      echo "git clone -b ${DRUPAL_MAKE_BRANCH} -q ${DRUPAL_MAKE_REPO} ${DRUPAL_MAKE_DIR}"
      git clone -b ${DRUPAL_MAKE_BRANCH} -q ${DRUPAL_MAKE_REPO} ${DRUPAL_MAKE_DIR}
      #echo "make command: ${DRUPAL_MAKE_CMD}"
      #${DRUPAL_MAKE_CMD}
      drush make ${DRUPAL_MAKE_DIR}/${DRUPAL_MAKE_DIR}.make /var/tmp/drupal-install
      if [ $? -ne 0 ] ; then
        echo ">>>>> ERROR: drush make failed, aborting <<<<<<"
        exit -1;
      fi;
      (cd /var/tmp/drupal-install && mv .[a-zA-Z0-9]* * $www)


    elif [[ ${DRUPAL_GIT_REPO} && ${DRUPAL_GIT_BRANCH} ]]; then
      echo "42" > $buildstat
      cd $www
      if [[ ${DRUPAL_GIT_SSH} ]]; then
        echo "-- pull the drupal site from ${DRUPAL_GIT_REPO} with ssh keys, branch ${DRUPAL_GIT_BRANCH}"
        # pull via ssh /gitwrap.sh and /root/.ssh must be mounted as volumes
        echo "GIT_SSH=${DRUPAL_GIT_SSH} git clone -b ${DRUPAL_GIT_BRANCH} -q ${DRUPAL_GIT_REPO} ."
        GIT_SSH=${DRUPAL_GIT_SSH} git clone -b ${DRUPAL_GIT_BRANCH} -q ${DRUPAL_GIT_REPO} .
        #todo:  "undetached head" when tags are used
      else
        # todo: hide password from echoed URL
        #echo "-- pull the drupal site from git ${DRUPAL_GIT_REPO}, branch ${DRUPAL_GIT_BRANCH}"
        echo "-- clone the drupal site from git, branch ${DRUPAL_GIT_BRANCH}"
        #git clone -q https://USER:PASSWORD@example.org/path/something .

        #git clone -b ${DRUPAL_GIT_BRANCH} -q ${DRUPAL_GIT_REPO} .
        # better method if files already present,note all branches will be downloaded!
        # todo: only get one branch: clone --single-brach or remote -t remote-branchn or fetch origin <branch_name>
        rm -f index.html
        git init 
        git remote add origin ${DRUPAL_GIT_REPO} 
        git fetch
        git checkout -q  origin/${DRUPAL_GIT_BRANCH}
      fi
      echo "-- git submodule and update"
        git submodule init
        git submodule update

    elif [[ ${DRUPAL_VERSION} ]]; then
      echo "43" > $buildstat
      mkdir /var/tmp/drupal-install && cd /var/tmp/drupal-install
      echo "-- download ${DRUPAL_VERSION} with drush"
      echo "drush dl ${DRUPAL_VERSION} --drupal-project-rename=drupal"
      drush dl ${DRUPAL_VERSION} --drupal-project-rename=drupal
      (cd drupal && mv .[a-zA-Z0-9]* * $www)
      rmdir /var/tmp/drupal-install/drupal
      cd $www
      chmod 755 sites/default; mkdir sites/default/files; chown -R www-data:www-data sites/default/files;

    else 
      # quickest: pull in drupal already at the image stage
      echo "-- download drupal: copy the version included with this image "
      (cd /tmp/drupal && tar cf - .[a-zA-Z0-9]* *) | (cd $www && tar xf -)
      cd $www
      mkdir -p sites/default/files && chmod 755 sites/default && chown -R www-data:www-data sites/default/files;
    fi


    # - get custom profile
    if [[ ${DRUPAL_INSTALL_REPO} ]]; then
      echo "-- download drupal custom profile"
      echo "45" > $buildstat
      cd $www/profiles 
      # todo: INSTALL_REPO: allow for private repos, https and authentication
      echo "git clone -b ${DRUPAL_INSTALL_PROFILE_BRANCH} -q ${DRUPAL_INSTALL_REPO} ${DRUPAL_INSTALL_PROFILE}"
      git clone -b ${DRUPAL_INSTALL_PROFILE_BRANCH} -q ${DRUPAL_INSTALL_REPO} ${DRUPAL_INSTALL_PROFILE}
    fi

    # - run the drupal installer 
    echo "50" > $buildstat
    cd $www/sites/default || exit -1
    echo "05. -- Installing Drupal with profile=${DRUPAL_INSTALL_PROFILE} site-name=${DRUPAL_SITE_NAME} "
    #drush site-install standard -y --account-name=admin --account-pass=admin --db-url="mysqli://drupal:${MYSQL_PASSWORD}@localhost:3306/drupal"
    drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass="${DRUPAL_ADMIN_PW}" --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:3306/${MYSQL_DATABASE}"
    if [[ $? -ne 0 ]]; then
      echo "-- ERROR: drush site-install failed";
      echo drush site-install ${DRUPAL_INSTALL_PROFILE} -y --account-name=${DRUPAL_ADMIN} --account-pass="${DRUPAL_ADMIN_PW}" --account-mail="${DRUPAL_ADMIN_EMAIL}" --site-name="${DRUPAL_SITE_NAME}" --site-mail="${DRUPAL_SITE_EMAIL}"  --db-url="mysqli://${MYSQL_USER}:HIDDEN@${MYSQL_HOST}:3306/${MYSQL_DATABASE}"
      echo "--";
      exit;
    fi

    # permissions: Minimal write access for apache:
    mkdir -p $www/sites/default/files  $www/sites/all/libraries/composer 
    chown -R www-data $www/sites/default/files 
    # D7 only, d8 will give an error
    # permissions: Allow modules/themes to be uploaded
    chown -R www-data $www/sites/all 2>/dev/null

    if [[ ${DRUPAL_MAKE_FEATURE_REVERT} ]]; then
      echo "52" > $buildstat
      echo "Drupal revert features"
      cd $www/sites/default
      drush -y fra
    fi;

  cd $www
  echo "06. drupal finalising"
  echo "60" > $buildstat
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
  if [ ! -f webfact_status.sh ] ; then
    cp /tmp/webfact_status.sh webfact_status.sh && chmod 755 webfact_status.sh
  fi;

  if [[ ${DRUPAL_FINAL_CMD} ]]; then
    echo "65" > $buildstat
    echo "-- Run custom comand DRUPAL_FINAL_CMD:"
    # todo security discussion: allows ANY command to be executed, giving power!
    # alternatively one could prefix it with drush and strip dodgy characters 
    # e.g. "!$|;&", but then it wont be as flexible!
    echo "${DRUPAL_FINAL_CMD}"
    eval ${DRUPAL_FINAL_CMD} 
  fi;

  if [[ ${DRUPAL_FINAL_SCRIPT} ]]; then
    echo "66" > $buildstat
    echo "-- Run custom script DRUPAL_FINAL_SCRIPT: ${DRUPAL_FINAL_SCRIPT} "
    # todo security discussion: allows ANY command to be executed, giving power!
    if [[ -x "${DRUPAL_FINAL_SCRIPT}" ]] ; then
      ${DRUPAL_FINAL_SCRIPT}
    else
      echo "File '${DRUPAL_FINAL_SCRIPT}' is not executable or found"
    fi
  fi;


  echo "08. Drupal site installation finished. Starting processes via supervisor."
  echo "80" > $buildstat
  ## </drupal>
  fi

  if [ "x$MYSQL_HOST" == 'xlocalhost' ] ; then
    # Stop mysql, will be restarted by supervisor below
    killall mysqld
    sleep 5s
  fi


  # build is 100% done
  echo "100" > $buildstat

else 
  echo "09. Site already installed or DB exists: no installation needed."
fi


# Enable the cron/syslog daemons?
if [[ ${SUPERVISOR_CRON_ENABLE} ]]; then
  echo "-- Enable cron via supervisor"
  mv  /etc/supervisord.d/.cron.conf /etc/supervisord.d/cron.conf
  mv  /etc/init.d/.cron  /etc/init.d/cron
fi
if [[ ${SUPERVISOR_RSYSLOG_ENABLE} ]]; then
  echo "-- Enable rsyslog via supervisor"
  mv  /etc/supervisord.d/.rsyslog.conf /etc/supervisord.d/rsyslog.conf
  mv  /etc/init.d/.rsyslog  /etc/init.d/rsyslog
fi

# Tuning specific to the webfactory i
# (todo: find a way to xeremove this from this image)
if [[ ${WEBFACT_RM_SITE_ENABLE} ]]; then
  echo "-- Webfactory specific: Enable script for deleting sites /etc/sudoers.d/webfact, /opt/sites/webfact_rm_site.sh"
  echo "www-data ALL=(ALL) NOPASSWD: /opt/sites/webfact_rm_site.sh" > /etc/sudoers.d/webfact
  cp -f /tmp/.webfact_rm_site.sh /opt/sites/webfact_rm_site.sh
  chmod a+x /opt/sites/webfact_rm_site.sh
fi


# Is a custom script visible (can be added by inherited images)
# If any building is done in there, augment $buildstat there too.
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
echo "-- starting /etc/rc.local"
/etc/rc.local &

echo "10. Starting processes via supervisor."
# Start lamp, make sure no PIDs lying around
rm /var/run/apache2/apache2.pid /var/run/rsyslog.pid /var/run/rsyslogd.pid /var/run/mysqld/mysqld.pid /var/run/crond.pid 2>/dev/null 2>/dev/null
supervisord -c /etc/supervisord.conf -n

