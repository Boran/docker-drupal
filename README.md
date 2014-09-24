docker-drupal
==============

Create a [Docker](http://docker.io) container for Drupal 7, using Linux (Ubuntu 14.04), Apache and MySQL. 

- Create a Ubuntu 14.04/Apache/Mysql stack with startup scripts
- Install drupal+DB is needed
- Most drupal install settings are parameters: drupal users, install profile etc.


The pattern is derived from https://github.com/ricardoamaro/docker-drupal.git

Running: 
Start a container that listen on the public port 8003, give it a name
docker run -td -p 8003:80 --name drupal8003 boran/drupal
  http://MYHOST.com:8003/

Run and provide alternative parameters:
docker run -td -p 8003:80 -e "DRUPAL_INSTALL_PROFILE=standard" --name drupal8003 boran/drupal

Troubleshooting: 
- Examine log of container started above
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


Sean Boran, 24.Sep.2014
