#!/bin/bash
#
# chrubix_s1_latest.sh	<== FOR TESTING THE LATEST CODE
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
# # cd && rm -f latest_that && wget bit.do/latest_that && sudo bash latest_that
# 
###################################################################################



ALARPY_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/alarpy.tar.xz"
PARTED_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/parted_and_friends.tar.xz"
echo "$0" | fgrep latest_that &> /dev/null || FINALS_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/finals"
CHRUBIX_URL="http://github.com/ReubenAbrams/Chrubix/archive/master.tar.gz"
OVERLAY_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz"
RYO_TEMPDIR=/root/.rmo
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
LOGLEVEL=2
SPLITPOINT=6000998	# 2GB			# If you change this, you shall change the line in redo_mbr.sh too!
MYDISK_CHR_STUB=/.mydisk
HIDDENLOOP=/dev/loop3			# hiddendev uses this (if it is hidden) :)
LOOPFS_BTSTRAP=/tmp/_loopfs_bootstrap
PARTED_CHROOT=$LOOPFS_BTSTRAP/.parted
FSTAB_OPTS="defaults,noatime,nodiratime" #commit=100
MOUNT_OPTS="-o $FSTAB_OPTS"
TOP_BTSTRAP=/tmp/_build_here
MINIDISTRO_CHROOT=$TOP_BTSTRAP/.alarpy
MYDISK_CHROOT=$MINIDISTRO_CHROOT$MYDISK_CHR_STUB
VFAT_MOUNTPOINT=/tmp/.vfat.mountpoint




# PARTED_CHROOT is mounted on the internal loopfs
# MINIDISTRO_CHROOT and its files are actually *living on* MYDISK_CHROOT/.alarpy
# /dev/mmcblk1p2 is mounted at /tmp/_build_here 				 a.k.a. $TOP_BTSTRP
# The mini-distro lives here:  /tmp/_build_here/.alarpy  		 a.k.a. $MINIDISTRO_CHROOT
# The actual dest distro is at /tmp/_build_here/.alarpy/.mnydisk a.k.a. $MYDISK_CHROOT


