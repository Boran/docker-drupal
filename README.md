docker-drupal
==============

Create a [Docker](http://docker.io) container for Drupal 7, using Linux (Ubuntu 14.04), Apache and MySQL. 

- Create a Ubuntu 14.04/Apache/Mysql stack with startup scripts
- Install drupal+DB is needed
- Most drupal install settings are parameters: drupal users, install profile etc.


The pattern is derived from https://github.com/ricardoamaro/docker-drupal.git

Running: 
Start a container that listens on the public port 8003, give it a name
  docker run -td -p 8003:80 --name drupal8003 boran/drupal
  http://MYHOST.com:8003/

Run and provide alternative parameters:
The available parameters and defaults are:
    DRUPAL_DOCROOT /var/www/html
    DRUPAL_INSTALL_PROFILE standard
    #DRUPAL_INSTALL_REPO https://github.com/Boran/drupal-profile1.git
    DRUPAL_SITE_NAME My Drupal Site
    DRUPAL_SITE_EMAIL drupal@example.ch
    DRUPAL_ADMIN admin
    DRUPAL_ADMIN_PW admin
    DRUPAL_ADMIN_EMAIL root@example.ch
    #If a second admin user is needed:
    # DRUPAL_USER1 admin2
    # DRUPAL_USER1_PW admin2
    # DRUPAL_USER1_EMAIL drupal2@example.ch
To run the container with "foo" as the admin password:
  docker run -td -p 8003:80 -e "DRUPAL_ADMIN_PW=foo" -e "DRUPAL_SITE_NAME=My Super site" --name drupal8003 boran/drupal

Custom install profiles: they are git clopnes from DRUPAL_INSTALL_REPO and named DRUPAL_INSTALL_PROFILE


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


TODO:
- echo final URL to the logs
- onetime login instead of admin user/password


Sean Boran, 24.Sep.2014
