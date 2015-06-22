#!/bin/bash
#
# adjust_brightness.sh
# - calls chrubix.sh w/ ersatz_lxdm as param #1
#
#################################################################################

fp=~/.brightness.path
mypath=`cat $fp 2> /dev/null`
if [ ! -e "$mypath" ] ; then
	mp=`find /sys -name brightness -type f | head -n1`
	mypath=`dirname $mp`
	echo "$mypath" > $fp
fi

currval=`cat $mypath/brightness`
if [ "$1" = "up" ] && [ "$currval" -lt "`cat $mypath/max_brightness`" ] ; then
	currval=$(($currval+100))
elif [ "$1" = "down" ] && [ "$currval" -gt "0" ] ; then
	currval=$(($currval-100))
fi

echo "$currval" > $mypath/brightness
exit 0
