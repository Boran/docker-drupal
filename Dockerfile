# docker container for Drupal 
# Ubuntu 14.04 +mysql+apache+ tools + drupal
#
# VERSION       1
# DOCKER-VERSION        1
FROM             ubuntu:14.04
MAINTAINER       Sean Boran <sean_at_boran.com>
ENV REFRESHED_AT 2014-09-23

RUN apt-get -qqy update

RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl  

# Todo: php-apc, or php5 cache?
RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install git mysql-client mysql-server apache2 libapache2-mod-php5 pwgen python-setuptools vim-tiny php5-mysql php5-gd php5-curl drush 
RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install php5-memcache memcached mc
RUN DEBIAN_FRONTEND=noninteractive apt-get -q autoclean

# Option: Make mysql listen on the outside, might be useful for backups
# but adds a security risk.
#RUN sed -i "s/^bind-address/#bind-address/" /etc/mysql/my.cnf


# Retrieve drupal
WORKDIR /var/www/    
RUN mv html html.orig && drush -q dl drupal; mv drupal* html;
RUN chmod 755 html/sites/default; mkdir html/sites/default/files; chown -R www-data:www-data html/sites/default/files;

# Custom startup scripts
RUN easy_install supervisor
ADD ./supervisord.conf /etc/supervisord.conf
ADD ./start.sh /start.sh
ADD ./foreground.sh /etc/apache2/foreground.sh
ADD ./ubuntu1404/000-default.conf /etc/apache2/sites-enabled/000-default.conf

# Drupal settings: used by start.sh within the container
# can be overridden at run time e.g. -e "DRUPAL_INSTALL_PROFILE=standard"
ENV DRUPAL_DOCROOT /var/www/html

# Install profile:
ENV DRUPAL_INSTALL_PROFILE standard
#Example custom profile: pull it from git
#ENV DRUPAL_INSTALL_PROFILE boran1
#ENV DRUPAL_INSTALL_REPO https://github.com/Boran/drupal-profile1.git

ENV DRUPAL_SITE_NAME My Drupal Site
ENV DRUPAL_SITE_EMAIL drupal@example.ch
ENV DRUPAL_ADMIN admin
ENV DRUPAL_ADMIN_PW admin
ENV DRUPAL_ADMIN_EMAIL root@example.ch
#Default is no second admin user
#ENV DRUPAL_USER1 admin2
#ENV DRUPAL_USER1_PW admin2
#ENV DRUPAL_USER1_EMAIL drupal@example.ch

# During build test of profiles, copy profile in directly
#ENV DRUPAL_INSTALL_PROFILE boran1
#ADD ./drupal-profile1      /var/www/html/profiles/boran1


# Automate starting of mysql+apache, allow bash for debugging
RUN chmod 755 /start.sh /etc/apache2/foreground.sh
EXPOSE 80
CMD ["/bin/bash", "/start.sh"]

