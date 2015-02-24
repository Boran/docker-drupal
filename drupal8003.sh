#!/bin/sh
# Example script for testing container variants

name=drupal8003
domain=webfact.example.ch
image=boran/drupal

# Wipe container, recreate with a name and follow logs
docker stop $name; docker rm $name 
# If developing the mother image
docker build -t="$image" .

docker run -d -t -p 8003:80 -v /var -e "VIRTUAL_HOST=$name.$domain" --name $name $image

#docker run -d -t -p 8003:80 -e "DRUPAL_NONE=skip" -e "DRUPAL_INSTALL_PROFILE=standard" -e "VIRTUAL_HOST=$name.$domain" --name $name $image
# -e "DRUPAL_NONE=skip"
# -e "DRUPAL_FINAL_CMD=drush -y dl prod_check && drush -y en prod_check && drush -y cache-clear drush && drush -y prod-check-prodmode"
# -e "VIRTUAL_HOST=$name.$domain"

## DRUPAL_GIT_SSH
#docker run -ti -p 8003:80 -e "DRUPAL_GIT_SSH=/gitwrap.sh" -e "DRUPAL_GIT_REPO=git@bitbucket.org:/innoveto/swisscom-site-factory.git" -v /root/boran-drupal/ssh/id_rsa:/root/gitwrap/id_rsa -v /root/boran-drupal/ssh/id_rsa.pub:/root/gitwrap/id_rsa.pub -v /root/boran-drupal/ssh/known_hosts:/root/gitwrap/known_hosts --restart=always --hostname drupal8003 --name drupal8003 boran/drupal /bin/bash

#DRUPAL_GIT_REPO
#docker run -dt -p 8003:80 -e "VIRTUAL_HOST=drupal8003.$domain" -e "DRUPAL_GIT_REPO=https://bob:bobpasswd@bitbucket.org/some/repo" --restart=always --hostname drupal8003 --name drupal8003 $image

#docker run -td -p 8003:80 -e "DRUPAL_MAKE_DIR=drupal-make1" -e "DRUPAL_MAKE_REPO=https://github.com/Boran/drupal-make1" -e 'DRUPAL_INSTALL_PROFILE=standard' --hostname drupal8003 --name drupal8003 $image

# other options
# --restart=always

docker logs -f $name


