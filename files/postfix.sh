#!/usr/bin/env bash
#
# This file is managed by Puppet
#
# postfix.sh, version 0.1.0
#
# You cannot start postfix in some foreground mode and
# it's more or less important that docker doesn't kill
# postfix and its chilren if you stop the container.
#
# Use this script with supervisord and it will take
# care about starting and stopping postfix correctly.
#
# supervisord config snippet for postfix:
#
# [program:postfix]
# command=/opt/postfix.sh
# autostart=true
# autorestart=true
#

trap "postfix stop"   SIGINT
trap "postfix stop"   SIGTERM
trap "postfix reload" SIGHUP

# force new copy of hosts there (otherwise links could be outdated)
cp /etc/hosts /var/spool/postfix/etc/hosts

# start postfix
postfix start

# lets give postfix some time to start
sleep 3

# wait until postfix is dead (triggered by trap)
while kill -0 "`cat /var/spool/postfix/pid/master.pid`"; do
  sleep 5
done

