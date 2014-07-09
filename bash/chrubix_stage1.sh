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
#
# To force from-the-ground-up rebuild & to forgo online (Dropbox) URLs:-
# # touch /tmp/FROMSCRATCH
###################################################################################


if [ "$USER" != "root" ] ; then
	SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
	fname=$SCRIPTPATH/`basename $0`
	sudo bash $fname $@
	exit $?
fi




ALARPY_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/alarpy.tar.xz"
FINALS_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/finals"
CHRUBIX_URL=https://github.com/ReubenAbrams/Chrubix/archive/master.tar.gz
OVERLAY_URL=https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz
RYO_TEMPDIR=/root/.rmo
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
KERNEL_SRC_BASEDIR=$SOURCES_BASEDIR/linux-chromebook
LOGLEVEL=2

if [ -e "/home/chronos/user/Downloads/reubenabrams.txt" ] ; then 
	FINALS_URL="https://dont.use.online.stuff.at.all"
	if ping -W2 -c1 192.168.1.66 &>/dev/null ; then
		WGET_PROXY="http://192.168.1.66:8080"
		export http_proxy=$WGET_PROXY
	fi
fi





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
			possibles="$possibles $d"
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

#	clear
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
	rm -Rf $root/usr/local/bin/Chrubix $root/usr/local/bin/1hq8O7s
	wget $CHRUBIX_URL -O - | tar -zx -C $root/usr/local/bin
	mv $root/usr/local/bin/Chrubix* $root/usr/local/bin/Chrubix	# rename Chrubix-master (or whatever) to Chrubix
	wget $OVERLAY_URL -O - | tar -Jx -C $root/usr/local/bin/Chrubix || echo "Sorry. Dropbox is down. We'll have to rely on GitHub..."
	for f in chrubix.sh greeter.sh ersatz_lxdm.sh CHRUBIX redo_mbr.sh modify_sources.sh ; do
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


restore_stage_X_from_backup() {
	local distroname device root
	distroname=$1
	fname=$2
	root=$3
#	clear
	echo "Using $distroname midpoint file $fname"
	pv $fname | tar -Jx -C $root || failed "Failed to unzip $fname --- J err?"
	echo "Restored ($distroname, stage X) from $fname"
	rm -Rf $root/usr/local/bin/Chrubix
}



get_distro_type_the_user_wants() {
	url=""
	while [ "$distroname" = "" ] ; do
		clear
		echo -en "Welcome to the Chrubix installer. Which GNU/Linux distro shall I install on $dev?

Choose from...
   (A)rchLinux
   (J)essie, a.k.a. Debian Unstable
   (W)heezy, a.k.a. Debian Stable
   (T) - Alarmist, a TAILS-like ARM distro

----early alpha (not ready for public consumption) ----
(F)edora; (K)ali; (S)uSE 12.3; (U)buntu

Which would you like me to install? "
		read r
		case $r in
"A") distroname="archlinux";;
"F") distroname="fedora";;
"J") distroname="debianjessie";;
"K") distroname="kali";;
"S") distroname="suse";;
"T") distroname="alarmistwheezy";;
"U") distroname="ubuntupangolin";;
"W") distroname="debianwheezy";;
*)   echo "Unknown distro";;
		esac
	done
	url=$FINALS_URL/$distroname/$distroname"__D.xz"
	squrl=$FINALS_URL/$distroname/$distroname.sqfs
	echo $distroname > $lockfile
}


restore_from_stage_X_backup_if_possible() {
	mkdir -p /tmp/a /tmp/b
	mount /dev/sda4 /tmp/a &> /dev/null || echo -en ""
	mount /dev/sdb4 /tmp/b &> /dev/null || echo -en ""
	for stage in D C B A ; do
		fnA="/tmp/a/$distroname/"$distroname"__"$stage".xz"
		fnB="/tmp/b/$distroname/"$distroname"__"$stage".xz"
		for fname in $fnA $fnB ; do
			if [ -e "$fname" ] ; then
				restore_stage_X_from_backup $distroname $fname $root
				echo "9999" > $root/.checkpoint.txt
				echo "$fname" > $root/.url_or_fname.txt
				return 0
			fi
		done
	done
	[ "$url" = "" ] && url=$FINALS_URL/$distroname/$distroname"__D.xz"
	echo "FYI, url=$url"
	if wget --spider $url -O /dev/null ; then
		if wget $url -O - | tar -Jx -C $root ; then
			echo "Restored ($distroname, stage D) from Dropbox"
			echo "9999" > $root/.checkpoint.txt
			echo "$url" > $root/.url_or_fname.txt
			return 0
		fi
	else
		echo "Online stage D not found." > /dev/stderr
	fi
	return 1
}


