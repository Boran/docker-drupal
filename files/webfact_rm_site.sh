#!/bin/sh
# Webfactory: allow delete of the file tree associated with a site
# Restrict to subfolders of the location of this script
rm -r $(dirname $0)/$1
