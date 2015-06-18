# docker container for Drupal 
# Ubuntu 14.04 +mysql+apache+ tools + drupal
#
# VERSION       1
# DOCKER-VERSION        1
FROM             ubuntu:14.04
MAINTAINER       Sean Boran <sean_at_boran.com>
ENV REFRESHED_AT 2015-06-18

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -qqy update

RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl  

# todo: make some optional (to save space/time): memcache, compass
RUN apt-get -qy install git mysql-client mysql-server apache2 libapache2-mod-php5 pwgen python-setuptools vim-tiny php5-mysql php5-gd php5-curl curl wget
#maybe later: software-properties-common
#RUN apt-get -qy install php5-memcache memcached 
#RUN apt-get -qy install ruby-compass
RUN apt-get -q autoclean

# drush: instead of installing a package, pull via composer into /opt/composer
# http://www.whaaat.com/installing-drush-7-using-composer
RUN curl -sS https://getcomposer.org/installer | php 
RUN mv composer.phar /usr/local/bin/composer
RUN COMPOSER_HOME=/opt/composer composer --quiet global require drush/drush:dev-master
RUN ln -s /opt/composer/vendor/drush/drush/drush /bin/drush
# Add drush comand https://www.drupal.org/project/registry_rebuild
RUN wget http://ftp.drupal.org/files/projects/registry_rebuild-7.x-2.2.tar.gz && \
    tar xzf registry_rebuild-7.x-2.2.tar.gz && \
    rm registry_rebuild-7.x-2.2.tar.gz && \
    mv registry_rebuild /opt/composer/vendor/drush/drush/commands
#RUN sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' /root/.bashrc
RUN /bin/drush --version

# Option: Make mysql listen on the outside, might be useful for backups
# but adds a security risk.
#RUN sed -i "s/^bind-address/#bind-address/" /etc/mysql/my.cnf
ADD files/root/.my.cnf.sample /root/.my.cnf.sample


# Use a proxy for downloads?
#ENV PROXY http://proxy.example.ch:80

## ---
## Drupal settings: used by start.sh within the container
#  can be overridden at run time e.g. -e "DRUPAL_XX=YY"
ENV DRUPAL_DOCROOT /var/www/html

### Install drupal: 
# A) Use the drupal included the the image (no parameter needed)

# B) a specific vanilla version via drush 
# What version of drupal is to be installed (see drush sl syntax): drupal-6, drupal-7, drupal-7.x (dev), 8.0.x-dev
#ENV DRUPAL_VERSION drupal-7

# C) Install via Drush make
#ENV DRUPAL_MAKE_DIR  drupal-make1
#ENV DRUPAL_MAKE_REPO https://github.com/Boran/drupal-make1
ENV DRUPAL_MAKE_BRANCH master
#Which will run:  drush make ${DRUPAL_MAKE_DIR}/${DRUPAL_MAKE_DIR}.make ${DRUPAL_DOCROOT}
#During build testing one can just copy in makes to save time:
#ADD ./drupal-make1  /opt/drush-make/drupal-make1

# D) Pull The entire Drupal site from a Repo, default is master branch
#ENV DRUPAL_GIT_REPO  https://USER:PASSWORD@example.org/path/something
ENV DRUPAL_GIT_BRANCH master

# E) Pull The entire Drupal site from a Repo with ssh+keys
#DRUPAL_GIT_SSH=/gitwrap.sh


### Run an 'install profile': standard or custom?
ENV DRUPAL_INSTALL_PROFILE standard
# Example custom profile: pull it from git
#ENV DRUPAL_INSTALL_PROFILE boran1
#ENV DRUPAL_INSTALL_REPO https://github.com/Boran/drupal-profile1.git
# During build test: copy in directly
#ADD ./drupal-profile1      /var/www/html/profiles/boran1


### Run a feature revert revert after installing, can be useful for default content
#ENV DRUPAL_MAKE_FEATURE_REVERT 1

## Default Drupal settings
ENV DRUPAL_SITE_NAME My Drupal Site
ENV DRUPAL_SITE_EMAIL drupal@example.ch
ENV DRUPAL_ADMIN admin
ENV DRUPAL_ADMIN_PW admin
ENV DRUPAL_ADMIN_EMAIL root@example.ch
#by default no second user  
#ENV DRUPAL_USER1 admin2
#ENV DRUPAL_USER1_PW admin2
#ENV DRUPAL_USER1_EMAIL drupal@example.ch
#ENV DRUPAL_USER1_ROLE administrator

# Run a custom command after the site is installed
# Example: get,enable and run the production check module
#ENV DRUPAL_FINAL_CMD drush -y dl prod_check && drush -y en prod_check && drush -y cache-clear drush && drush -y prod-check-prodmode

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


# Make sure we have a proper working terminal
ENV TERM xterm

WORKDIR /var/www/html
# Automate starting of mysql+apache, allow bash for debugging
RUN chmod 755 /start.sh /etc/apache2/foreground.sh
EXPOSE 80
CMD ["/bin/bash", "/start.sh"]

