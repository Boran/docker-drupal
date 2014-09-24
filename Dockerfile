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

# Custom startup scripts
RUN easy_install supervisor
ADD ./supervisord.conf /etc/supervisord.conf
ADD ./start.sh /start.sh
ADD ./foreground.sh /etc/apache2/foreground.sh
ADD ./ubuntu1404/000-default.conf /etc/apache2/sites-enabled/000-default.conf


# Retrieve drupal
WORKDIR /var/www/    
RUN mv html html.orig && drush -q dl drupal; mv drupal* html;
RUN chmod 755 html/sites/default; mkdir html/sites/default/files; chown -R www-data:www-data html/sites/default/files;


# Automate starting of mysql+apache, allow bash for debugging
RUN chmod 755 /start.sh /etc/apache2/foreground.sh
EXPOSE 80
CMD ["/bin/bash", "/start.sh"]

