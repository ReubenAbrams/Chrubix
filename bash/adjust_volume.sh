#!/bin/bash
#
# adjust_volume.sh
# - calls volume :)
#
#################################################################################

call_amixer() {
	amixer set Speaker $1
	amixer set Headphone $1
}


# ------------------------------------------------------------

fp=~/tmp/.setvol.running
currval=`cat $fp 2> /dev/null`
if [ ! -e "$fp" ] ; then
	cd /usr/local/bin/Chrubix/src
	python3 setvol.py &> /tmp/.setvol.out &
	sleep 5
	echo 20 > $fp
fi

if [ "$#" -ne "1" ] ; then
	vol=`cat $fp`
	if [ "$1" = "up" ] ; then
		vol=$(($vol+8))
	elif [ "$1" = "down" ] ; then
		vol=$(($vol-8))
	fi
fi

echo $vol > $fp
call_amixer "$vol"%

exit 0
