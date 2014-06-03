#!/bin/bash
#
# chrubix_stage1.sh
#
# - lets the user choose the Linux distro they want
# - partitions the SD card
# - formats it
# - mounts boot, root, and kernel (u-boot) partitions
# - installs the Alarpy.tar.xz filesystem
# - enters it
# - calls chrubix.sh, which calls chrubix.py -D<distro>
# - unmounts everything
# - reboots :-)
#
# To run me, type:-
# # cd && rm -f that && wget bit.do/that && sudo bash that
###################################################################################




ALARPY_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/alarpy.tar.xz"
FINALS_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/finals"
CHRUBIX_URL=https://github.com/ReubenAbrams/Chrubix/archive/master.tar.gz
OVERLAY_URL=https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz


if ping -W2 -c1 192.168.1.66 &>/dev/null ; then
	WGET_PROXY="http://192.168.1.66:8080"
else
	WGET_PROXY=""
fi
[ "$WGET_PROXY" != "" ] && export http_proxy=$WGET_PROXY





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




deduce_dev_name() {
	echo "/dev/`ls -l $1 | tr '/' '\n' | tail -n1`"
}



deduce_dev_stamen() {
	if echo "$1" | grep "mmcblk" &> /dev/null ; then
		echo "$1"p
	elif echo "$1" | fgrep "by-id" &> /dev/null ; then
		echo $1"-part"
	elif echo "$1" | grep "/dev/" &> /dev/null ; then
		echo $1
	else
		echo "$1 is missing"
		exit 1
	fi
}




unmount_everything() {
	local r
	echo -en "Unmounting everything..."
	for r in 1 2 3 ; do
		sync;sync;sync; sleep 1
		umount $1/tmp $1/proc $1/sys $1/dev &> /dev/null || echo -en ""
		umount "$4"* &> /dev/null || echo -en ""
	done
	sync;sync;sync
}



find_boot_drive() {
	local partial mpt
	mpt=`mount | grep " / " | cut -d' ' -f1`
	partial=`echo "$mpt" | sed s/p[0-9][0-9]// | sed s/p[0-9]//`
	if echo "$partial" | grep mmcblk &> /dev/null ; then
		echo $partial
	else
		echo $partial | tr '[0-9]' '\n' | head -n1
	fi
}


deduce_homedrive() {
	homedev=`mount | grep " / " | cut -d' ' -f1`
	ls -l /dev/disk/by-id/* | grep "`basename $homedev`" | tr ' ' '\n' | grep /dev/disk/by-id | sed s/\-part[0-9]*//
}



deduce_my_dev() {
	local mydevbyid mydevsbyid_a mydevsbyid_b possibles d dev mountdev
	mydevsbyid_a=`find /dev/disk/by-id/usb-* 2> /dev/null | grep -vx ".*part[0-9].*"`
	mydevsbyid_b=`find /dev/disk/by-id/mmc-* 2> /dev/null | grep -vx ".*part[0-9].*"`
	homedev=`deduce_homedrive`
	[ "$homedev" = "" ] && homedev=/dev/mmcblk0
	possibles=""
	for d in $mydevsbyid_a $mydevsbyid_b ; do
		if [ "`ls -l $d | grep mmcblk0`" = "" ] && [ ! "`ls -l $d | grep $homedev`" ]; then
#if ! ls /tmp/_root.`ls -l $d | tr '/' '\n' | tail -n1` &> /dev/null ; then
				possibles="$possibles $d"
#			fi
		fi
	done
	mydevbyid=`echo "$possibles" | tr ' ' '\n' | tail -n1`
	dev=`deduce_dev_name $mydevbyid`
	if [ "$dev" = "$mountdev" ] ; then
		mydevbyid=`echo "$possibles" | tr ' ' '\n' | grep -vx "$dev" | tail -n1`
	fi
	echo $mydevbyid
}