failed() {
	kill $bkgd_proc &> /dev/null || echo -en ""
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
		sync;sync;sync
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


unmount_bootstrap_stuff() {
	for btstrap in $1 /tmp/_root.mmcblk1/.bootstrap /home/chronos/user/Downloads/.bootstrap ; do	
		umount $btstrap/tmp/_root/{dev,tmp,proc,sys} 2> /dev/null || echo -en ""
		umount $btstrap/tmp/posterity 2> /dev/null || echo -en ""
		umount $btstrap/tmp/_root/{dev,tmp,proc,sys} 2> /dev/null || echo -en ""
		umount $btstrap/tmp/posterity 2> /dev/null || echo -en ""
		umount $btstrap/tmp/_root 2> /dev/null || echo -en ""
		umount $btstrap/{dev,tmp,proc,sys} 2> /dev/null || echo -en ""
		umount $btstrap/tmp/_root/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
		umount /tmp/_root*/.ro /tmp/_root.*/.* 2> /dev/null || echo -en ""
		umount $btstrap/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
	done
}




##################################################################################################################################

install_chrubix() {
	local root dev rootdev hiddendev kerndev distro proxy_string mydiskmtpt rr sss evilmaid
	root=$1
	dev=$2
	rootdev=$3
	hiddendev=$4
	kerndev=$5
	distroname=$6
	
	if [ "$EVILMAID" = "zed" ] ; then
		evilmaid="\-Z"
	elif [ "$EVIL_MAID" = "yes" ] ; then
		evilmaid="\-E"
	else
		evilmaid=""
	fi
	 
	mydiskmtpt=$MYDISK_CHR_STUB
	[ "$mydiskmtpt" = "/`basename $mydiskmtpt`" ] || failed "install_chrubix() -- $mydiskmtpt must not have any subdirectories. It must BE a directory and a / one at that."
	mkdir -p $MYDISK_CHROOT
	mount $ROOTDEV $MYDISK_CHROOT || failed "install_chrubix() -- unable to mount root device at $MYDISK_CHROOT"	
	mount_dev_sys_proc_and_tmp $MYDISK_CHROOT
	
	cp -f $MINIDISTRO_CHROOT/.[a-z]*.txt $MYDISK_CHROOT/ || echo -en ""
	
	touch $TOP_BTSTRAP/.gloria.first-i-was-afraid
	[ -e "$MYDISK_CHROOT/.gloria.first-i-was-afraid" ] || failed "For some reason, MYDISK_CHROOT and TOP_BTSTRAP don't share the '/' directory."
	
	touch $MINIDISTRO_CHROOT/.gloria.i-was-petrified
	[ -e "$MYDISK_CHROOT/.gloria.i-was-petrified" ] && failed "Why are MINIDISTRO_CHROOT and MYDISK_CHROOT sharing a '/' directory?"

	rm -f $TOP_BTSTRAP/.gloria*
	rm -f $MINIDISTRO_CHROOT/.gloria*
	rm -f $MYDISK_CHROOT/.gloria*
		
	rm -Rf $root/usr/local/bin/Chrubix
	lastblock=`cgpt show $DEV | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2` || failed "Failed to calculate lastblock"
	maximum_length=$(($lastblock-$SPLITPOINT-8))
	SIZELIMIT=$(($maximum_length*512))
	
	[ "$SIZELIMIT" != "" ] || failed "Set SIZELIMIT before calling install_chrubix(), please."
	[ "$WGET_PROXY" != "" ] && proxy_info="export http_proxy=$WGET_PROXY; export ftp_proxy=$WGET_PROXY" || proxy_info=""

	echo -en "*** Pausing so that author can futz with the GitHub and overlay tarballs; press ENTER to continue ***"; read line

	wget $CHRUBIX_URL -O - | tar -xz -C $root/usr/local/bin 2> /dev/null
	rm -Rf $root/usr/local/bin/Chrubix
	mv     $root/usr/local/bin/Chrubix* $root/usr/local/bin/Chrubix	# rename Chrubix-master (or whatever) to Chrubix

	wget $OVERLAY_URL -O - | tar -Jx -C $root/usr/local/bin/Chrubix 2> /dev/null || echo "Sorry. Dropbox is down. We'll have to rely on GitHub..."

	for rr in $root$MYDISK_CHR_STUB $root; do
		if [ ! -e "$rr/usr/local/bin" ] ; then
			echo "You are probably installing from scratch. Fair enough."
			continue
		fi
		[ -d "$rr" ] || failed "install_chrubix() -- $rr does not exist. BummeR."
		for f in chrubix.sh greeter.sh ersatz_lxdm.sh CHRUBIX redo_mbr.sh modify_sources.sh make_me_persistent.sh adjust_brightness.sh adjust_volume.sh ; do
			ln -sf Chrubix/bash/$f $rr/usr/local/bin/$f || echo "Cannot do $f softlink"
		done
		cd $rr/usr/local/bin/Chrubix/bash
		[ -e "chrubix.sh.orig" ] || failed "Where is chrubix.sh.orig?!"
	
		cat chrubix.sh.orig \
| sed s/\$dev/\\\/dev\\\/`basename $dev`/ \
| sed s/\$rootdev/\\\/dev\\\/`basename $rootdev`/ \
| sed s/\$hiddendev/\\\/dev\\\/`basename $hiddendev`/ \
| sed s/\$kerndev/\\\/dev\\\/`basename $kerndev`/ \
| sed s/\$distroname/$distroname/ \
| sed s/\$splitpoint/$(($SPLITPOINT*512))/ \
| sed s/\$sizelimit/$SIZELIMIT/ \
| sed s/\$mydiskmtpt/\\\/`basename $mydiskmtpt`/ \
| sed s/\$evilmaid/$evilmaid/ \
> chrubix.sh || failed "Failed to rejig chrubix.sh.orig"

# Is this necessary? Does it even work?
		cd $rr/usr/local/bin/Chrubix
		chmod -R 755 .
        chown -R 0 .
        mkdir src.meow
        mv src/* src.meow
        mv src src.woof
        mv src.meow src
        rm -Rf src.woof
        chmod -R 755 $rr/usr/local/bin
        chmod +x $rr/usr/local/bin/* || echo -en "WARNING - softlink(s) error(s) A"
        chmod +x $rr/usr/local/bin/Chrubix/bash/*
        chmod -R 755 $rr/usr/local/bin/Chrubix/
	done

	if [ -e "$root$MYDISK_CHR_STUB/usr/local/bin" ] ; then
		cp -af $root/usr/local/bin/Chrubix $root$MYDISK_CHR_STUB/usr/local/bin/ || failed "Failed to copy chrubix folder from mydisk to minidistro #1"
	fi
	if [ -e "$TOP_BTSTRAP/usr/local/bin/" ] ; then
		cp -af $root/usr/local/bin/Chrubix $TOP_BTSTRAP/usr/local/bin/ || failed "Failed to copy chrubix folder from mydisk to minidistro #1"
	fi
}


call_chrubix() {
	local btstrap fname
	btstrap=$1

	tar -cz /usr/lib/xorg/modules/drivers/armsoc_drv.so \
		/usr/lib/xorg/modules/input/cmt_drv.so /usr/lib/libgestures.so.0 \
		/usr/lib/libevdev* \
		/usr/lib/libbase*.so \
		/usr/lib/libmali.so* \
		/usr/lib/libEGL.so* \
		/usr/lib/libGLESv2.so* > $btstrap/tmp/.hipxorg.tgz 2>/dev/null || failed "Failed to save old drivers"
	tar -cz /usr/bin/vbutil* /usr/bin/futility > $btstrap/tmp/.vbtools.tgz
	tar -cz /usr/share/alsa/ucm/ > $btstrap/tmp/.usr_share_alsa_ucm.tgz
	tar -cz /usr/share/vboot > $btstrap/tmp/.vbkeys.tgz || failed "Failed to save your keys" #### MAKE SURE CHRUBIX HAS ACCESS TO Y-O-U-R KEYS and YOUR vbutil* binaries ####
	tar -cz /lib/firmware > $btstrap/tmp/.firmware.tgz || failed "Failed to save your firmware"  # save firmware!
#	tar -cz /etc/X11/xorg.conf.d /usr/share/gestures > $btstrap/tmp/.xorg.conf.d.tgz || failed "Failed to save xorg.conf.d stuff"
	chroot_this $btstrap "chmod +x /usr/local/bin/*" || echo -en "WARNING -- softlink(s) errors() B"
	ln -sf ../../bin/python3 $btstrap/usr/local/bin/python3
	echo "************ Calling CHRUBIX, the Python powerhouse of pulchritudinous perfection ************"
	echo "yep, use latest" > $root/tmp/.USE_LATEST_CHRUBIX_TARBALL
	[ -e "$btstrap/usr/local/bin/Chrubix" ] || failed "Where is $btstrap/usr/local/bin/Chrubix? #1"	
	[ -e "$MINIDISTRO_CHROOT/usr/local/bin/Chrubix" ] || failed "Where is $MINIDISTRO_CHROOT/usr/local/bin/Chrubix? #2"

	[ "$EVILMAID" != "no" ] && cp -f $btstrap/tmp/.*z $TOP_BTSTRAP/
	chroot_this $btstrap "/usr/local/bin/chrubix.sh" || failed "Because chrubix reported an error, I'm aborting... and I'm leaving everything mounted.
Type 'sudo chroot $MINIDISTRO_CHROOT' and then 'chrubix.sh' to retry."
	if [ -e "$TOP_BTSTRAP/.squashfs.sqfs" ] ; then
		echo -en "Moving squashfs and kernel to memory card..."
		mv $TOP_BTSTRAP/.squashfs.sqfs $TOP_BTSTRAP/.kernel.dat $VFAT_MOUNTPOINT || failed "call_chrubix() -- where are the sqfs and kernel?"
		echo "Done."
	else
		touch /tmp/.do.not.install.new.mbr
	fi
}

partition_the_device() {
	local dev dev_p btstrap splitpoint only_two_partitions
	dev=$1
	dev_p=$2
	btstrap=$3
	splitpoint=$4
	only_two_partitions=$5

	mount | fgrep "$DEV" && failed "partition_my_disk() --- stuff from $DEV is already mounted. Abort!" || echo -en ""
	echo -en "Partitioning"

	sync;sync;sync; umount $root/{dev/pts,dev,proc,sys,tmp} &> /dev/null || echo -en "."
	sync;sync;sync; umount "$dev_p"* &> /dev/null &> /dev/null  || echo -en "."
	sync;sync;sync; umount "$dev"* &> /dev/null &> /dev/null  || echo -en "."
	sync;sync;sync; umount /media/removable/* &> /dev/null  || echo -en "."
	sync;sync;sync
	chroot_this $btstrap "parted -s $dev mklabel gpt" || failed "There is something vaguely wrong with your SD card, I suspect. Reboot and try again, please."
	chroot_this $btstrap "cgpt create -z $dev" || failed "Failed to create -z $dev"
	chroot_this $btstrap "cgpt create $dev" || failed "Failed to create $dev"
	chroot_this $btstrap "cgpt add -i  1 -t kernel -b  8192 -s 32768 -l U-Boot -S 1 -T 5 -P 10 $dev" || failed "Failed to create 1"
	chroot_this $btstrap "cgpt add -i 12 -t data   -b 40960 -s 32768 -l Script $dev" || failed "Failed to create 12"

	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2` || failed "Failed to calculate lastblock"

	if [ "$splitpoint" = "" ] ; then
		chroot_this $btstrap "cgpt add -i  2 -t data   -b 73728 -s `expr $lastblock - 73728` -l Root $dev" || failed "Failed to create 3"
	elif [ "$only_two_partitions" = "yes" ] ; then
		chroot_this $btstrap "cgpt add -i  2 -t data   -b 73728 -s `expr $splitpoint - 73728` -l Root $dev" || failed "Failed to create 3"
	else
		chroot_this $btstrap "cgpt add -i  2 -t data   -b 73728 -s `expr $splitpoint - 73728` -l Root $dev" || failed "Failed to create 3"
		chroot_this $btstrap "cgpt add -i  3 -t data   -b $splitpoint -s `expr $lastblock - $splitpoint` -l Kernel $dev" || failed "Failed to create 2"
	fi
	chroot_this $btstrap "partprobe $dev"
	sync;sync;sync
}


sign_and_write_custom_kernel() {
	local writehere rootdev extra_params_A extra_params_B readwrite root
	root=$1
	writehere=$2
	rootdev=$3
	vmlinux_path=$4
	extra_params_A=$5
	extra_params_B=$6
	if [ -e "/tmp/.do.not.install.new.mbr" ] ; then
		echo "sign_and_write_custom_kernel() -- skipping this part; the python chrubix code handled it already"
		return 0
	fi
# echo "sign_and_write_custom_kernel() -- writehere=$writehere rootdev=$rootdev "
	echo -en "Writing kernel to boot device (replacing nv_u-boot)..."
	[ -e "$vmlinux_path" ] || failed "Cannot find original kernel path '$vmlinux_path'"
	dd if=/dev/zero of=$writehere bs=1k 2> /dev/null || echo -en "..."
	echo "$extra_params_A $extra_params_B" | grep crypt &> /dev/null && readwrite=ro || readwrite=rw # TODO Shouldn't it be rw always?
	echo "console=tty1  $extra_params_A root=$rootdev rootwait $readwrite quiet systemd.show_status=0 loglevel=$LOGLEVEL lsm.module_locking=0 init=/sbin/init $extra_params_B" > /tmp/kernel.flags
	tar -cJ /usr/share/vboot 2> /dev/null > $root/.vboot.gz
	cp -f $vmlinux_path /tmp/vmlinux.file	
	chroot_this / "vbutil_kernel --pack /tmp/vmlinuz.signed --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 \
--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config /tmp/kernel.flags \
--vmlinuz /tmp/vmlinux.file --arch arm --bootloader /tmp/kernel.flags &&" || failed "Failed to sign kernel"
	sync;sync;sync;sleep 1	# FYI, --bootloader is a dummy parameter :-/
	dd if=/tmp/vmlinuz.signed of=$writehere &> /dev/null && echo -en "..." || failed "Failed to write kernel to $writehere"
	echo -en "OK. Signed & written kernel. "
}


get_distro_type_the_user_wants() {
	local r
	url=""
	while [ "$distroname" = "" ] ; do
		clear
# NOT SUPPORTED: (F)edora, (S)uSE 12.3
		echo -en "Welcome to the Chrubix installer. Which GNU/Linux distro shall I install on $DEV?

Choose from...

   (A)rchLinux <== ArchLinuxArm's make package is broken. It keeps segfaulting.
   (F)edora 19
   (S)tretch, a.k.a. Debian Testing w/ kernel 4.1
   (J)essie, a.k.a. Debian Stable
   (W)heezy, a.k.a. Debian Oldstable
   (U)buntu 15.04, a.k.a. Vivid <== kernel/jfsutils problems
   

Which would you like me to install? "
		read r
		case $r in
"A") distroname="archlinux";;
"F") distroname="fedora19";;
"J") distroname="debianjessie";;
"K") distroname="kali";;
"E") distroname="suse";;
"S") distroname="debianstretch";;
"U") distroname="ubuntuvivid";;
"W") distroname="debianwheezy";;
*)   echo "Unknown distro";;
		esac
	done
	url=$FINALS_URL/$distroname/$distroname"__D.xz"
	squrl=$FINALS_URL/$distroname/$distroname.sqfs
	DISTRONAME=$distroname
}



ask_if_afraid_of_evil_maid() {
	local r
	EVILMAID=""
	while [ "$EVILMAID" != "yes" ] && [ "$EVILMAID" != "no" ] && [ "$EVILMAID" != "zed" ] ; do
		echo -en "Does the evil maid scare you (y/n)? "
		read r
		if [ "$r" = "Y" ] || [ "$r" = "y" ] ; then
			EVILMAID=yes
		elif [ "$r" = "N" ] || [ "$r" = "n" ] ; then
			EVILMAID=no
		elif [ "$r" = "Z" ] || [ "$r" = "z" ] ; then
			EVILMAID=zed
		fi
	done
}



locate_prefab_file() {
	local mypath
	mypath=/tmp/prefab_thumb_drive
	mkdir -p $mypath
	if ! mount | fgrep "$mypath" &> /dev/null ; then
		if ! mount /dev/sda1 $mypath 2> /dev/null ; then
			if ! mount /dev/sdb1 $mypath 2> /dev/null ; then
				echo -en ""
			fi
		fi
	fi

	if mount | fgrep "$mypath" &> /dev/null ; then
		locate_prefab_on_thumbdrive $mypath
	else
		locate_prefab_on_dropbox
	fi
	return $?
}


locate_prefab_on_dropbox() {
	local sqfs_url stageD_url url
	sqfs_url=$FINALS_URL/$DISTRONAME/$DISTRONAME".sqfs"
	stageD_url=$FINALS_URL/$DISTRONAME/$DISTRONAME"__D.xz"
	if [ "$EVILMAID" != "no" ] ;then
		img_url=""
		sqfs_url=""
	fi
	for url in $sqfs_url $stageD_url ; do
		if wget --spider $url -O /dev/null 2> /dev/null ; then
			echo "$url"
			return 0
		fi
	done
	return 1
}


locate_prefab_on_thumbdrive() { 
	local mypath sqfs_fname fname stageD_fname stageC_fname stageB_fname stageA_fname
	mypath=$1
	sqfs_fname=$mypath/$DISTRONAME/$DISTRONAME".sqfs"
	stageD_fname=$mypath/$DISTRONAME/$DISTRONAME"__D.xz"
	stageC_fname=$mypath/$DISTRONAME/$DISTRONAME"__C.xz"
	stageB_fname=$mypath/$DISTRONAME/$DISTRONAME"__B.xz"
	stageA_fname=$mypath/$DISTRONAME/$DISTRONAME"__A.xz"
	if [ "$EVILMAID" != "no" ] ;then
		img_fname=""
		sqfs_fname=""
	fi
	for fname in $img_fname $sqfs_fname $stageD_fname $stageC_fname $stageB_fname $stageA_fname ; do
		if [ -f "$fname" ] ; then
			echo "$fname"
			return 0
		fi
	done
	return 1	
}


mount_scratch_space_loopback() {
	local loopfile
	loopfile=/home/chronos/user/Downloads/.alarpy.dat
	if [ ! -e "$LOOPFS_BTSTRAP/bin/parted" ] ; then
		umount $LOOPFS_BTSTRAP 2> /dev/null || echo -en ""
		mkdir -p $LOOPFS_BTSTRAP
		losetup -d /dev/loop1 &> /dev/null || echo -en ""
		[ -e "$loopfile" ] || dd if=/dev/zero of=$loopfile bs=1024k count=110 2> /dev/null	#FIXME change to 100
		losetup /dev/loop1 $loopfile
		mke2fs /dev/loop1 &> /dev/null || failed "Failed to mkfs the temp loop partition"
		mount /dev/loop1 $LOOPFS_BTSTRAP || failed "Failed to loopmount /dev/loop1 at $LOOPFS_BTSTRAP"
	fi
}


install_parted_chroot() {
	local bkgd_proc=$1 bt_fname=/tmp/.$RANDOM$RANDOM$RANDOM
	wget $PARTED_URL -O - > $bt_fname || failed "Failed to download/install parted and friends"
	mkdir -p $PARTED_CHROOT
	while ps $bkgd_proc &> /dev/null; do
		echo -en "."
		sleep 1
	done
	tar -Jxf $bt_fname -C $PARTED_CHROOT/
	mkdir -p $PARTED_CHROOT/{dev,sys,proc,tmp}
	mount devtmpfs  $PARTED_CHROOT/dev -t devtmpfs	|| echo -en ""
	mount sysfs     $PARTED_CHROOT/sys -t sysfs		|| echo -en ""
	mount proc      $PARTED_CHROOT/proc -t proc		|| echo -en ""
	mount tmpfs     $PARTED_CHROOT/tmp -t tmpfs		|| echo -en ""
}


mount_scratch_space_loopback_and_install_parted_chroot() {
	local bkgd_proc
	mount_scratch_space_loopback &
	bkgd_proc=$!
	install_parted_chroot $bkgd_proc
}


format_my_disk() {
	local temptxt=/tmp/.temp.txt
	echo -en "Formatting"
	sleep 1; umount "$DEV_P"* &> /dev/null || echo -en ""
	yes | mkfs.ext4 -v $VFATDEV &> $temptxt || failed "Failed to format p2 - `cat $temptxt`"		# FIXME someday, use vfat instead
	echo -en "."
	sleep 1; umount "$DEV_P"* &> /dev/null || echo -en ""
	if cgpt show $DEV | tr -s '\t' ' ' | fgrep " 3 Label" &> /dev/null ; then
		yes | mkfs.ext4 -v $ROOTDEV &> $temptxt || failed "Failed to format p3 - `cat $temptxt`"
	fi
	echo -en "."
	sleep 1; umount "$DEV_P"* &> /dev/null || echo -en ""
	mkfs.vfat -F 16 $KERNELDEV &> $temptxt || failed "Failed to format p12 - `cat $temptxt`"
	echo ".Done."
}


mount_my_disk() {
	mkdir -p $TOP_BTSTRAP $VFAT_MOUNTPOINT
	mount $VFATDEV $VFAT_MOUNTPOINT || failed "mount_my_disk() -- unable to mount p2"
	if cgpt show $DEV | tr -s '\t' ' ' | fgrep " 3 Label" &> /dev/null ; then
		mount $MOUNT_OPTS $ROOTDEV $TOP_BTSTRAP || failed "mount_my_disk() -- unable to mount p3"
	fi
}


wait_for_partitioning_and_formatting_to_complete() {
	echo -en "Partitioning"
	while ps $partandform_proc &> /dev/null ; do
		echo -en "."
		sleep 1
	done
	echo "Installing OS itself..."
}	


install_microdistro() {
	cd /
	wait_for_partitioning_and_formatting_to_complete
	mount_my_disk
	echo "Installing microdistro..."
	mkdir -p $MINIDISTRO_CHROOT
	wget $ALARPY_URL -O - | tar -Jx -C $MINIDISTRO_CHROOT || failed "Failed to download/install microdistro"
	mkdir -p $MINIDISTRO_CHROOT/{dev,proc,sys,tmp}
	mount devtmpfs  $MINIDISTRO_CHROOT/dev -t devtmpfs
	mount sysfs     $MINIDISTRO_CHROOT/sys -t sysfs		
	mount proc      $MINIDISTRO_CHROOT/proc -t proc		
	mount tmpfs     $MINIDISTRO_CHROOT/tmp -t tmpfs		
	echo ""
	echo "en_US.UTF-8 UTF-8" >> $MINIDISTRO_CHROOT/etc/locale.gen
	chroot_this $MINIDISTRO_CHROOT "locale-gen"
	echo "LANG=\"en_US.UTF-8\"" >> $MINIDISTRO_CHROOT/etc/locale.conf
	echo "nameserver 8.8.8.8" >> $MINIDISTRO_CHROOT/etc/resolv.conf
	echo "Woohoo."
}


unmount_my_disk() {
	umount $MYDISK_CHROOT/{tmp,dev,proc,sys} $MYDISK_CHROOT || echo -en "Unable to unmount mydisk chroot"
	umount $ALARPY_CHROOT/{tmp,dev,proc,sys} $MINIDISTRO_CHROOT || echo -en "Unable to unmount alarpy chroot"
	umount $PARTED_CHROOT/{tmp,dev,proc,sys} $PARTED_CHROOT || echo -en "Unable to unmount parted chroot"
	umount $LOOPFS_BTSTRAP/* $LOOPFS_BTSTRAP || echo -en "Unable to unmount main btstrap mtpt"
	umount $TOP_BTSTRAP/{tmp,dev,proc,sys} $TOP_BTSTRAP || echo -en "Unable to unmount top btstrap"
	umount $VFAT_MOUNTPOINT || echo -en "Unable to unmount vfat partition"
}


install_and_call_chrubix() {
	install_chrubix $MINIDISTRO_CHROOT $DEV $ROOTDEV $VFATDEV $KERNELDEV $DISTRONAME
	call_chrubix $MINIDISTRO_CHROOT || failed "call_chrubix() returned an error. Failing."
# FIXME is this necessary? v
	cp -f $MYDISK_CHROOT/.*.txt $VFAT_MOUNTPOINT/ || failed "install_and_call_chrubix() -- failed to copy cool stuff to vfat partition"
# FIXME is this necessary? ^
}


mount_dev_sys_proc_and_tmp() {
	mkdir -p $1/{dev,sys,proc,tmp}
	mount devtmpfs  $1/dev -t devtmpfs
	mount sysfs     $1/sys -t sysfs		
	mount proc      $1/proc -t proc		
	mount tmpfs     $1/tmp -t tmpfs
}


restore_this_stageX_prefab() {
	local prefab_fname_or_url=$1
	local myfifo=/tmp/`basename $prefab_fname_or_url | tr -s '/' '_'`
	local bkgd_proc

	rm -f $myfifo
	mkfifo $myfifo
	cd /
	
	echo "Restoring $prefab_fname_or_url"
	if echo "$prefab_fname_or_url" | fgrep http &> /dev/null ; then
		wget $prefab_fname_or_url -O - | pv -W -B 5m > $myfifo &
		bkgd_proc=$!
	else
		[ -e "$prefab_fname_or_url" ] || failed "restore_this_stageX_prefab() -- $prefab_fname_or_url does not exist"
		pv -W -B 256m $prefab_fname_or_url > $myfifo &
		bkgd_proc=$!
	fi

	wait_for_partitioning_and_formatting_to_complete
	mount_my_disk
	
	cat $myfifo | tar -Jx -C $TOP_BTSTRAP || failed "restore_this_stageX_prefab() -- Failed to unzip $fname --- J err?"	
	echo "Done."

	mkdir -p $TOP_BTSTRAP/{dev,sys,proc,tmp}
	[ -e "$TOP_BTSTRAP/bin/date" ] || failed "restore_this_stageX_prefab() -- you say you've restored from a Stage X file... but where's the date binary? #1"
	[ -e "$MINIDISTRO_CHROOT" ] || failed "Prefab file $prefab_fname_or_url did not contain an .alarpy folder; that is odd. It should have been backed up."
	mount_dev_sys_proc_and_tmp $MINIDISTRO_CHROOT || failed "restore_this_stageX_prefab() -- failed to mount dev, sys, etc. on $MINIDISTRO_CHROOT"
	mkdir -p $MYDISK_CHROOT

# So, at this point:-
# - partition #2 of SD card is mounted   at $TOP_BTSTRAP
# - the .alarpy folder should be present at $TOP_BTSTRAP/.alarpy (a.k.a. $MINIDISTRO_CHROOT)
# - I can chroot into .alarpy and build the rest of the OS at $MKDISK_CHROOT (which is bindmounted to $TOP_BTSTRAP)
	
	echo "9999"                > $MINIDISTRO_CHROOT/.checkpoint.txt 	|| echo "BLAH 1"
	echo "$prefab_fname_or_url" > $MINIDISTRO_CHROOT/.url_or_fname.txt 	|| echo "BLAH 2"
	rm -f $myfifo
}


sign_and_install_kernel() {
	local sqfs_fname=$VFAT_MOUNTPOINT/.squashfs.sqfs
	local kernel_fname=$VFAT_MOUNTPOINT/.kernel.dat
	if [ -e "/tmp/.do.not.install.new.mbr" ] ; then
		echo "Python code signed the kernel. No need to do it again."
		return 0
	fi
	[ -d "$VFAT_MOUNTPOINT" ] || failed "sign_and_install_kernel() -- where is vfat mountpoint?"
	mount | fgrep " $VFAT_MOUNTPOINT " &> /dev/null || failed "sign_and_install_kernel() -- why is vfat mountpoint not mounted?"
	[ -f "$sqfs_fname" ] || failed "sign_and_install_kernel() -- where is the sqfs file?"
	[ -f "$kernel_fname" ] || failed "sign_and_install_kernel() -- where is the kernel?"

	rm -f $MYDISK_CHROOT/.checkpoint.txt $VFAT_MOUNTPOINT/.checkpoint.txt $MINIDISTRO_CHROOT/.checkpoint.txt

	# try ROOTDEV instead of VFATDEV?
	sign_and_write_custom_kernel $MYDISK_CHROOT $UBOOTDEV $VFATDEV $kernel_fname "" ""  || failed "sign_and_install_kernel() -- failed to sign/write custom kernel"
}


	
wipe_spare_space_in_partition() {
	local mtpt=/tmp/koalabear918
	echo -en "Wiping spare space in $1 ..."
	mkdir -p $mtpt
	mount $1 $mtpt
	dd if=/dev/zero of=$mtpt/zero 2> /dev/null || echo -en ""
	rm -f $mtpt/zero
	umount $mtpt
	echo "Done."
}


install_the_hard_way() {
	local prefab_fname_or_url=$1
	# The mounting of the disk is handled by install_microdistro or restore_this_stageX_prefab
	[ "$prefab_fname_or_url" = "" ] && install_microdistro || restore_this_stageX_prefab $prefab_fname_or_url
	install_and_call_chrubix
	sign_and_install_kernel
	unmount_my_disk &> /dev/null || echo -en ""
}


install_from_sqfs_prefab() {
	local prefab_fname_or_url=$1
	local kernel_fname_or_url=$2
	local myfifo=/tmp/`basename $prefab_fname_or_url | tr -s '/' '_'`
	bkgd_proc=""	# DO NOT MAKE THIS LOCAL! ...failed() might need it...
	rm -f $myfifo
	mkfifo $myfifo
	
	if mount | grep "$DEV" ; then
		umount "$DEV"* &> /dev/null || echo -en ""
		mount | fgrep "$DEV" && failed "partition_my_disk() --- stuff from $DEV is already mounted. Abort!" || echo -en ""
	fi
	
	if echo "$prefab_fname_or_url" | fgrep http &> /dev/null ; then
		wget $prefab_fname_or_url -O - | pv -W -B 5m > $myfifo & # || failed "install_from_sqfs_prefab() -- Unable to download $prefab_fname_or_url"
		bkgd_proc=$!
	else
		pv -W -B 64m $prefab_fname_or_url > $myfifo & # || failed "install_from_sqfs_prefab() -- Failed to save $prefab_fname_or_url --- L err?"
		bkgd_proc=$!
	fi

	wait_for_partitioning_and_formatting_to_complete
	mount_my_disk

	if echo "$prefab_fname_or_url" | fgrep http &> /dev/null ; then
		wget $kernel_fname_or_url -O - > $VFAT_MOUNTPOINT/.kernel.dat || failed "install_from_sqfs_prefab() -- Unable to download $kernel_fname_or_url"
	else
		cp -f $kernel_fname_or_url $VFAT_MOUNTPOINT/.kernel.dat || failed "install_from_sqfs_prefab() -- Failed to save $kernel_fname_or_url --- L err?"
	fi

	ps $bkgd_proc &> /dev/null || failed "install_from_sqfs_prefab() -- pv crapped out :-/"
#	echo "Restoring from $prefab_fname_or_url and .../`basename $kernel_fname_or_url`"
	cat $myfifo > $VFAT_MOUNTPOINT/.squashfs.sqfs 
	sign_and_install_kernel		# Try putting this line after mount_my_disk :) ... and see what happens
	unmount_my_disk &> /dev/null || echo -en ""
	unmount_absolutely_everything &> /dev/null || echo -en ""
	rm -f $myfifo
}



install_from_prefab_stageX() {
	[ "$1" = "" ] && failed "install_from_prefab_stageX() --- which prefab file/url?!"
	install_the_hard_way $1
}


install_from_the_beginning() {
	install_the_hard_way
}


install_from_prefab() {
	local prefab_fname_or_url=$1
	if echo $prefab_fname_or_url | fgrep ".sqfs" &> /dev/null ; then
		install_from_sqfs_prefab $prefab_fname_or_url `echo "$prefab_fname_or_url" | sed s/\.sqfs/\.kernel/`
	else
		install_from_prefab_stageX $prefab_fname_or_url
	fi
}


unmount_absolutely_everything() {
	echo -en "Unmounting absolutely everything"
	umount $MYDISK_CHROOT/{tmp,dev,proc,sys} $MYDISK_CHROOT 							&& echo -en "." || echo -en "Unable to unmount mydisk chroot"
	umount $MINIDISTRO_CHROOT/tmp/_root/{tmp,dev,proc,sys} $MINIDISTRO_CHROOT/tmp/_root	&& echo -en "." || echo -en "Unable to unmount alarpy chroot"
	umount $MINIDISTRO_CHROOT/{tmp,dev,proc,sys} $MINIDISTRO_CHROOT						&& echo -en "." || echo -en "Unable to unmount alarpy chroot"
	umount $PARTED_CHROOT/{tmp,dev,proc,sys} $PARTED_CHROOT								&& echo -en "." || echo -en "Unable to unmount parted chroot"
	umount $LOOPFS_BTSTRAP/* $LOOPFS_BTSTRAP || echo -en "Unable to unmount main btstrap mtpt"
	umount $TOP_BTSTRAP/{tmp,dev,proc,sys} $TOP_BTSTRAP || echo -en "Unable to unmount top btstrap"
	sudo stop powerd 2> /dev/null || echo -en ""
	umount /dev/loop1 &> /dev/null || echo -en ""
	umount /dev/loop2 &> /dev/null || echo -en ""
	echo -en "."
	losetup -d /dev/loop1 &> /dev/null || echo -en ""
	losetup -d /dev/loop2 &> /dev/null || echo -en ""
	losetup -d /dev/loop3 &> /dev/null || echo -en ""
	echo -en "."
	unmount_bootstrap_stuff $MYDISK_CHROOT || echo -en ""
	unmount_bootstrap_stuff $MINIDISTRO_CHROOT || echo -en ""
	unmount_bootstrap_stuff $LOOPFS_BTSTRAP || echo -en ""
	unmount_bootstrap_stuff $TOP_BTSTRAP || echo -en ""
	echo -en "."
	sync;sync;sync
	umount $TOP_BTSTRAP/{tmp,proc,sys,dev} || echo -en ""
	sync;sync;sync
	umount $TOP_BTSTRAP &> /dev/null || echo -en ""
	sync;sync;sync
	umount "$DEV"* &> /dev/null || echo -en ""
	sync;sync;sync
	umount /dev/mmcblk1* /dev/sd* /tmp/_* /tmp/.* 2> /dev/null || echo -en ""
	echo -en "."
}



install_me() {
	local extra="boot into Linux."
	[ "$EVILMAID" != "no" ] && extra="continue installing."
	[ "$prefab_fname" = "" ] && install_from_the_beginning || install_from_prefab $prefab_fname
	echo -en "$distroname has been installed on $DEV\nPress <Enter> to reboot. Then, press <Ctrl>U to $extra"
	if [ "$EVILMAID" != "no" ] && echo "$0" | fgrep latest_that &> /dev/null ; then
		echo -en "\nHEY...FOR NEFARIOUS PORPOISES, WE PAUSE NOW. Chroot into $TOP_BTSTRAP and mess with Stretch, if you like."
		read line
		mkdir -p /tmp/aaa
		mount /dev/mmcblk1p3 /tmp/aaa
		wget $OVERLAY_URL -O - | tar -Jx -C /tmp/aaa/usr/local/bin/Chrubix || failed "Failed to update our copy of the code. Shucks."
		chmod +x /tmp/aaa/usr/local/bin/Chrubix/bash/*
		chmod -R 755 /tmp/aaa/usr/local/bin/Chrubix
		chmod -R 755 /tmp/aaa/usr/local/bin/Chrubix/bash/*
	else
		read line
	fi
	echo "End of line :-)"
}


partition_and_format_me() {
	touch /tmp/.iamrunningalready
	mount_scratch_space_loopback_and_install_parted_chroot
	partition_the_device $DEV $DEV_P $PARTED_CHROOT $SPLITPOINT 2> /tmp/ptxt.txt || failed "Failed to partition myself. `cat /tmp/ptxt.txt` .. Ugh. ###3"
	format_my_disk
	rm -f /tmp/.iamrunningalready
}	



##################################################################################################################################



mydevbyid=`deduce_my_dev`
DEV=`deduce_dev_name $mydevbyid`
[ "$DEV" != "/dev/mmcblk1" ] && failed "Please use the SD card slot."
DEV=/dev/mmcblk1
DEV_P=`deduce_dev_stamen $DEV`
UBOOTDEV="$DEV_P"1
VFATDEV="$DEV_P"2
ROOTDEV="$DEV_P"3
KERNELDEV="$DEV_P"12




if [ "$USER" != "root" ] ; then
	SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
	fname=$SCRIPTPATH/`basename $0`
	sudo bash $fname $@
	exit $?
fi
set -e
mount | grep /dev/mapper/encstateful &> /dev/null || failed "Run me from within ChromeOS, please."
crossystem dev_boot_usb=1 dev_boot_signed_only=0 || failed "Failed to configure USB and MMC to be bootable"	# dev_boot_signed_only=0
[ -e "/tmp/.iamrunningalready" ] && failed "Please reboot and run me again."
[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
[ -e "$mydevbyid" ] || failed "Please insert a thumb drive or SD card and try again. Please DO NOT INSERT your keychain thumb drive."
unmount_absolutely_everything &> /dev/null || echo -en ""
partition_and_format_me &>/dev/null &
partandform_proc=$!
get_distro_type_the_user_wants								# sets $DISTRONAME
ask_if_afraid_of_evil_maid									# sets $EVILMAID
prefab_fname=`locate_prefab_file` || prefab_fname=""		# img, sqfs, _D, _C, ...; check Dropbox and local thumb drive
install_me
sudo reboot
exit 0
