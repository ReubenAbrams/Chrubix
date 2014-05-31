# stage1.sh
# - create semi-useful Linux distro on thumb drive or SD card from within ChromeOS
#
# Do not run me directly. To run my parent, type:-
# wget bit.ly/1hdWfk6 | bash
##########################################################################


DISTRO=ArchLinux
#DISTRO=`cat /tmp/.chrubix_distro`
SPLITPOINT=4999999
root=/tmp/_chrubix_root
boot=/tmp/_chrubix_boot
kern=/tmp/_chrubix_kern



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
	chroot $1 $tmpfile && res=0 || res=$?
	rm $1/$tmpfile
	return $res
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
		[ "`ls -l $d | grep mmcblk0`" = "" ] && [ ! "`ls -l $d | grep $homedev`" ] && possibles="$possibles $d"
	done
	mydevbyid=`echo "$possibles" | tr ' ' '\n' | tail -n1`
	dev=`deduce_dev_name $mydevbyid`
	[ "$dev" = "$mountdev" ] && mydevbyid=`echo "$possibles" | tr ' ' '\n' | grep -vx "$dev" | tail -n1`
	echo $mydevbyid
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


partition_device() {
	local dev dev_p
	dev=$1
	dev_p=$2
	echo -en "Partitioning "$dev"..."
	parted -s $dev mklabel gpt
	cgpt create -z $dev
	cgpt create $dev
	cgpt add -i  1 -t kernel -b  8192 -s 32768 -l U-Boot -S 1 -T 5 -P 10 $dev
	cgpt add -i 12 -t data   -b 40960 -s 32768 -l Script $dev
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	cgpt add -i  3 -t data   -b 73728 -s `expr $SPLITPOINT - 73728` -l Kernel $dev
	cgpt add -i  2 -t data   -b $SPLITPOINT -s `expr $lastblock - $SPLITPOINT` -l Root $dev
	partprobe $dev
}


format_and_mount_partitions() {
	local dev dev_p temptxt
	dev=$1
	dev_p=$2
	temptxt=/tmp/$RANDOM$RANDOM$RANDOM
	echo -en "Formatting partitions..."
	yes | mkfs.ext4 "$dev_p"2 &> $temptxt			&& echo -en "..." || failed "`cat $temptxt` - failed to format p2"
	yes | mkfs.ext4 "$dev_p"3 &> $temptxt			&& echo -en "..." || failed "`cat $temptxt` - failed to format p3"
	mkfs.vfat -F 16 "$dev_p"12 &> $temptxt			&& echo -en "..." || failed "`cat $temptxt` - failed to format p12"
	mkdir -p $root; mount -o defaults,noatime,nodiratime "$dev_p"3  $root
	mkdir -p $boot; mount								 "$dev_p"12 $boot
	mkdir -p $kern; mount								 "$dev_p"2  $kern
}


reconfigure_firmware() {
	local tmpfile
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	echo -en "Reconfiguring firmware"
	chromeos-firmwareupdate --mode=todev	&> $tmpfile && echo -en "..." || failed "`cat $tmpfile` -- failed to reconfigure firmware"
	crossystem dev_boot_usb=1				&> $tmpfile && echo -en "..." || failed "`cat $tmpfile` -- failed to run crossystem"
}