restore_from_squash_fs_backup_if_possible() {
	mkdir -p /tmp/a /tmp/b
	mount /dev/sda4 /tmp/a &> /dev/null || echo -en ""
	mount /dev/sdb4 /tmp/b &> /dev/null || echo -en ""
	
	fnA=/tmp/a/$distroname/$distroname.sqfs
	fnB=/tmp/b/$distroname/$distroname.sqfs
	for fname in $fnA $fnB ; do
		if [ -e "$fname" ] ; then
			if [ "$temp_or_perm" = "temp" ] ; then	
				echo "Installing squashfs file"
				find /tmp/[a,b]/$distroname/$distroname.kernel &> /dev/null || failed "Squashfs file is present but kernel file is not. Boo..."
				pv $fname > $root/.squashfs.sqfs && echo "...copied across OK" || failed "Failed to copy the squashfs file across."
				cp /tmp/[a,b]/$distroname/$distroname.kernel /tmp/.kernel.dat
				hack_something_squishy $distroname $root $dev_p
				return 0
			fi
		fi
	done
	squrl=$FINALS_URL/$distroname/$distroname.sqfs
	echo "squrl = $squrl"
	if wget --spider $squrl -O - > $root/.squashfs.sqfs &> /dev/null ; then
		if [ "$temp_or_perm" = "temp" ] ; then
			wget $squrl -O - > $root/.squashfs.sqfs && echo "Squashfs file downloaded and installed OK" || failed "Failed to restrieve squashfs file from URL"
			echo "Restored ($distroname, squash fs) from Dropbox"
			hack_something_squishy $distroname $root $dev_p
			return 0
		fi
	else
		echo "Online squashfs not found." > /dev/stderr
	fi
	return 1
}


sign_and_write_custom_kernel() {
	local writehere rootdev extra_params_A extra_params_B readwrite root
	root=$1
	writehere=$2
	rootdev=$3
	vmlinux_path=$4
	extra_params_A=$5
	extra_params_B=$6
# echo "sign_and_write_custom_kernel() -- writehere=$writehere rootdev=$rootdev "
	echo -en "Writing kernel to boot device (replacing nv_u-boot)..."
	[ -e "$vmlinux_path" ] || failed "Cannot find original kernel path '$vmlinux_path'"
	dd if=/dev/zero of=$writehere bs=1k 2> /dev/null || echo -en "..."
	echo "$extra_params_A $extra_params_B" | grep crypt &> /dev/null && readwrite=ro || readwrite=rw # TODO Shouldn't it be rw always?
	echo "console=tty1  $extra_params_A root=$rootdev rootwait $readwrite quiet systemd.show_status=0 loglevel=$LOGLEVEL lsm.module_locking=0 init=/sbin/init $extra_params_B" > /tmp/kernel.flags
	vbutil_kernel --pack /tmp/vmlinuz.signed --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 \
--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config /tmp/kernel.flags \
--vmlinuz $vmlinux_path --arch arm && echo -en "..." || failed "Failed to sign kernel"
	sync;sync;sync;sleep 1
	dd if=/tmp/vmlinuz.signed of=$writehere &> /dev/null && echo -en "..." || failed "Failed to write kernel to $writehere"
	echo "OK."
}


hack_something_squishy() {
	local distroname root dev_p
	distroname=$1
	root=$2
	dev_p=$3
	
	echo "9999" > $root/.checkpoint.txt
	umount /tmp/a /tmp/b &> /dev/null || echo -en ""
	# FYI, $root is mounted on /dev/mmcblk1p3 (or similar).
	mkdir -p $root/.ro
	kernelpath=/tmp/.kernel.dat
	if [ ! -e "$kernelpath" ] ; then
		wget $FINALS_URL/$distroname/$distroname.kernel -O - > $kernelpath || failed "Failed to download $distroname.kernel"
	fi
	sign_and_write_custom_kernel $root "$dev_p"1 "$dev_p"3 $kernelpath "" ""  || failed "Failed to sign/write custom kernel"
}


