#!/bin/bash
#
# adjust_volume.sh
# - calls volume :)
#
#################################################################################



volfname=$HOME/.volnow




call_amixer() {
	echo "$1" > $volfname
	chmod 777 $volfname
	amixer set Speaker "$1"%
	amixer set Headphone "$1"%
}


# ------------------------------------------------------------


if [ ! -e "$volfname" ] ; then
	if [ "$#" -ne "1" ] ; then
		echo 30 > $volfname
	else
		echo $1 > $volfname
	fi
fi

if ! ps wax | fgrep setvol.py | fgrep -v grep ; then
	cd /usr/local/bin/Chrubix/src
	python3 setvol.py &> /tmp/.setvol.out &
	sleep 3
	cd /
	exit 0
fi

vol=`cat $volfname`
if [ "$1" = "up" ] ; then
	vol=$(($vol+10))
	[ "$vol" -gt "100" ] && vol=100
elif [ "$1" = "down" ] ; then
	vol=$(($vol-10))
	[ "$vol" -lt "0" ] && vol=0
elif [ "$1" = "mute" ] ; then
	if [ -e "$volfname.orig" ] ; then
		mv $volfname.orig $volfname
		vol=`cat $volfname`
	else
		mv $volfname $volfname.orig
		echo 0 > $volfname
	fi
fi

echo $vol > $volfname
call_amixer $vol

exit 0
