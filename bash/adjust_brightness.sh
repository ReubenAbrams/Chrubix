#!/bin/bash
#
# adjust_brightness.sh
# - adjusts brightness :)
#
#################################################################################


fp=~/.brightness.path
mypath=`cat $fp 2> /dev/null`
if [ ! -e "$fp" ] ; then
	sleep 0.5
fi

my_brightness_fname=~/.brightnow
if [ ! -e "$my_brightness_fname" ] ; then
	mp=`find /sys -name brightness -type f | head -n1`
	mypath=`dirname $mp`
	echo "$mypath" > $fp
#	echo 200 > $my_brightness_fname
fi

if ! ps wax | fgrep setbright | fgrep -v grep ; then
	cd /usr/local/bin/Chrubix/src
	python3 setbright.py &> /tmp/.setbright.out &
	sleep 1
	exit 0
fi

currval=`cat $mypath/brightness`

if [ "$1" = "up" ] && [ "$currval" -lt "`cat $mypath/max_brightness`" ] ; then
	if [ "$2" != "" ] ; then
		currval=$(($currval+$2))
	else
		currval=$(($currval+100))
	fi
elif [ "$1" = "down" ] && [ "$currval" -gt "0" ] ; then
	currval=$(($currval-100))
elif [ "$1" != "" ] ; then
	currval=$1
fi


echo $(($(($currval*100))/`cat $mypath/max_brightness`)) > $my_brightness_fname
echo $currval > $mypath/brightness
exit 0
