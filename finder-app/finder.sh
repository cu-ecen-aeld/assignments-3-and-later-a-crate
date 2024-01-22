#!/bin/sh
filesdir=$1
if [ -z $filesdir ]; then
  exit 1
fi
searchstr=$2
if [ -z $searchstr ]; then
  exit 1
fi
x=$(find $filesdir -type f | wc -l)
y=$(grep -r $searchstr $filesdir | wc -l)
echo "The number of files are $x and the number of matching lines are $y"
