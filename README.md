docker-drupal
==============

Completely automated Drupal install, with lots of flexibility!

Create a [Docker](http://docker.io) container for Drupal 7, using Linux (Ubuntu 14.04), Apache and MySQL. 
- Create a Ubuntu 14.04/Apache/Mysql stack with startup scripts
- Download Vanilla Drupal or via drush makefile
- Install drupal+DB  via a standard or custom profile
- Most drupal install settings are parameters that can be setting when createing a container from the image. See below.


Running: 
Start a container that listens on the public port 8003, give it a name
  docker run -td -p 8003:80 --name drupal8003 boran/drupal
  http://MYHOST.com:8003/

Run with provide alternative parameters. The defaults are
 s follows, commented vales are not set by default:
    DRUPAL_DOCROOT /var/www/html
    DRUPAL_SITE_NAME My Drupal Site
    DRUPAL_SITE_EMAIL drupal@example.ch
    DRUPAL_ADMIN admin
    DRUPAL_ADMIN_PW admin
    DRUPAL_ADMIN_EMAIL root@example.ch

    #DRUPAL_MAKE_DIR  drupal-make1
    #DRUPAL_MAKE_REPO https://github.com/Boran/drupal-make1
    #DRUPAL_MAKE_CMD  drush make ${DRUPAL_MAKE_DIR}/${DRUPAL_MAKE_DIR}.make ${DRUPAL_DOCROOT}
    DRUPAL_INSTALL_PROFILE standard
    #DRUPAL_INSTALL_REPO https://github.com/Boran/drupal-profile1.git

    #If a second admin user is needed:
    # DRUPAL_USER1 admin2
    # DRUPAL_USER1_PW admin2
    # DRUPAL_USER1_EMAIL drupal2@example.ch

To run the container with "foo" as the admin password:
  docker run -td -p 8003:80 -e "DRUPAL_ADMIN_PW=foo" -e "DRUPAL_SITE_NAME=My Super site" --name drupal8003 boran/drupal

To download drupal+modules according to a make file:
  docker run -td -p 8003:80 -e "DRUPAL_MAKE_DIR=drupal-make1" -e "DRUPAL_MAKE_REPO=https://github.com/Boran/drupal-make1" -e "DRUPAL_MAKE_CMD=${DRUPAL_MAKE_DIR}/${DRUPAL_MAKE_DIR}.make ${DRUPAL_DOCROOT}" --name drupal8003 boran/drupal

To run a custom install profile, set DRUPAL_INSTALL_REPO and DRUPAL_INSTALL_PROFILE accordingle


Troubleshooting: 
- Examine log of container started above (named drupal8003)
  docker logs -f drupal8003

- connect shell to the running container using 'nsenter':
  sudo docker run -v /usr/local/bin:/target jpetazzo/nsenter
    PID=$(sudo docker inspect --format {{.State.Pid}} drupal8003)
    sudo nsenter --target $PID --mount --uts --ipc --net --pid

- Run a shell only for a new container
  docker run -ti boran/drupal /bin/bash


Building:
  Grab sources from Github
  docker build -t="boran/drupal" .
  # Interative: stop/delete/rebuild:
  docker stop drupal8003 && docker rm drupal8003 && docker build -t="boran/drupal" .

  # Run and look at logs:
  docker run -td -p 8003:80 --name drupal8003 boran/drupal
  docker logs -f drupal8003


Thanks: The very first interation was based on a pattern from https://github.com/ricardoamaro/docker-drupal.git

Sean Boran, 25.Sep.2014  https://github.com/Boran/docker-drupal
