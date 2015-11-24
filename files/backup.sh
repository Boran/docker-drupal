#!/bin/sh
#/root/backup.sh 

dest=/data
today=`date +'%Y%m%d'`
thishost=`uname -n`

if [ -f /mysql-root-pw.txt ] ; then 
  pass=`cat /mysql-root-pw.txt`
  nice mysqldump -p$pass --events drupal  >$dest/$thishost.$today.sql

  # delete files over 3 days: we expect to run daily and the
  # docker server to backup /data each day too
  cd $dest
  nice find . -xdev -mtime +3 -type f  -exec rm -f \{\} \;
else
  logger "Mysql backup skipped since no /mysql-root-pw.txt"
fi


# file backup
if [ -d /var/www/html ] ; then 
  cd /var/www/html;
  nice tar czf $dest/html_sites.tgz sites
fi

#1 1    *   *   *  www-data  (cd /var/www/html && drush -p bam-backup | logger);
#1 2    *   *   *  root      (cd /var/lib/drupal-private/backup_migrate && find . -xdev -ctime +30 -type f  -exec rm -f \{\} \;)o