partition_device() {
	local dev dev_p
	dev=$1
	dev_p=$2

	clear
	echo -en "Partitioning "$dev"."
	sync;sync;sync; umount $root/{dev/pts,dev,proc,sys,tmp} &> /dev/null || echo -en "."
	sync;sync;sync; umount "$dev_p"* &> /dev/null || echo -en "."
	sync;sync;sync; umount "$dev"* &> /dev/null || echo -en "."
	parted -s $dev mklabel gpt
	cgpt create -z $dev
	cgpt create $dev
	cgpt add -i  1 -t kernel -b  8192 -s 32768 -l U-Boot -S 1 -T 5 -P 10 $dev
	cgpt add -i 12 -t data   -b 40960 -s 32768 -l Script $dev
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	lastblock=$(($lastblock-19999))	# FIXME Why do I do this?
	splitpoint=$(($lastblock/2))

	cgpt add -i  2 -t data   -b 73728 -s `expr $splitpoint - 73728` -l Kernel $dev
	cgpt add -i  3 -t data   -b $splitpoint -s `expr $lastblock - $splitpoint` -l Root $dev
	partprobe $dev
}



format_partitions() {
	local dev dev_p temptxt
	dev=$1
	dev_p=$2
	temptxt=/tmp/$RANDOM$RANDOM$RANDOM
	old_pid_list=`ps -o pid -C chrome`
	echo -en "Formatting partitions"
	echo -en "."
	yes | mkfs.ext2 "$dev_p"2 &> $temptxt || failed "Failed to format p2 - `cat $temptxt`"
	echo -en "."
	sleep 1; umount "$dev_p"* &> /dev/null || echo -en ""
	yes | mkfs.ext4 -v "$dev_p"3 &> $temptxt || failed "Failed to format p3 - `cat $temptxt`"
	echo -en "."
	sleep 1; umount "$dev_p"* &> /dev/null || echo -en ""
	mkfs.vfat -F 16 "$dev_p"12 &> $temptxt || failed "Failed to format p12 - `cat $temptxt`"
	sleep 1; umount "$dev_p"* &> /dev/null || echo -en ""
	sleep 1
	new_pid_list=`ps -o pid -C chrome`
#	standouts=`echo "$old_pid_list $new_pid_list" | tr -s ' ' '\n' | sort | uniq -u`
	standouts=`ps wax | fgrep "chrome --type=" | grep -v grep | tail -n2 | cut -d' ' -f1,2 | tr ' ' '\n' | grep -x "[0-9].*"`
#	for pid in $standouts ; do
#		kill $pid && echo -en "" || echo -en ""
#	done
}



install_chrubix() {
	local root dev rootdev sparedev kerndev distro proxy_string
	root=$1
	dev=$2
	rootdev=$3
	sparedev=$4
	kerndev=$5
	distroname=$6

	[ "$WGET_PROXY" != "" ] && proxy_info="export http_proxy=$WGET_PROXY; export ftp_proxy=$WGET_PROXY" || proxy_info=""
	rm -Rf $root/usr/local/bin/Chrubix $rot/usr/local/bin/1hq8O7s
	wget $CHRUBIX_URL -O - | tar -zx -C $root/usr/local/bin
	mv $root/usr/local/bin/Chrubix* $root/usr/local/bin/Chrubix	# rename Chrubix-master (or whatever) to Chrubix
	wget $OVERLAY_URL -O - | tar -Jx -C $root/usr/local/bin/Chrubix || failed "Sorry. Dropbox is down. We'll have to rely on GitHub..."
	for f in chrubix.sh greeter.sh CHRUBIX redo_mbr.sh modify_sources.sh ; do
		ln -sf Chrubix/bash/$f $root/usr/local/bin/$f
	done

	cd $root/usr/local/bin/Chrubix/bash
	cat chrubix.sh.orig \
| sed s/\$dev/\\\/dev\\\/`basename $dev`/ \
| sed s/\$rootdev/\\\/dev\\\/`basename $rootdev`/ \
| sed s/\$sparedev/\\\/dev\\\/`basename $sparedev`/ \
| sed s/\$kerndev/\\\/dev\\\/`basename $kerndev`/ \
| sed s/\$distroname/$distroname/ \
> chrubix.sh
	cd /

}


