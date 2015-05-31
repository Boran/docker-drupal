#!/bin/sh
# nginxproxy.sh
#
# Create the two reverse proxy containers for the Webfactory.

# New reverse proxy: 
# listen on 443 too
# - forward 80 to 80 on backend
# - forward 443 to 443 on backend
# - look for specific wildcard for webcat.[domain1|domain2]
# See also /opt/sites/nginx-templates/nginx.tmpl and /opt/sites/nginx/default.conf
#

# must be run from the directory where this script is
# todo: check for directories and exit


## A) single-container without SSL:
#docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock --restart=always --hostname nginxproxy --name nginxproxy jwilder/nginx-proxy
#docker start nginxproxy; 
#docker logs nginxproxy


## B) 2 containers: nginx and nginx-gen
## The following is extracted from a working systems, you'll have to interpret and build
## your own alternative, you cannot just copy and paste below.
# settings
workdir=/root
templates=$workdir/webfactnginx/nginx-templates
template=$templates/nginx.tmpl
sslkeys=$workdir/webfactnginx/sslkeys

docker stop nginx 2>/dev/null
docker rm nginx 2>/dev/null
mkdir -p /opt/sites/nginx $sslkeys 2>/dev/null
docker run -dt -p 80:80 -p 443:443 --restart=always \
  --hostname nginx --name nginx                     \
  -v /opt/sites/nginx:/etc/nginx/conf.d             \
  -v $sslkeys:/etc/nginx/certs                      \
  nginx

docker stop nginx-gen 2>/dev/null
docker rm nginx-gen 2>/dev/null
docker run -td --volumes-from nginx --restart=always \
  -v /var/run/docker.sock:/tmp/docker.sock           \
  -v $templates:/etc/docker-gen/templates            \
  -v $sslkeys:/etc/nginx/certs                       \
  --name nginx-gen jwilder/docker-gen                \
    -notify-sighup nginx                             \
    -watch /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf

docker logs nginx-gen

