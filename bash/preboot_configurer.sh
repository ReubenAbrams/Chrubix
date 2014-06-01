#!/bin/bash
#
# preboot_configurer.sh
# - the command-line version of greeter.py
#
#################################################################################



failed() {
	echo "$1" >> /dev/stderr
	exit 1
}




chroot_this() {
	[ -d "$1" ] || failed "chroot_this() --- first parameter is not a directory; weird; '$1'"
	local res tmpfile proxy_info
	tmpfile=/tmp/do-me.$RANDOM$RANDOM$RANDOM.sh
	[ "$WGET_PROXY" != "" ] && proxy_info="export http_proxy=$WGET_PROXY" || proxy_info=""
	echo -en "#!/bin/sh\n$proxy_info\n$2\nexit \$?\n" > $1/$tmpfile
	chmod +x $1/$tmpfile
	chroot $1 bash $tmpfile && res=0 || res=1
	rm -f $1/$tmpfile
	return $res
}




yes_or_no() {
	local res
	res="blah"
	while [ "$res" != "Y" ] && [ "$res" != "y" ] && [ "$res" != "N" ] && [ "$res" != "n" ]; do
		echo -en "$1 (Y/N/?) "
		read res
		if [ "$1" == "More options" ] && [ "$res" = "" ] ; then
			res="n"
		fi
		if [ "$res" = "?" ] || [ "$res" = "" ] ; then
			echo -en "$2\n"
		fi
	done
	if [ "$res" = "Y" ] || [ "$res" = "y" ] ;then
		return 0
	else
		return 1
	fi
}






# ---------------------------------------------------------------------------------------------------------

echo "We use GREETER (Python 3) now, instead of preboot_configuere.sh; yay..."
exit 0
ready_to_proceed=no
while [ "$ready_to_proceed" != "yes" ] ; do
	set_root_password=no
	spoof_all_mac_addresses=no
	emulate_xp=no
	direct_connect=no
	clear
	echo -en "Welcome to Alarmist.\n\n\n\n\n"
	if ! yes_or_no "More options" "Alarmist lets you choose to obfuscate your MAC address, camouflage your OS to look like Windows, etc.\n"; then
		ready_to_proceed="yes"
	else
		yes_or_no "Set root password" "\n\nADMINISTRATION PASSWORD\n\nYou have the option of entering an administration password in case you need to perform\nadministrative tasks. If you choose not to, it will be disabled for better security.\n\n" && set_root_password=yes
		yes_or_no "Activate Windows camouflage" "\n\nWINDOWS CAMOUFLAGE\n\nThis option makes Alarmist look more like Microsoft Windows XP. This\nmay be ueful in public places in order to avoid attracting suspicion.\n\n" && emulate_xp=yes
		yes_or_no "Spoof all MAC addresses" "\n\nMAC ADDRESS SPOOFING\n\nSpoofing MAC addresses hides the serial number of your network cards\nto the local network. This can help you hide your geographical location.\n\nIt is generally safer to spoof MAC addresses, but it might\nalso raise suspicions or cause network connection problems.\n\n"  && spoof_all_mac_addresses=yes
		yes_or_no "Direct network connection" "\n\nNETWORK CONFIGURATION\n\nIs your network connection clear of obstacles? If so, and you would like\nto connect directly to the Tor network, say (Y)es. On the other hand, If\nyour computer's network connection is censored, filtered, or proxied, say\n(N)o and configure your bridge, firewall, or proxy settings manually.\n\n" && direct_connect=yes
		yes_or_no "\n\nSet admin passwd   $set_root_passrord\nSpoof MAC address  $spoof_all_mac_addresses\nResemble Win XP    $emulate_xp\nDirect connect     $direct_connect\n\nShall I proceed" "" && ready_to_proceed=yes
	fi
done

if [ "$set_root_password" = "yes" ] ; then
	res=999
	while [ "$res" -ne "0" ] ; do
		echo -en "\nPlease choose a root password.\n"
		chroot_this /newroot "passwd" && res=0 || res=1
	done
else
	chroot /newroot "passwd -l root" || echo "WARNING - failed to deactivate root password" > /dev/stderr
fi

[ -d "/newroot" ] || failed "I cannot write the alarmist.cfg file if /newroot does not exist."

echo "#!/bin/sh
spoof_all_mac_addresses=$spoof_all_mac_addresses
emulate_xp=$emulate_xp
direct_connect=$direct_connect
" > newroot/etc/.alarmist.cfg

if [ "$spoof_all_mac_addresses" != "no" ] ; then
	macchanger -r `ifconfig | grep lan0 | cut -d':' -f1 | head -n1`
fi

if [ "$emulate_xp" != "no" ] ; then
	xfconf-query -c xsettings -p /Net/ThemeName -s "XP Blue"		# Options: XP Blue, XP Silver, or XP Olive
fi

exit 0
