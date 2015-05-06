#!/bin/sh
cd /var/www/html/sites/default
drush status|grep 'Drupal version'|awk '{print $1 $4}'
