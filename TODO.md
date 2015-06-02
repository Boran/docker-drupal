

Some ideas... no priorites set yet

- check memcache
- nodejs server
- in start.sh
  composer self-update

- Install of Drupal 6 does not (yet) work. See the 6.x branch, Example
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

Derived image for corporate use:
- harden apache
- tune apache/php
