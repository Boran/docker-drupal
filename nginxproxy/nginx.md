nginx reverse proxy: making containers visible on the network
===================

The basic reverse proxy (jwilder/nginx-proxy container) makes containers available as a dynamic subdomain, e.g. http://SOMETHING.webfact.example.ch 

It maps incoming requests on port 80 to port 80 on the appropriate container which it finds via the VIRTUAL_HOST and VIRTUAL_PORT docker container environment parameters. It automatically detects docker changes (events), no configuration is needed it "just works".

However, in most environments https is needed in addition to http and the default nginx-proxy container insufficient: for example SSL certificates need to be bundled. The service is then divided into two containers.
 - nginx: provides the reverse proxy according to the nginx config.
 - nginx-gen: watch docker for container changes and adapts the nginx if necessary. Include SSL certs.
For templating, see also https://github.com/jwilder/docker-gen http://golang.org/pkg/text/template/ 

