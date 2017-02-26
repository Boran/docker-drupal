## See Description LABEL at the bottom ##

FROM             ubuntu:14.04
MAINTAINER       Sean Boran <sean_at_boran.com>

ENV REFRESHED_AT=2017-02-26 \
    #PROXY=http://proxy.example.ch:80 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get -qqy update && \
    dpkg-divert --local --rename --add /sbin/initctl && \
    ln -sf /bin/true /sbin/initctl  

# Additional base packages
# More later: software-properties-common php5-memcache memcached ruby-compass 
RUN apt-get -qy install git vim-tiny curl wget pwgen \
  mysql-client mysql-server \
  apache2 libapache2-mod-php5 php5-mysql php5-gd php5-curl \
  python-setuptools && \
  apt-get -q autoclean

# drush: instead of installing a package, pull via composer into /opt/composer
# http://www.whaaat.com/installing-drush-7-using-composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    COMPOSER_HOME=/opt/composer composer --quiet global require drush/drush:8.* && \
    ln -s /opt/composer/vendor/drush/drush/drush /bin/drush
# Add drush comand https://www.drupal.org/project/registry_rebuild
RUN wget http://ftp.drupal.org/files/projects/registry_rebuild-7.x-2.2.tar.gz && \
    tar xzf registry_rebuild-7.x-2.2.tar.gz && \
    rm registry_rebuild-7.x-2.2.tar.gz && \
    mv registry_rebuild /opt/composer/vendor/drush/drush/commands
#RUN sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' /root/.bashrc
RUN /bin/drush --version
RUN /bin/drush dl drush_language-7.x

# Option: Make mysql listen on the outside, might be useful for backups
# but adds a security risk.
#RUN sed -i "s/^bind-address/#bind-address/" /etc/mysql/my.cnf
ADD files/root/.my.cnf.sample /root/.my.cnf.sample

# Sample backup script
ADD files/backup.sh  /root/backup.sh
# Webfactory specifc
ADD files/webfact_rm_site.sh /tmp/.webfact_rm_site.sh

# ENV variables
# (note: ENV is one long line to minimise layers)
ENV \
  # Make sure we have a proper working terminal
  TERM=xterm \

  ## ---
  ## Drupal settings: used by start.sh within the container
  #  can be overridden at run time e.g. -e "DRUPAL_XX=YY"
  DRUPAL_DOCROOT=/var/www/html \
  ### Install drupal: 
  # A) Use the drupal included in the image (no parameter needed)
   
  # B) a specific vanilla version via drush 
  # What version of drupal is to be installed (see drush sl syntax): drupal-6, drupal-7, drupal-7.x (dev), 8.0.x-dev
  #DRUPAL_VERSION=drupal-7
   
  # C) Install via Drush make
  #DRUPAL_MAKE_DIR=drupal-make1
  #DRUPAL_MAKE_REPO=https://github.com/Boran/drupal-make1
  DRUPAL_MAKE_BRANCH=master \
  #Which will run:  drush make ${DRUPAL_MAKE_DIR}/${DRUPAL_MAKE_DIR}.make ${DRUPAL_DOCROOT}
  #During build testing one can just copy in makes to save time:
  #ADD ./drupal-make1  /opt/drush-make/drupal-make1

  # D) Pull The entire Drupal site from a Repo, default is master branch
  #DRUPAL_GIT_REPO=https://USER:PASSWORD@example.org/path/something
  DRUPAL_GIT_BRANCH=master \

  # E) Pull The entire Drupal site from a Repo with ssh+keys
  #DRUPAL_GIT_SSH=/gitwrap.sh


  ### Run an 'install profile': standard or custom?
  DRUPAL_INSTALL_PROFILE=standard \
  DRUPAL_INSTALL_PROFILE_BRANCH=master \
  # Example custom profile: pull it from git
  #DRUPAL_INSTALL_PROFILE=boran1
  #DRUPAL_INSTALL_REPO=https://github.com/Boran/drupal-profile1.git
  # During build test: copy in directly
  #ADD ./drupal-profile1      /var/www/html/profiles/boran1


  ### Run a feature revert revert after installing, can be useful for default content
  #DRUPAL_MAKE_FEATURE_REVERT=1

  ## Default Drupal settings
  DRUPAL_SITE_NAME="My Drupal Site" DRUPAL_SITE_EMAIL=drupal@example.ch \
  DRUPAL_ADMIN=admin DRUPAL_ADMIN_PW=admin \
  DRUPAL_ADMIN_EMAIL=root@example.ch
  #by default no second user  
  #DRUPAL_USER1=admin2 DRUPAL_USER1_PW=admin2 DRUPAL_USER1_EMAIL=drupal@example.ch ENV DRUPAL_USER1_ROLE=administrator

  # Run a custom command after the site is installed
  # Example: get, enable and run the production check module
  #DRUPAL_FINAL_CMD="drush -y dl prod_check && drush -y en prod_check && drush -y cache-clear drush && drush -y prod-check-prodmode"

# /ENV


# Setup a default postfix to allow local delivery and stop drupal complaining
#  for external delivery add local config to custom.sh such as:
#  postconf -e 'relayhost = myrelay.example.ch'
RUN apt-get install -q -y postfix
ADD ./files/postfix.sh /opt/postfix.sh
RUN chmod 755 /opt/postfix.sh

### Custom startup scripts
RUN easy_install supervisor

# Retrieve drupal: changed - now in start.sh to allow for makes too.
# Push down a copy of drupal
ADD ./files/drupal-7  /tmp/drupal

ADD ./files/webfact_status.sh /tmp/webfact_status.sh
ADD ./files/supervisord.conf /etc/supervisord.conf
ADD ./files/supervisord.d    /etc/supervisord.d
ADD ./files/init.d/*         /etc/init.d/
ADD ./files/foreground.sh    /etc/apache2/foreground.sh
ADD ./ubuntu1404/000-default.conf /etc/apache2/sites-available/000-default.conf
ADD ./ubuntu1404/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
ADD ./gitwrap.sh /gitwrap.sh
ADD ./start.sh /start.sh


VOLUME ["/var/www/html", "/data"]
# Using /var/www/html as WORKDIR causes docker exec to fail in certain cases
#WORKDIR /var/www/html
WORKDIR /var
# Automate starting of mysql+apache, allow bash for debugging
RUN chmod 755 /start.sh /etc/apache2/foreground.sh
EXPOSE 80
CMD ["/bin/bash", "/start.sh"]

LABEL Description="Docker for Drupal Websites. Ubuntu 14.04 mysql+apache+drupal/composer/drush..." Version="1.2"

# Dockerfile todo:
# - "DEBIAN_FRONTEND noninteractive" should be prefixed on each line to avoid a default
# - add more labels

