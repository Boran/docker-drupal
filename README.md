docker-drupal
==============

Completely automated Drupal install, with lots of flexibility!

Creates a [Docker](http://docker.io) container for Drupal 7 or 8, using Linux (Ubuntu 14.04), Apache and MySQL:
- Install Ubuntu 14.04/Apache/Php/Mysql with supervisord startup scripts
- Install postfix to allow drupal to deliver emails
- Install composer and drush 
- Use included Drupal7, or download Drupal, pull from git or via drush makefile
- Install drupal+DB via a standard or custom profile
- Optionally run cron, rsyslog and postfix, or add HTTPS, or externalise the DB, or..
- Most drupal install settings are environment settings when creating a container from the image. See below.

# Installation
Well, install docker if you dont have it yet (see the bottom), then just use it.

# Usage

## Create a running container

Simplest form, start a D7 container:
> docker run -td boran/drupal

Start a D8 container:
> docker run -td -e "DRUPAL_VERSION=drupal-8" boran/drupal

Start a D7 container, interactive shell (run /start.sh when you have the shell to start lamp):
> docker run -ti boran/drupal /bin/bash

Name the container (--name drupal8003) and give it a public port (8003).
Then visit http://MYHOST.com:8003/
> docker run -td -p 8003:80 --name drupal8003 boran/drupal

## Troubleshooting 
- Examine log of the container started above (named drupal8003)
  `docker logs -f drupal8003`

- connect a shell to the running container
> sudo docker exec -it drupal8003 bash


- create a nice shell function in /etc/profile.d/nsenter.sh, which allows one to do "nsenter CONTAINER-NAME"
> function nsenter (){ sudo docker exec -it $* bash; }


- Create a new container and only run a shell
  `docker run -ti boran/drupal /bin/bash`

## Creating more complex containers

To run the container with "foo" as the admin password:
> docker run -td -p 8003:80 -e "DRUPAL_ADMIN_PW=foo" -e "DRUPAL_SITE_NAME=My Super site" --name drupal8003 boran/drupal

Drupal 8, set a password and title, mysql DB in on 10.1.1.1 and mount /var/www/html from /opt/foo
> docker run -td -p 8004:80 --name bc -e "DRUPAL_VERSION=drupal-8" -e "DRUPAL_ADMIN_PW=foo" -e "DRUPAL_SITE_NAME=My Super site" -e "MYSQL_HOST=10.1.1.1" -e "MYSQL_DATABASE=drupal_site1" -e "MYSQL_USER=drupal_site1" -e "MYSQL_PASSWORD=pass4drupal_site1" -v /opt/foo:/var/www/html  boran/drupal

Download drupal+website on the develop branch from a https git repo:
> docker run -td -p 8003:80 -e "DRUPAL_GIT_REPO=https://USER:PASSWORD@example.org/path/something" -e "DRUPAL_GIT_BRANCH=devop" --name drupal8003 boran/drupal

To run a custom install profile, set DRUPAL_INSTALL_REPO and DRUPAL_INSTALL_PROFILE accordingly.

Download drupal+modules according to a make file:
> docker run -td -p 8003:80 -e "DRUPAL_MAKE_DIR=drupal-make1" -e "DRUPAL_MAKE_REPO=https://github.com/Boran/drupal-make1" -e "DRUPAL_MAKE_CMD=${DRUPAL_MAKE_DIR}/${DRUPAL_MAKE_DIR}.make ${DRUPAL_DOCROOT}" --name drupal8003 boran/drupal`

## Parameter reference
Environment parameters, defaults are as follows, commented values are not set by default:
```
    DRUPAL_SITE_NAME My Drupal Site
    DRUPAL_SITE_EMAIL drupal@example.ch
    DRUPAL_ADMIN admin
    DRUPAL_ADMIN_PW admin
    DRUPAL_ADMIN_EMAIL root@example.ch

    #DRUPAL_VERSION drupal-7 
      By default a bundled drupal 7 is installed
      drush dl syntax, e.g.  drupal-7, drupal-7.x =dev, drupal-8.0.0-alpha15

    #DRUPAL_GIT_REPO https://USER:PASSWORD@example.org/path/something
    #DRUPAL_GIT_BRANCH master

    #DRUPAL_MAKE_DIR  drupal-make1
    #DRUPAL_MAKE_REPO https://github.com/Boran/drupal-make1
    #DRUPAL_MAKE_BRANCH master
    # Which will run:  drush make ${DRUPAL_MAKE_DIR}/${DRUPAL_MAKE_DIR}.make ${DRUPAL_DOCROOT}
    DRUPAL_INSTALL_PROFILE standard
    Specify the repo and the branch of the install profile:
    # DRUPAL_INSTALL_REPO https://github.com/Boran/drupal-profile1.git
    # DRUPAL_INSTALL_PROFILE_BRANCH master

    # Run a feature revert revert after installing, can be useful for default content
    #ENV DRUPAL_MAKE_FEATURE_REVERT 1

    #If a second user is needed:
    # DRUPAL_USER1 bob
    # DRUPAL_USER1_PW bobspasswd
    # DRUPAL_USER1_EMAIL bob@example.ch
    # DRUPAL_USER1_ROLE manager     (if not specified, default is administrator)

    Optional mysql:
    # MYSQL_HOST is set, mysql will not be installed in the container
    # MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD 

    Optional mysql+drupal
    # DRUPAL_NONE     (if set, mysql/drupal will not be installed)
 
    # Enable verbose debugging of start.sh
    #DRUPAL_DEBUG=true
```
## DRUPAL_FINAL_CMD and DRUPAL_FINAL_SCRIPT
After drupal has been installed one may need to run some commands, e.g. set values via drush. There are two ways do do this.
 * DRUPAL_FINAL_CMD: Run a custom command after the site is installed. Example: get, enable and run the production check module  "ENV DRUPAL_FINAL_CMD drush -y dl prod_check && drush -y en prod_check && drush -y cache-clear drush && drush -y prod-check-prodmode"
 * DRUPAL_FINAL_SCRIPT: Run a script after the site is installed. This script must already be available (i.e. pulled from a repo or make file during installation, or downloaded via a DRUPAL_FINAL_CMD.  Example: 
```
 * DRUPAL_FINAL_CMD=curl --silent -o /tmp/cleanup1.sh https://raw.githubusercontent.com/Boran/webfact-make/master/scripts/cleanup1.sh && chmod 700 /tmp/cleanup1.sh
 * DRUPAL_FINAL_SCRIPT=/tmp/cleanup1.sh
```

## Install Drupal from a git repo with ssh keys
Download drupal+website on the master branch from a git repo via ssh with keys. 
 * In this case an included script DRUPAL_GIT_SSH=/gitwrap.sh is referenced which passes keys to ssh for use in git clone
 * Create ssh keys (id_rsa.pub id_rsa) with ssh-keygen, stored in /root/boran-drupal/ssh
 * Then build the container mounting the SSH keys files under /root/gitwrap/id_rsa /root/gitwrap/id_rsa.pub
 * The example repo is git@bitbucket.org:/MYUSER/MYREPO.git

`docker run -td -p 8003:80 -e "DRUPAL_GIT_SSH=/gitwrap.sh" -e "DRUPAL_GIT_REPO=git@bitbucket.org:/MYUSER/MYREPO.git" -v /root/boran-drupal/ssh/id_rsa:/root/gitwrap/id_rsa -v /root/boran-drupal/ssh/id_rsa.pub:/root/gitwrap/id_rsa.pub -v /root/boran-drupal/ssh/known_hosts/root/gitwrap/known_hosts --name drupal8003 boran/drupal`


# Special cases
## External database: MYSQL_HOST

If MYSQL_HOST is set, mysql will not be installed in the container.
In this case, create the DB first on your server and set the environment variables MYSQL_DATABASE MYSQL_USER DRUPAL_PASSWORD in addition to MYSQL_HOST.


## No website: DRUPAL_NONE

By setting DRUPAL_NONE Its possible to setup a container with all tools and dependancies, but without a Drupal website. The first usee of this was creating a build container for continuous integration (see boran/docker-cibuild on github)


## Postfix: email delivery

Postfix is installed since drupal needs to send emails during certain installation scenarios. If it cannot email, builds will break. The default installation will allow emails to be queued in postfix locally within the container.
To enabled full delivery ouside of the container, add appropriate lines to /custom.sh inside the container e.g. change the relay to a SMTP mailgateway reachable from your network:
```
  echo "custom.sh: setup postfix, puppet. VIRTUAL_HOST=$VIRTUAL_HOST";
  postconf -e "myhostname = `hostname`"
  postconf -e 'mydestination = $VIRTUAL_HOST localhost.localdomain, localhost'
  postconf -e 'relayhost = MYRELAY.EXAMPLE.ch'
```


## HTTPS support: DRUPAL_SSL

By setting DRUPAL_SSL you enable ssl support in Apache. The preinstalled self signed certificate is used /etc/ssl/certs/ssl-cert-snakeoil.pem
To connect to port 443 via https map your port to port 443 (eg docker run -p 8443:443...)

## Enable cron: SUPERVISOR_CRON_ENABLE
By setting SUPERVISOR_CRON_ENABLE=true the cron daemon is started via supervisor.

## Enable syslog: SUPERVISOR_RSYSLOG_ENABLE
By setting SUPERVISOR_RSYSLOG_ENABLE=true the syslog daemon is started via supervisor i.e. to catch and log events sent to syslog within the container.

# Docker notes

## Installing docker 
If you have not yet got docker running, the following is one way to install on Ubuntu 14.04, pulling the latest version and ensuring aufs filesystem:
```
sudo apt-get install linux-image-extra-`uname -r`

sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9

sudo sh -c "echo deb https://get.docker.io/ubuntu docker main\ > /etc/apt/sources.list.d/docker.list"

sudo apt-get update -qq && sudo apt-get -yq install lxc-docker
```
See also [using docker] (https://docs.docker.com/userguide/usingdocker/)


# Development
### Building an image (e.g. inheriting from this one)

Some changes can be made by creating a new image based on boran/drupal
 - download a copy of drupal to a subfolder called drupal
 - Set new defaults for the "DRUPAL*" enviroment variables  
 - Include a custom.sh, which (if it exists) is run just before the end of start.sh.
   this could be used to run for example puppet, or other provisioning tool.

e.g. create a site specific inherited image with additional stuff such as cron, postfix, syslog and puppet. 

### Building an image (e.g. changing this one)
  Grab sources from Github
 - download a copy of drupal to a subfolder called files/drupal-7
```
  cd files
  rm -rf drupal-7  # incase an old version is there
  drush dl drupal 
  mv drupal-7.* drupal-7 
  # or
  wget http://ftp.drupal.org/files/projects/drupal-7.39.tar.gz
  tar xf drupal-7.39.tar.gz 
  mv drupal-7.39 drupal-7
  cd ..
```
 - then rebuild:
```
# Interative: stop/delete/rebuild:
docker stop drupal8003; docker rm drupal8003; 
docker build -t="boran/drupal" .

# Run and look at logs:
docker run -td -p 8003:80 --name drupal8003 boran/drupal
docker logs -f drupal8003
```

# Thanks 
The very first iteration was based on a pattern from https://github.com/ricardoamaro/docker-drupal.git

Sean Boran  https://github.com/Boran/docker-drupal