restore_from_backup() {
	local distroname device root
	distroname=$1
	device=/dev/$2
	root=$3
	echo "Restoring $distroname (stage D) from $device"
		pv /tmp/a/"$distroname"__D.xz | tar -Jx -C $root
	echo "Restored ($distroname, stage D) from $device"
	rm -Rf $root/usr/local/bin/Chrubix
}


hack_something_together() {
	local distroname device root dev_p
	distroname=$1
	root=$2
	dev_p=$3
	echo "9999" > $root/.checkpoint.txt
	umount /tmp/a
	bootstraploc=$root/.bootstrap
	if [ -e "$bootstraploc" ] ; then
		mv $bootstraploc $bootstraploc.old
	fi
}



##################################################################################################################################




echo "Chrubix ------ starting now"
set -e

mount | grep /dev/mapper/encstateful &> /dev/null || failed "Run under ChromeOS, please."
mydevbyid=`deduce_my_dev`
[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
[ -e "$mydevbyid" ] || failed "Please insert a thumb drive or SD card and try again. Please DO NOT INSERT your keychain thumb drive."
dev=`deduce_dev_name $mydevbyid`
dev_p=`deduce_dev_stamen $dev`
petname=`find_boot_drive | cut -d'-' -f3 | tr '_' '\n' | tail -n1 | awk '{print substr($0,length($0)-7);}' | tr '[:upper:]' '[:lower:]'`
fstab_opts="defaults,noatime,nodiratime" #commit=100
mount_opts="-o $fstab_opts"
format_opts="-v"
fstype=ext4
root=/tmp/_root.`basename $dev`		# Don't monkey with this...
boot=/tmp/_boot.`basename $dev`		# ...or this...
kern=/tmp/_kern.`basename $dev`		# ...or this!


lockfile=/tmp/.chrubix.distro.`basename $dev`
if [ -e "$lockfile" ] ; then
	distroname=`cat $lockfile`
else
	url=""
	while [ "$distroname" = "" ] ; do
		clear
		echo -en "Welcome to the Chrubix installer. Which Linux distro shall I install on $dev?

Choose from...
(A)rchLinux
(J)essie [Debian]
(F)edora
(K)ali
(S)uSE 12.3
Alarmis(t), a derivative of Tails
(U)buntu Pangolin
(W)heezy [Debian]

Which would you like me to install? "
		read r
		case $r in
"A") distroname="archlinux";;
"F") distroname="fedora";;
"J") distroname="jessie";;
"K") distroname="kali";;
"S") distroname="suse";;
"T") distroname="alarmist";;
"U") distroname="ubuntu";;
"W") distroname="wheezy";;
*)   echo "Unknown distro";;
		esac
	done
	url=$FINALS_URL/$distroname"__D.tar.xz"
	echo $distroname > $lockfile
fi

btstrap=$root/.bootstrap
installer_fname=/tmp/$RANDOM$RANDOM$RANDOM	# Script to install tarball and/or OS... *and* mount dev, sys, tmp, etc.
if mount | grep "$dev" | grep "$root" &> /dev/null ; then
	echo "Already partitioned and mounted. Reboot and try again..."
fi
sudo stop powerd || echo -en ""
partition_device $dev $dev_p
format_partitions $dev $dev_p
mkdir -p $root
mount $mount_opts "$dev_p"3  $root
rm -Rf $btstrap
mkdir -p $btstrap
mkdir -p /tmp/a
res=0
mkdir -p $btstrap/{dev,proc,tmp,sys}
mkdir -p $root/{dev,proc,tmp,sys}
if mount /dev/sda4 /tmp/a && [ -e "/tmp/a/"$distroname"__D.xz" ]; then
	restore_from_backup $distroname sda4 $root
	hack_something_together $distroname $root $dev_p
	btstrap=$root
