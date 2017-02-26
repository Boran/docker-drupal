
Some notes of creating a drupal6 containing, for supporting legacy sites not yet on Drupal7/8


# Built a Ubuntu 12.04 image

mkdir ./files/drupal-7
docker build -t="boran/drupal6" -f Dockerfile.drupal6 .


# Run and look at logs:
```
docker stop drupal8006; docker rm drupal8006;
#docker run -td -p 8006:80 --name drupal8006 boran/drupal6
#docker run -td -p 8006:80 -e "DRUPAL_VERSION=drupal-6.38" -e DRUPAL_DOCROOT=/var/www --name drupal8006 boran/drupal6

# Just dependancies, but no drupal
docker run -td -p 8006:80 -e "DRUPAL_NONE=1" --name drupal8006 boran/drupal6
docker logs -f drupal8006
```


# Installating fails
Installing drupal with the container fails. not yet resolved.
```
Starting Drupal installation. This takes a few seconds ...           [ok]
PHP Fatal error:  Call to undefined function db_result() in /opt/composer/vendor/drush/drush/commands/core/drupal/site_install_6.inc on line 136
Drush command terminated abnormally due to an unrecoverable error.   [error]
Error: Call to undefined function db_result() in
/opt/composer/vendor/drush/drush/commands/core/drupal/site_install_6.inc,
line 136
-- ERROR: drush site-install failed
drush site-install standard -y --account-name=admin --account-pass=admin --account-mail=root@example.ch --site-name=My Drupal Site --site-mail=drupal@example.ch --db-url=mysqli://drupal:HIDDEN@localhost:3306/drupal
```

