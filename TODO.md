

Some ideas... no priorites set yet


- add postfix for mail delivery
- echo final URL to the logs
- add proxy support
- onetime login instead of admin user/password: drush uli- some-username
- php-apc, or more likely php5 cache?
- tune apache/php
- harden apache
- check memcache
- add https as an option, with certificates?
- in start.sh
  composer self-update

- Install of Drupal 6 does not (yet) work.
Example
docker run -td -p 8003:80 -e "DRUPAL_VERSION=drupal-6.33" --name drupal8003  boran/drupal

Starting Drupal installation. This takes a few seconds ...           [ok]
Table &#039;drupal.variable&#039; doesn&#039;t exist                 [warning]
query: SELECT value FROM variable WHERE name =
&#039;install_task&#039; database.mysqli.inc:134
Table &#039;drupal.variable&#039; doesn&#039;t exist                 [warning]
query: SELECT value FROM variable WHERE name =
&#039;install_task&#039; database.mysqli.inc:134
The site install task '' failed.                                     [error]
----------------