oh_well_start_from_beginning() {
	cd /
	echo "OK. There was no Stage D available on a thumb drive or online."
#	clear
	echo "Installing bootstrap filesystem..."
	mkdir -p $btstrap
	if [ -e "/home/chronos/user/Downloads/alarpy.tar.xz" ] ; then
		tar -Jxf /home/chronos/user/Downloads/alarpy.tar.xz -C $btstrap || failed "Failed to install alarpy.tar.xz"
	else
		wget $ALARPY_URL -O - | tar -Jx -C $btstrap || failed "Failed to download/install alarpy.tar.xz"
	fi
	echo ""
	echo "en_US.UTF-8 UTF-8" >> $btstrap/etc/locale.gen
	chroot_this $btstrap "locale-gen"
	echo "LANG=\"en_US.UTF-8\"" >> $btstrap/etc/locale.conf
	echo "nameserver 8.8.8.8" >> $btstrap/etc/resolv.conf
}




ask_if_user_wants_temporary_or_permanent() {
	temp_or_perm=""
	while [ "$temp_or_perm" = "" ] ; do
		echo "
Would you prefer a temporary setup or a permanent one? Before you choose, consider your options.

TEMPORARY: When you boot, you will see a little popup window that asks you about mimicking Windows XP,
spoofing your MAC address, etc. Whatever you do while the OS is running, nothing will be saved to disk.

PERMANENT: When you boot, you will be prompted for a password. No password? No access. The whole disk
is encrypted. Although you will initially be logged in as a guest whose home directory is on a ramdisk,
you have the option of creating a permanent user, logging in as that user, and saving files to disk.
In addition, you will be prompted for a 'logging in under duress' password. Pick a short one.

MEH: No encryption. No duress password. Changes are permanent. Guest Mode is still the default.
"
		echo -en "(T)emporary, (P)ermanent, or (M)eh ? "
		read line
		if [ "$line" = "t" ] || [ "$line" = "T" ] ; then
			temp_or_perm="temp"
		elif [ "$line" = "p" ] || [ "$line" = "P" ] ; then
			temp_or_perm="perm"
		elif [ "$line" = "m" ] || [ "$line" = "M" ] ; then
			temp_or_perm="meh"
		fi
	done
}



