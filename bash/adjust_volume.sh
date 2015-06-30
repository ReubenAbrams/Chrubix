#!/bin/bash
#
# adjust_volume.sh
# - calls volume :)
#
#################################################################################

call_amixer() {
	echo "$1" > /tmp/.volnow
	chmod 777 /tmp/.volnow
	amixer set Speaker "$1"%
	amixer set Headphone "$1"%
}


# ------------------------------------------------------------

volfname=/tmp/.volnow

if [ ! -e "$volfname" ] ; then
	cd /usr/local/bin/Chrubix/src
	python3 setvol.py &> /tmp/.setvol.out &
	sleep 1
	if [ "$#" -ne "1" ] ; then
		echo 30 > $volfname
	else
		echo $1 > $volfname
	fi
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
