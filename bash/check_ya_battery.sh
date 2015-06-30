#!/bin/bash
#
# check_ya_battery.sh
# - runs in background; monitors battery; tells the user about its status
#
#################################################################################



get_field() {
	upower -i $1 | grep -i "$2" | head -n1 | cut -d':' -f2 | tr -s ' ' ' ' | cut -d' ' -f2-5
}


# ------------------------------------------------------------


battery_device=`upower -e | grep battery | head -n1`
charger_device=`upower -e | grep charger | head -n1`

last_message=""
last_pc="999"
while [ "black" != "white" ] ; do
	sleep 1
	upower -i $charger_device | grep "online.*yes" &> /dev/null && charging="yes" || charging="no"
	if upower -i $battery_device | fgrep "fully-charged" ; then
		status="fully charged"
		percentage=""
		time_remaining=""
		pc=101
	else
		if [ "$charging" = "yes" ] ; then
			status="charging"
			pc=`get_field $battery_device "percent" | sed s/\%//`
			time_remaining="Time until full: `get_field $battery_device "time"`"
			percentage=" Battery @ $pc%."
		else
			pc=`get_field $battery_device "percent" | sed s/\%//`
			percentage=" Battery @ $pc%."
			status="Time remaining: `get_field $battery_device "time"`"
		fi
	fi
	message="Laptop $status.$percentage $time_remaining"
	if [ "$last_message" != "$message" ] ; then
		echo "$message" > /tmp/.battstat
		if [ "$(($pc/5))" != "$(($last_pc/5))" ] || [ "$pc" -le "8" ] || [ "$pc" == "100" ] || [ "$pc" == "99" ] ; then
			notify-send "Battery $status" "$message"
		fi
		last_message="$message"
		last_pc=$pc
	fi
done
exit 0