main() {
	echo "Chrubix ------ starting now"
	umount /tmp/_root*/.bootstrap/tmp/_root/{dev,tmp,proc,sys} 2> /dev/null || echo -en ""
	umount /tmp/_root*/.bootstrap/tmp/_root 2> /dev/null || echo -en ""
	umount /tmp/_root*/.bootstrap/{dev,tmp,proc,sys} 2> /dev/null || echo -en ""
	umount /tmp/_root*/.bootstrap /tmp/_root*/.ro /tmp/_root.*/.* 2> /dev/null || echo -en ""
	#clear
	mount | grep /dev/mapper/encstateful &> /dev/null || failed "Run me from within ChromeOS, please."
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
	if [ -e "$lockfile" ] && [ -e "/tmp/temp_or_perm" ] ; then
		distroname=`cat $lockfile`
		temp_or_perm=`cat /tmp/temp_or_perm`
	else
		get_distro_type_the_user_wants
		if [ "$distroname" = "alarmist" ] ; then
			temp_or_perm="temp"
			echo "OK. Everything will be temporary. Nothing will be permanent. (Such is Life...)"
		else
			ask_if_user_wants_temporary_or_permanent
		fi
		echo "$temp_or_perm" > /tmp/temp_or_perm
	fi
	
	btstrap=$root/.bootstrap
	installer_fname=/tmp/$RANDOM$RANDOM$RANDOM	# Script to install tarball and/or OS... *and* mount dev, sys, tmp, etc.
	if mount | grep "$dev" | grep "$root" &> /dev/null ; then
		umount "$dev"* &> /dev/null || echo "Already partitioned and mounted. Reboot and try again..."
	fi
	sudo stop powerd || echo -en ""
		
	partition_device $dev $dev_p
	format_partitions $dev $dev_p
	mkdir -p $root
	mount $mount_opts "$dev_p"3  $root
	mkdir -p $btstrap
	mkdir -p /tmp/a
	res=0
	mkdir -p $btstrap/{dev,proc,tmp,sys}
	mkdir -p $root/{dev,proc,tmp,sys}
	
	mount devtmpfs  $btstrap/dev -t devtmpfs	|| echo -en ""
	mount sysfs     $btstrap/sys -t sysfs		|| echo -en ""
	mount proc      $btstrap/proc -t proc		|| echo -en ""
	mount tmpfs     $btstrap/tmp -t tmpfs		|| echo -en ""
	
	mkdir -p $btstrap/tmp/_root
	mount -o noatime "$dev_p"3 $btstrap/tmp/_root		|| echo -en ""
	mount devtmpfs $btstrap/tmp/_root/dev -t devtmpfs	|| echo -en ""
	mount tmpfs $btstrap/tmp/_root/tmp -t tmpfs			|| echo -en ""
	mount proc $btstrap/tmp/_root/proc -t proc			|| echo -en ""
	mount sys $btstrap/tmp/_root/sys -t sysfs			|| echo -en ""
	
	sudo crossystem dev_boot_usb=1 dev_boot_signed_only=0 || echo "WARNING - failed to configure USB and MMC to be bootable"	# dev_boot_signed_only=0
	
	if restore_from_squash_fs_backup_if_possible ; then
		echo "Restored from squashfs. Good."
	else
		if restore_from_stage_X_backup_if_possible ; then
			echo "Restored from stage X. Good."
		else
			echo "OK. Starting from beginning."
			oh_well_start_from_beginning
		fi
		install_chrubix $btstrap $dev "$dev_p"3 "$dev_p"2 "$dev_p"1 $distroname
		tar -cz /usr/lib/xorg/modules/drivers/armsoc_drv.so \
			/usr/lib/xorg/modules/input/cmt_drv.so /usr/lib/libgestures.so.0 \
			/usr/lib/libevdev* \
			/usr/lib/libbase*.so \
			/usr/lib/libmali.so* \
			/usr/lib/libEGL.so* \
			/usr/lib/libGLESv2.so* > $btstrap/tmp/.hipxorg.tgz 2>/dev/null
		tar -cz /usr/bin/vbutil* /usr/bin/old_bins /usr/bin/futility > $btstrap/tmp/.vbtools.tgz 2>/dev/null
		tar -cz /usr/share/vboot > $btstrap/tmp/.vbkeys.tgz 2>/dev/null #### MAKE SURE CHRUBIX HAS ACCESS TO Y-O-U-R KEYS and YOUR vbutil* binaries ####
		tar -cz /lib/firmware > $btstrap/tmp/.firmware.tgz 2>/dev/null # save firmware!
		chroot_this $btstrap "chmod +x /usr/local/bin/*"
		echo "$temp_or_perm" > $btstrap/.temp_or_perm.txt
		ln -sf ../../bin/python3 $btstrap/usr/local/bin/python3
		echo "************ Calling CHRUBIX, the Python powerhouse of pulchritudinous perfection ************"
		chroot_this     $btstrap "/usr/local/bin/chrubix.sh" && res=0 || res=$?
		[ "$res" -ne "0" ] && failed "Because chrubix reported an error, I'm aborting... and I'm leaving everything mounted."
	fi
	
	sync; umount $btstrap/tmp/_root/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
	sync; umount $btstrap/tmp/_root/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
	sync; umount $btstrap/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
	sync; umount $btstrap/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
	unmount_everything       $root $boot $kern $dev_p
	
	if [ "$res" -eq "0" ] ; then
		sudo start powerd || echo -en ""
		if [ "$DONOTREBOOT" = "" ] ; then 
			echo -en "$distroname has been installed on $dev\nPress ENTER to reboot, or wait 60 seconds..."
			read -t 60 line || reboot
			reboot
		fi
	else
		echo -en "\n\n\n\n\n\n\nDone, although errors occurred..."
	fi
	return $res
}


##################################################################################################################################


if [ "$1" != "EVERYONE" ] ; then
	set -e
	main
	exit $?
else
	set +e
	DONOTREBOOT=yousaidit
	mount /dev/sda4 /tmp/a &> /dev/null || echo -en ""
	mount /dev/sdb4 /tmp/b &> /dev/null || echo -en ""
	for wildcard in .kernel .sqfs _D.xz ; do 
		rm -f /media/removable/*/*/*"$wildcard"
	done
	for distroname in alarmistwheezy archlinux debianjessie debianwheezy ; do
		echo "$distroname" > /tmp/.chrubix.distro.mmcblk1
		echo "temp" > /tmp/temp_or_perm
		clear
		echo "About to build $distroname..."
		main
		echo "`date` Back from building $distroname"
		echo "`date` Built $distroname" >> /tmp/log.txt
	done
fi
