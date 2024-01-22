#!/bin/sh
writefile=$1
if [ -z $writefile ]; then
  exit 1
fi
writestr=$2
if [ -z $writestr ]; then
  exit 1
fi
mkdir -p $(dirname $writefile)
echo $writestr > $writefile
