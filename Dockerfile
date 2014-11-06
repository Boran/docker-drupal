# docker container for Drupal 
# Ubuntu 14.04 +mysql+apache+ tools + drupal
#
# VERSION       1
# DOCKER-VERSION        1
FROM             ubuntu:14.04
MAINTAINER       Sean Boran <sean_at_boran.com>
ENV REFRESHED_AT 2014-10-29

RUN apt-get -qqy update

RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl  

# Todo: php-apc, or php5 cache?
# todo: make some optional (to save space/time): memcache, compass
RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install git mysql-client mysql-server apache2 libapache2-mod-php5 pwgen python-setuptools vim-tiny php5-mysql php5-gd php5-curl curl 
#maybe later: software-properties-common
RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install php5-memcache memcached 
RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install ruby-compass
RUN DEBIAN_FRONTEND=noninteractive apt-get -q autoclean
RUN apt-get -q autoclean

# drush: instead of installing a package, pull via composer
RUN apt-get -q install curl
RUN curl -sS https://getcomposer.org/installer | php 
RUN mv composer.phar /usr/local/bin/composer
RUN sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' /root/.bashrc
RUN composer --quiet global require drush/drush:dev-master
RUN ln -s /root/.composer/vendor/bin/drush /usr/local/bin/drush
RUN /usr/local/bin/drush --version

# Option: Make mysql listen on the outside, might be useful for backups
# but adds a security risk.
#RUN sed -i "s/^bind-address/#bind-address/" /etc/mysql/my.cnf


WORKDIR /var/www
# Retrieve drupal: changed - now in start.sh to allow for makes too.
#RUN mv html html.orig && drush -q dl drupal; mv drupal* html;
#RUN chmod 755 html/sites/default; mkdir html/sites/default/files; chown -R www-data:www-data html/sites/default/files;
# Push down a copy of drupal
ADD ./files/drupal-7  /tmp/drupal


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


### Custom startup scripts
RUN easy_install supervisor
ADD ./supervisord.conf /etc/supervisord.conf
ADD ./foreground.sh /etc/apache2/foreground.sh
ADD ./ubuntu1404/000-default.conf /etc/apache2/sites-enabled/000-default.conf
ADD ./start.sh /start.sh
ADD ./gitwrap.sh /gitwrap.sh

# Automate starting of mysql+apache, allow bash for debugging
RUN chmod 755 /start.sh /etc/apache2/foreground.sh
EXPOSE 80
CMD ["/bin/bash", "/start.sh"]

