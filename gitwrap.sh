#!/bin/sh
# Pass ssh keys to git clone
# e.g.
# GIT_SSH=/gitwrap.sh git clone -b master -q git@bitbucket.org:/MYUSER/MYREPO.git html

ssh -o StrictHostKeyChecking=no -i /root/gitwrap/id_rsa -q $@

