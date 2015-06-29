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

fp=/tmp/.setvol.running
currval=`cat $fp 2> /dev/null`
if [ ! -e "$fp" ] ; then
	cd /usr/local/bin/Chrubix/src
	python3 setvol.py &> /tmp/.setvol.out &
	sleep 1
	if [ "$#" -ne "1" ] ; then
		echo 30 > $fp
	else
		echo $1 > $fp
	fi
fi

vol=`cat $fp`
if [ "$1" = "up" ] ; then
	vol=$(($vol+5))
	[ "$vol" -gt "100" ] && vol=100
elif [ "$1" = "down" ] ; then
	vol=$(($vol-5))
	[ "$vol" -lt "0" ] && vol=0
elif [ "$1" = "mute" ] ; then
	if [ -e "$fp.orig" ] ; then
		mv $fp.orig $fp
		vol=`cat $fp`
	else
		mv $fp $fp.orig
		echo 0 > $fp
	fi
fi

echo $vol > $fp
call_amixer $vol

exit 0