install_the_necessaries() {
	local dev dev_p root boot kern tarloc tmpfile
	dev=$1
	dev_p=$2
	root=$3
	boot=$4
	kern=$5
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	echo "Working..."
	wget bit.ly/Qwl00W -O - | tar -Jx -C $root || failed "Failed to download/install alarm rootfs"
	mkdir -p $boot/u-boot
	cp $root/boot/boot.scr.uimg $boot/u-boot
	cp $root/boot/vmlinux.uimg $kern
	chroot_this $root "locale-gen" &> /dev/null || echo "Warning - failed to generate locale(s)"

	echo -en "Installing kernel..."
	echo "console=tty1 root="$dev_p"3 rootwait rw loglevel=3 lsm.module_locking=0 init=/sbin/init" > $root/root/.kernel.flags
	vbutil_kernel --pack $root/root/.vmlinuz.signed --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config $root/root/.kernel.flags --vmlinuz $root/boot/vmlinux.uimg --arch arm &> /dev/null && echo -en "..." || failed "Failed to sign kernel"
	dd if=$root/root/.vmlinuz.signed of="$dev_p"1 &> /dev/null || failed "Failed to write kernel to boot device"
	echo "Done. Installing additional tools..."
	mount devtmpfs $root/dev  -t devtmpfs	|| echo -en ")))"
	mount devpts   $root/dev/pts -t devpts  || echo -en "***"
	mount proc     $root/proc -t proc		|| echo -en "%%%"
	mount sys      $root/sys  -t sysfs		|| echo -en "^^^"
	mount tmp      $root/tmp  -t tmpfs		|| echo -en "((("
	mv $root/etc/pacman.d/mirrorlist $root/etc/pacman.d/mirrorlist.orig
	cat $root/etc/pacman.d/mirrorlist.orig | sed s/#.*Server\ =/Server\ =/ > $root/etc/pacman.d/mirrorlist
	echo -en "search localhost\nnameserver 8.8.8.8\n" >> $root/etc/resolv.conf
	chroot_this $root "pacman -Sy && yes \"\" || pacman -S python3" || failed "`cat $tmpfile` -- Failed to update pacman database."
	chroot_this $root "yes \"\" | pacman -S python3" || failed "`cat $tmpfile` -- Failed to install Python"
}


call_stage_two() {
	echo "Calling Python stage"
echo "NEFARIOUS PORPOISES"
exit 0

	wget --quiet bit.ly/PrjcVL -O - > $root/root/.stage2.py
	chroot_this $root "python3 /root/.stage2.py" && echo "Python stage succeeded" || failed "Python stage failed"
	sync;sync;sync;sleep 1;sync;sync;sync
}


# ------------------------------------------------------------------


#dev=/dev/mmcblk1
#dev_p=/dev/mmcblk1p
#set -e
#call_stage_two
#exit $?


rm -f chrubix
umount $root/{dev,proc,sys,tmp} &> /dev/null
umount $root $boot $kern &> /dev/null
set -e
mydevbyid=`deduce_my_dev`
[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
[ -e "$mydevbyid" ] || failed "Unable to validate your MMC/SD card device."
dev=`deduce_dev_name $mydevbyid`
dev_p=`deduce_dev_stamen $dev`
orig_dev=$mydevbyid
umount "$dev_p"* &> /dev/null || echo -en ""
mount | grep "$dev" &> /dev/null && failed "$dev is already mounted. That's bad!"
mount | grep /dev/mapper/encstateful &> /dev/null || failed "Run me from within ChromeOS, please."
ifconfig | grep mlan0 &> /dev/null || failed "Connect to the Internet first."

clear
echo "Welcome to stage 1 of Chrubix's $DISTRO installer. Your thumb drive or SD card will be wiped in 10 seconds."
ps wax | grep chrome/chrome | cut -d' ' -f1 > /tmp/.processes.txt.1
sleep 10
reconfigure_firmware
partition_device $dev $dev_p
format_and_mount_partitions $dev $dev_p
ps wax | grep chrome/chrome | cut -d' ' -f1 > /tmp/.processes.txt.2
for r in `cat /tmp/.processes.txt.1 /tmp/.processes.txt.2 | sort | uniq -u`; do kill $r 2>/tmp/null || echo -en ""; done

install_the_necessaries $dev $dev_p $root $boot $kern			# bootstrap, kernel, etc. ... and stage 2 (.py)
call_stage_two
cd /
umount $root/{tmp,sys,proc,dev/pts,dev} || echo "Warning - failed to unmount tmp/sys/proc/dev/whatever"
umount $boot $kern $root 2> /tmp/null || echo -en ""
echo "Please reboot, then pess <Ctrl>U at the boot screen. Rebooting in 20 seconds..."
sleep 20;sync;sync;sync; umount $boot $kern $root 2> /tmp/null || echo -en ""
reboot





actual_stage1() {
		stage1_ramdisk_within_chromeos
	elif [ "$line" = "B" ] ; then
		wget bit.ly/1pCmy3H -O - | gunzip -dc > /tmp/clarion.sh
		bash /tmp/clarion.sh
	elif [ "$line" = "C" ] ; then
		
	else
		failed "I don't understand '$line'. Sorry..."
	fi
}



#################################################################

if [ "$USER" = "root" ] ; then
	wget bit.ly/1hdWfk6 | sudo bash

else
	sudo bash $0
fi
exit $?