elif mount /dev/sdb4 /tmp/a && [ -e "/tmp/a/"$distroname"__D.xz" ] ; then
	restore_from_backup $distroname sdb4 $root
	hack_something_together $distroname $root $dev_p
	btstrap=$root
elif wget $url -O - | tar -Jx -C $root ; then
	echo "Restored ($distroname, stage D) from Dropbox"
	hack_something_together $distroname $root $dev_p
	btstrap=$root
else
	echo "OK. There was no Stage D available on a thumb drive or online."
	clear
	echo "Installing bootstrap filesystem..."
	if [ -e "/home/chronos/user/Downloads/alarpy.tar.xz" ] ; then
		tar -Jxf /home/chronos/user/Downloads/alarpy.tar.xz -C $btstrap || failed "Failed to install alarpy.tar.xz"
	else
		wget $ALARPY_URL -O - | tar -Jx -C $btstrap || failed "Failed to download/install alarpy.tar.xz"
	fi
	echo ""
	echo "en_US.UTF-8 UTF-8" >> $btstrap/etc/locale.gen
	chroot_this $btstrap "locale-gen"
	echo "LANG=\"en_US.UTF-8\"" >> $btstrap/etc/locale.conf
	mkdir -p $btstrap
	echo "nameserver 8.8.8.8" >> $btstrap/etc/resolv.conf
fi

mount devtmpfs  $btstrap/dev -t devtmpfs|| echo -en ""
mount sysfs     $btstrap/sys -t sysfs		|| echo -en ""
mount proc      $btstrap/proc -t proc		|| echo -en ""
mount tmpfs     $btstrap/tmp -t tmpfs		|| echo -en ""

if ! mount | fgrep $btstrap/tmp/_root ; then
	mkdir -p $btstrap/tmp/_root
	mount "$dev_p"3 $btstrap/tmp/_root
	mount devtmpfs $btstrap/tmp/_root/dev -t devtmpfs
	mount tmpfs $btstrap/tmp/_root/tmp -t tmpfs
	mount proc $btstrap/tmp/_root/proc -t proc
	mount sys $btstrap/tmp/_root/sys -t sysfs
fi
install_chrubix $btstrap $dev "$dev_p"3 "$dev_p"2 "$dev_p"1 $distroname


echo "************ Calling CHRUBIX, the Python powerhouse of pulchritudinous perfection ************"

tar -cz /usr/share/vboot /usr/bin/vbutil* /usr/bin/old_bins /usr/bin/futility > $btstrap/tmp/.vbkeys.tgz 2>/dev/null #### MAKE SURE CHRUBIX HAS ACCESS TO Y-O-U-R KEYS and YOUR vbutil* binaries ####
tar -cz /usr/lib/xorg/modules/drivers/armsoc_drv.so \
		/usr/lib/xorg/modules/input/cmt_drv.so /usr/lib/libgestures.so.0 \
		/usr/lib/libevdev* \
		/usr/lib/libbase*.so \
		/usr/lib/libmali.so* \
		/usr/lib/libEGL.so* \
		/usr/lib/libGLESv2.so* > $btstrap/tmp/.hipxorg.tgz 2>/dev/null

chmod +x $btstrap/usr/local/bin/*
chroot_this     $btstrap "/usr/local/bin/chrubix.sh" && res=0 || res=$?
[ "$res" -ne "0" ] && failed "Because chrubix reported an error, I'm aborting... and I'm leaving everything mounted."

sync; umount $btstrap/tmp/_root/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
sync; umount $btstrap/tmp/_root/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
sync; umount $btstrap/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
sync; umount $btstrap/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
unmount_everything       $root $boot $kern $dev_p

if [ "$res" -eq "0" ] ; then
	sudo start powerd || echo -en ""
	echo -en "$distroname has been installed on $dev\nPress ENTER to reboot, or wait 60 seconds..."
	read -t 60 line || reboot
	reboot
else
	echo -en "\n\n\n\n\n\n\nDone, although errors occurred..."
fi
exit $res
