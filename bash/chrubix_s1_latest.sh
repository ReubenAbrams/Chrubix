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
OVERLAY_URL=https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz
RYO_TEMPDIR=/root/.rmo
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
LOGLEVEL=2
TEMP_OR_PERM=temp
SPLITPOINT=3300998	# 1.7GB
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

if [ "$USER" != "root" ] ; then
	SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
	fname=$SCRIPTPATH/`basename $0`
	sudo bash $fname $@
	exit $?
fi
set -e
mount | grep /dev/mapper/encstateful &> /dev/null || failed "Run me from within ChromeOS, please."


# PARTED_CHROOT is mounted on the internal loopfs
# MINIDISTRO_CHROOT and its files are actually *living on* MYDISK_CHROOT/.alarpy
# /dev/mmcblk1p2 is mounted at /tmp/_build_here 				 a.k.a. $TOP_BTSTRP
# The mini-distro lives here:  /tmp/_build_here/.alarpy  		 a.k.a. $MINIDISTRO_CHROOT
# The actual dest distro is at /tmp/_build_here/.alarpy/.mnydisk a.k.a. $MYDISK_CHROOT


failed() {
	echo "$1" >> /dev/stderr
	exit 1
}


pause_then_reboot() {
	sudo start powerd || echo -en ""
	echo -en "$distroname has been installed on $DEV\nPress <Enter> to reboot. Then, press <Ctrl>U to boot into Linux."
	read line
	sudo reboot
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


make_sure_mkfs_code_was_successfully_modified() {
	local look_for_me dirname
	for look_for_me in \"_BHRfS_M\" 4D5F53665248425F \"JFS1\" 3153464a \"XAGF\" 58414746 ; do
		for dirname in $1/*fs*/*fs* ; do
#			echo "Searching $dirname for $look_for_me"
			fgrep --include='*.h' --include='*.c' -r "$look_for_me" $dirname && failed "Found $look_for_me still present in $1 sources." || echo -en ""
		done
	done		
	cd /
#	echo "FYI, make_sure_mkfs_code_was_successfully_modified() says the code WAS modified OK."
}



save_current_partitions_layout() {
	local dev outstub lastblock
	dev=$1
	outstub=$2

	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	dd if=$dev bs=16 count=$((0x9d)) of="$outstub".A.dat 2> /dev/null
	dd if=$dev skip=$lastblock of="$outstub".B.dat 2>/dev/null
	cgpt show $dev > "$outstub".cgpt.show.txt
}


restore_partitions_layout() {
	local dev outstub lastblock
	dev=$1
	outstub=$2
	
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	dd if="$outstub".A.dat of=$dev 2> /dev/null
	dd if="$outstub".B.dat | dd seek=$lastblock of=$dev 2> /dev/null
	sync;sync;sync
	chroot_this $btstrap "partprobe $dev"
}


##################################################################################################################################

install_chrubix() {
	local root dev rootdev hiddendev kerndev distro proxy_string mydiskmtpt rr
	root=$1
	dev=$2
	rootdev=$3
	hiddendev=$4
	kerndev=$5
	distroname=$6
	
	echo "install_chrubix() --- root=$root; dev=$dev; rootdev=$rootdev; hiddendev=$hiddendev; kerndev=$kerndev; distroname=$distroname"
	mydiskmtpt=$MYDISK_CHR_STUB
	[ "$mydiskmtpt" = "/`basename $mydiskmtpt`" ] || failed "install_chrubix() -- $mydiskmtpt must not have any subdirectories. It must BE a directory and a / one at that."
	mkdir -p $MYDISK_CHROOT
	mount $ROOTDEV $MYDISK_CHROOT || failed "install_chrubix() -- unable to mount root device at $MYDISK_CHROOT"	
	mount_dev_sys_proc_and_tmp $MYDISK_CHROOT
	
	cp -vf $MINIDISTRO_CHROOT/.[a-z]*.txt $MYDISK_CHROOT/
	
	touch $TOP_BTSTRAP/.gloria.first-i-was-afraid
	[ -e "$MYDISK_CHROOT/.gloria.first-i-was-afraid" ] || failed "For some reason, MYDISK_CHROOT and TOP_BTSTRAP don't share the '/' directory."
	
	touch $MINIDISTRO_CHROOT/.gloria.i-was-petrified
	[ -e "$MYDISK_CHROOT/.gloria.i-was-petrified" ] && failed "Why are MINIDISTRO_CHROOT and MYDISK_CHROOT sharing a '/' directory?"

	rm -f $TOP_BTSTRAP/.gloria*
	rm -f $MINIDISTRO_CHROOT/.gloria*
	rm -f $MYDISK_CHROOT/.gloria*
	
#	[ -e "$MINIDISTRO_CHROOT/lib/modules" ] || failed "Why does the mini distro not have a /lib/modules folder"	
	
	rm -Rf $root/usr/local/bin/Chrubix $root/usr/local/bin/1hq8O7s
	lastblock=`cgpt show $DEV | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2` || failed "Failed to calculate lastblock"
	maximum_length=$(($lastblock-$SPLITPOINT-8))
	SIZELIMIT=$(($maximum_length*512))
	
	[ "$SIZELIMIT" != "" ] || failed "Set SIZELIMIT before calling install_chrubix(), please."
	[ "$WGET_PROXY" != "" ] && proxy_info="export http_proxy=$WGET_PROXY; export ftp_proxy=$WGET_PROXY" || proxy_info=""
	wget $CHRUBIX_URL -O - | tar -xz -C $root/usr/local/bin 2> /dev/null
	mv $root/usr/local/bin/Chrubix* $root/usr/local/bin/Chrubix	# rename Chrubix-master (or whatever) to Chrubix
	wget $OVERLAY_URL -O - | tar -Jx -C $root/usr/local/bin/Chrubix 2> /dev/null || echo "Sorry. Dropbox is down. We'll have to rely on GitHub..."
	
	for rr in $root$MYDISK_CHR_STUB $root; do
		[ -d "$rr" ] || failed "install_chrubix() -- $rr does not exist. BummeR."
		for f in chrubix.sh greeter.sh ersatz_lxdm.sh CHRUBIX redo_mbr.sh modify_sources.sh ; do
			ln -sf Chrubix/bash/$f $rr/usr/local/bin/$f || echo "Cannot do $f softlink"
		done
	done
	cd $root/usr/local/bin/Chrubix/bash
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
> chrubix.sh || failed "Failed to rejig chrubix.sh.orig"

	cd /
	[ -e "$root/usr/local/bin/Chrubix" ] || failed "Where is $root/usr/local/bin/Chrubix?"
}


call_chrubix() {
	local btstrap
	btstrap=$1

	tar -cz /usr/lib/xorg/modules/drivers/armsoc_drv.so \
		/usr/lib/xorg/modules/input/cmt_drv.so /usr/lib/libgestures.so.0 \
		/usr/lib/libevdev* \
		/usr/lib/libbase*.so \
		/usr/lib/libmali.so* \
		/usr/lib/libEGL.so* \
		/usr/lib/libGLESv2.so* > $btstrap/tmp/.hipxorg.tgz 2>/dev/null || failed "Failed to save old drivers"
	tar -cz /usr/bin/vbutil* /usr/bin/futility > $btstrap/tmp/.vbtools.tgz
	tar -cz /usr/share/vboot > $btstrap/tmp/.vbkeys.tgz || failed "Failed to save your keys" #### MAKE SURE CHRUBIX HAS ACCESS TO Y-O-U-R KEYS and YOUR vbutil* binaries ####
	tar -cz /lib/firmware > $btstrap/tmp/.firmware.tgz || failed "Failed to save your firmware"  # save firmware!
	chroot_this $btstrap "chmod +x /usr/local/bin/*"
	echo "$TEMP_OR_PERM" > $btstrap/.TEMP_OR_PERM.txt
	ln -sf ../../bin/python3 $btstrap/usr/local/bin/python3
	echo "************ Calling CHRUBIX, the Python powerhouse of pulchritudinous perfection ************"
	echo "yep, use latest" > $root/tmp/.USE_LATEST_CHRUBIX_TARBALL
	[ -e "$btstrap/usr/local/bin/Chrubix" ] || failed "Where is $btstrap/usr/local/bin/Chrubix? #1"	
	[ -e "$MINIDISTRO_CHROOT/usr/local/bin/Chrubix" ] || failed "Where is $MINIDISTRO_CHROOT/usr/local/bin/Chrubix? #2"
	
#	failed "NEFARIOUS CORPUSCLES"
	chroot_this $btstrap "/usr/local/bin/chrubix.sh" || failed "Because chrubix reported an error, I'm aborting... and I'm leaving everything mounted.
Type 'sudo chroot $MINIDISTRO_CHROOT' and then 'chrubix.sh' to retry."
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
#	cgpt repair $dev || echo -en ""
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
#	cgpt repair $dev || failed "Failed to update/clean/repair $dev's MBRs"
	chroot_this $btstrap "partprobe $dev"
#	cgpt repair $dev || failed "Failed to update/clean/repair $dev's MBRs"
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
	RETVAL=""
	url=""
	while [ "$distroname" = "" ] ; do
		clear
# NOT SUPPORTED: (F)edora, (S)uSE 12.3
		echo -en "Welcome to the Chrubix installer. Which GNU/Linux distro shall I install on $dev?

Choose from...

   (A)rchLinux <== ArchLinuxArm's make package is broken. It keeps segfaulting.
   (F)edora 19
   (S)tretch, a.k.a. Debian Testing
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





locate_prefab_file() {
	local mypath
	mypath=/tmp/prefab_thumb_drive
	mkdir -p $mypath
#	echo "Trying to mount" > /dev/stderr
	if ! mount | fgrep "$mypath" &> /dev/null ; then
		if ! mount /dev/sda1 $mypath 2> /dev/null ; then
			if ! mount /dev/sdb1 $mypath 2> /dev/null ; then
				echo -en ""
			fi
		fi
	fi
#	echo "Trying to find" > /dev/stderr
	if mount | fgrep "$mypath" &> /dev/null ; then
#		echo "Checking thumb drive" > /dev/stderr	
		locate_prefab_on_thumbdrive $mypath
	else
#		echo "Checking dropbox" > /dev/stderr
		locate_prefab_on_dropbox
		return $?
	fi
	return $?
}


locate_prefab_on_dropbox() {
	local img_url sqfs_url stageD_url url
	img_url=$FINALS_URL/$DISTRONAME/$DISTRONAME".img.gz"
	sqfs_url=$FINALS_URL/$DISTRONAME/$DISTRONAME".sqfs"
	stageD_url=$FINALS_URL/$DISTRONAME/$DISTRONAME"__D.xz"
	for url in $img_url $sqfs_url $stageD_url ; do
		if wget --spider $url -O /dev/null 2> /dev/null ; then
			echo "$url"
			return 0
		fi
	done
	return 1
}


locate_prefab_on_thumbdrive() { 
	local mypath img_fname sqfs_fname fname stageD_fname stageC_fname stageB_fname stageA_fname
	mypath=$1
	img_fname=$mypath/$DISTRONAME/$DISTRONAME".img.gz"
	sqfs_fname=$mypath/$DISTRONAME/$DISTRONAME".sqfs"
	stageD_fname=$mypath/$DISTRONAME/$DISTRONAME"__D.xz"
	stageC_fname=$mypath/$DISTRONAME/$DISTRONAME"__C.xz"
	stageB_fname=$mypath/$DISTRONAME/$DISTRONAME"__B.xz"
	stageA_fname=$mypath/$DISTRONAME/$DISTRONAME"__A.xz"
	for fname in $img_fname $sqfs_fname $stageD_fname $stageC_fname $stageB_fname $stageA_fname ; do
#		echo "Trying $fname" > /dev/stderr
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
		echo -en "Thinking..."
		umount $LOOPFS_BTSTRAP 2> /dev/null || echo -en ""
		mkdir -p $LOOPFS_BTSTRAP
		losetup -d /dev/loop1 &> /dev/null || echo -en ""
		dd if=/dev/zero of=$loopfile bs=1024k count=128 2> /dev/null
		losetup /dev/loop1 $loopfile
		mke2fs /dev/loop1 &> /dev/null || failed "Failed to mkfs the temp loop partition"
		mount /dev/loop1 $LOOPFS_BTSTRAP || failed "Failed to loopmount /dev/loop1 at $LOOPFS_BTSTRAP"
	fi
}


install_parted_chroot() {
	if [ ! -f "/home/chronos/user/Downloads/.bt.tar.xz" ] ; then
		wget $PARTED_URL -O - > /home/chronos/user/Downloads/.bt.tar.xz || failed "Failed to download/install parted and friends"
	fi
	mkdir -p $PARTED_CHROOT
	tar -Jxf /home/chronos/user/Downloads/.bt.tar.xz -C $PARTED_CHROOT/
	mkdir -p $PARTED_CHROOT/{dev,sys,proc,tmp}
	mount devtmpfs  $PARTED_CHROOT/dev -t devtmpfs	|| echo -en ""
	mount sysfs     $PARTED_CHROOT/sys -t sysfs		|| echo -en ""
	mount proc      $PARTED_CHROOT/proc -t proc		|| echo -en ""
	mount tmpfs     $PARTED_CHROOT/tmp -t tmpfs		|| echo -en ""
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
	echo -en ".Done."
}


mount_my_disk() {
	mkdir -p $TOP_BTSTRAP $VFAT_MOUNTPOINT
	mount $VFATDEV $VFAT_MOUNTPOINT || failed "mount_my_disk() -- unable to mount p2"
	if cgpt show $DEV | tr -s '\t' ' ' | fgrep " 3 Label" &> /dev/null ; then
		mount $MOUNT_OPTS $ROOTDEV $TOP_BTSTRAP || failed "mount_my_disk() -- unable to mount p3"
	fi
}


install_microdistro() {
	cd /
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
	sudo crossystem dev_boot_usb=1 dev_boot_signed_only=0 || echo "WARNING - failed to configure USB and MMC to be bootable"	# dev_boot_signed_only=0
	install_chrubix $MINIDISTRO_CHROOT $DEV $ROOTDEV $VFATDEV $KERNELDEV $DISTRONAME
	call_chrubix $MINIDISTRO_CHROOT || failed "call_chrubix() returned an error. Failing."
	cp -vf $MYDISK_CHROOT/.*.txt $VFAT_MOUNTPOINT/ || failed "install_and_call_chrubix() -- failed to copy cool stuff to vfat partition"
	[ -f "$MYDISK_CHROOT/.kernel.dat" ] || failed "install_and_call_chrubix() -- no kernel!"
	[ -f "$MYDISK_CHROOT/.squashfs.sqfs" ] || failed "install_and_call_chrubix() -- no sqfs!"
}


mount_dev_sys_proc_and_tmp() {
	mkdir -p $1/{dev,sys,proc,tmp}
	mount devtmpfs  $1/dev -t devtmpfs
	mount sysfs     $1/sys -t sysfs		
	mount proc      $1/proc -t proc		
	mount tmpfs     $1/tmp -t tmpfs
}


restore_this_prefab() {
	local prefab_fname_or_url=$1
	cd /
	echo "Restoring..."
	[ -e "$TOP_BTSTRAP/bin/date" ] && failed "restore_this_prefab() -- haven't you called me once already?"
	mkdir -p $TOP_BTSTRAP/{dev,sys,proc,tmp}
	echo "Unzipping $prefab_fname_or_url"
	if echo "$prefab_fname_or_url" | fgrep http &> /dev/null ; then
		wget $prefab_fname_or_url -O - | tar -Jx -C $TOP_BTSTRAP
	else
		[ -e "$prefab_fname_or_url" ] || failed "restore_this_prefab() -- $prefab_fname_or_url does not exist"
		pv $prefab_fname_or_url | tar -Jx -C $TOP_BTSTRAP || failed "restore_this_prefab() -- Failed to unzip $fname --- J err?"
	fi

	[ -e "$TOP_BTSTRAP/bin/date" ] || failed "restore_this_prefab() -- you say you've restored from a Stage X file... but where's the date binary? #1"
	[ -e "$MINIDISTRO_CHROOT" ] || failed "Prefab file $prefab_fname_or_url did not contain an .alarpy folder; that is odd. It should have been backed up."
	mount_dev_sys_proc_and_tmp $MINIDISTRO_CHROOT || failed "restore_this_prefab() -- failed to mount dev, sys, etc. on $MINIDISTRO_CHROOT"
	mkdir -p $MYDISK_CHROOT

# So, at this point:-
# - partition #2 of SD card is mounted   at $TOP_BTSTRAP
# - the .alarpy folder should be present at $TOP_BTSTRAP/.alarpy (a.k.a. $MINIDISTRO_CHROOT)
# - I can chroot into .alarpy and build the rest of the OS at $MKDISK_CHROOT (which is bindmounted to $TOP_BTSTRAP)
	
	echo "9999"                > $MINIDISTRO_CHROOT/.checkpoint.txt 	|| echo "BLAH 1"
	echo "$prefab_fname_or_url" > $MINIDISTRO_CHROOT/.url_or_fname.txt 	|| echo "BLAH 2"
}


sign_and_install_kernel() {
	local sqfs_fname=$VFAT_MOUNTPOINT/.squashfs.sqfs
	local kernel_fname=$VFAT_MOUNTPOINT/.kernel.dat
	[ -d "$VFAT_MOUNTPOINT" ] || failed "sign_and_install_kernel() -- where is vfat mountpoint?"
	mount | fgrep " $VFAT_MOUNTPOINT " &> /dev/null || failed "sign_and_install_kernel() -- why is vfat mountpoint not mounted?"
	[ -f "$sqfs_fname" ] || failed "sign_and_install_kernel() -- where is the sqfs file?"
	[ -f "$kernel_fname" ] || failed "sign_and_install_kernel() -- where is the kernel?"

	rm -f $MYDISK_CHROOT/.checkpoint.txt
	rm -f $VFAT_MOUNTPOINT/.checkpoint.txt
	rm -f $MINIDISTRO_CHROOT/.checkpoint.txt
	
#	mkdir -p $MYDISK_CHROOT/.ro

	# try ROOTDEV instead of VFATDEV?
	sign_and_write_custom_kernel $MYDISK_CHROOT $UBOOTDEV $VFATDEV $kernel_fname "" ""  || failed "sign_and_install_kernel() -- failed to sign/write custom kernel"
}



delete_p3_if_it_exists() {
	sync;sync;sync
	if cgpt show $DEV | tr -s '\t' ' ' | fgrep " 3 Label" &> /dev/null ; then
		echo -en "Deleting p3..."
		umount $ROOTDEV || echo -en ""
		mount | fgrep " $ROOTDEV" && failed "delete_p3_if_it_exists() -- p3 is still mounted!"
		if [ ! -e "$PARTED_CHROOT/bin/parted" ] ; then
			mount_scratch_space_loopback
			install_parted_chroot
		fi
		[ -e "$PARTED_CHROOT/bin/parted" ] || failed "delete_p3_if_it_exists() -- failed to prep loopback parted thingy"
		chroot_this $PARTED_CHROOT "echo -en \"rm 3\\nq\\n\" | parted $DEV" || failed "Failed to delete p3"
		sync;sync;sync
		chroot_this $btstrap "partprobe $DEV"
	fi
	sync;sync;sync
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


yes_save_IMG_file_for_posterity() {
	local output_imgfile last_sector_of_p2 lsop start length gohere cksumhere
	output_imgfile=$1

	echo -en "So...."
	start=`cgpt show $DEV | tr -s '\t' ' ' | fgrep " 2 Label" | cut -d' ' -f2`
	length=`cgpt show $DEV | tr -s '\t' ' ' | fgrep " 2 Label" | cut -d' ' -f3`
	cksumhere=$(($start+$length))
	if [ "$cksumhere" -lt "$SPLITPOINT" ] ; then
		echo "WARNING --- I think the splitpoint *is* at $cksumhere but it *should be* at $SPLITPOINT"
		echo "Therefore, I am bumping ckusmhere up and making it equal $SPLITPOINT"
		cksumhere=$SPLITPOINT
	fi
	gohere=$(($cksumhere+1))

	mount | grep "$DEV" && failed "yes_save_output_imgfile_for_posterity() -- please unmount $DEV etc. before proceeding #1"
	delete_p3_if_it_exists
	mount | grep "$DEV" && failed "yes_save_output_imgfile_for_posterity() -- please unmount $DEV etc. before proceeding #2"	
	
	wipe_spare_space_in_partition $VFATDEV
	echo "cksumhere = $cksumhere"
	
	losetup -d /dev/loop6 &> /dev/null || echo -en ""
#	dd if=/dev/zero  of=$DEV seek=$cksumhere count=100k &> /dev/null || echo "yes_save_output_imgfile_for_posterity() -- failed to wipe old p3"
#	dd if=/dev/zero  of=$DEV seek=$cksumhere count=1 2>/dev/null || failed "yes_save_output_imgfile_for_posterity() -- dd 1 failed" 
#	echo "none" | dd of=$DEV seek=$cksumhere count=1 2>/dev/null || failed "yes_save_output_imgfile_for_posterity() -- dd 2 failed"
#	losetup /dev/loop6 -o $(($gohere*512)) $DEV
#	mkdir /tmp/quacky
#	yes | mkfs.ext4 -v /dev/loop6 &> /dev/null || failed "yes_save_output_imgfile_for_posterity() -- failed to format /dev/loop6"
#	mount /dev/loop6 /tmp/quacky
##cryptsetup luksOpen /dev/loop6 hiddensausage
#	echo "`date` --- hi there from yes_save_output_imgfile_for_posterity()" > /tmp/quacky/.hi.txt
#	umount /tmp/quacky
	
	echo "Saving image of $DEV ==> $output_imgfile"
	pv $DEV | dd count=$gohere 2> /dev/null | gzip -1 > "$output_imgfile".TEMP || failed "yes_save_output_imgfile_for_posterity() -- failed to save image $output_imgfile"
	echo -en "Done."
	mv -f "$output_imgfile".TEMP $output_imgfile
	echo ""
}




# Enable this to delete the now-unused p3 partition.
#	chroot_this $PARTED_CHROOT "echo -en \"rm 3\nq\n\" | parted $DEV" &> /tmp/ptxt.txt || echo "Warning --- Failed to delete partition #3 --- `cat /tmp/ptxt.txt`"

save_IMG_file_for_posterity_if_possible() {
	local dirname_of_posterity_thumb_drive_path img_file
	dirname_of_posterity_thumb_drive_path=/tmp/pot_img_save_place/
	mkdir -p $dirname_of_posterity_thumb_drive_path 						|| echo -en ""
	mount /dev/sda1 $dirname_of_posterity_thumb_drive_path 2> /dev/null 	|| echo -en ""
	if [ -e "$dirname_of_posterity_thumb_drive_path/$DISTRONAME" ] ; then
		img_file=$dirname_of_posterity_thumb_drive_path/$DISTRONAME/$DISTRONAME.img.gz
		yes_save_IMG_file_for_posterity $img_file							|| failed "save_IMG_file_for_posterity_if_possible() -- failed to yes_save_IMG_file_for_posterity. Darn." 
	fi
	umount $dirname_of_posterity_thumb_drive_path 2> /dev/null 				|| echo -en ""
}


install_the_hard_way() {
	mount_scratch_space_loopback
	install_parted_chroot
	partition_the_device $DEV $DEV_P $PARTED_CHROOT $SPLITPOINT 2> /tmp/ptxt.txt || failed "Failed to partition myself. `cat /tmp/ptxt.txt` .. Ugh. ###3"
	format_my_disk
	mount_my_disk
	[ "$1" = "" ] && install_microdistro || restore_this_prefab $1
	install_and_call_chrubix
	sign_and_install_kernel
	unmount_my_disk &> /dev/null || echo -en ""
}


install_from_prefab_img() {
	local kernel_fname=/tmp/.my.kernel.dat prefab_fname_or_url=$1 kernel_fname_or_url=`echo $1 | sed s/\.img\.gz/\.kernel/`
	mount | fgrep $DEV 2> /dev/null && failed "install_from_prefab_img() -- some partitions are already mounted. Unmount them first, please."
	echo "Installing prefab image ($prefab_fname_or_url)..."
	if echo "$prefab_fname_or_url" | fgrep http &> /dev/null ; then
		wget $prefab_fname_or_url -O - | gunzip -dc > $DEV
		wget $kernel_fname_or_url -O - > $kernel_fname
	else
		pv $prefab_fname_or_url | gunzip -dc > $DEV  || failed "Failed to save $prefab_fname_or_url --- K err?"
		pv $kernel_fname_or_url > $kernel_fname     || failed "Failed to save $kernel_fname_or_url --- L err?"
	fi
	
#	if [ ! -e "$PARTED_CHROOT/bin/parted" ] ; then
#		mount_scratch_space_loopback
#		install_parted_chroot
#	fi	
#	chroot_this $PARTED_CHROOT "partprobe $dev"
#	sync;sync;sync
	
	if [ ! -e "$VFATDEV" ] ; then
		mknod $VFATDEV b 179 66 || failed "install_from_prefab_img() -- failed to create p2 node."
	fi

	sign_and_write_custom_kernel $MYDISK_CHROOT $UBOOTDEV $VFATDEV $kernel_fname "" ""  || failed "install_from_prefab_img() -- failed to sign/write custom kernel"

#	mount_my_disk
#	sign_and_install_kernel || failed "install_from_prefab_img() -- failed to sign and install kernel"
#	unmount_my_disk &> /dev/null || echo -en ""

	unmount_absolutely_everything &> /dev/null || echo -en ""
	pause_then_reboot
}


install_from_prefab_sqfs() {
	local prefab_fname_or_url=$1
	local kernel_fname_or_url=$2
	mount_scratch_space_loopback
	install_parted_chroot

	mount | fgrep "$DEV" && failed "partition_my_disk() --- stuff from $DEV is already mounted. Abort!" || echo -en ""
	partition_the_device $DEV $DEV_P $PARTED_CHROOT $SPLITPOINT yes 2> /tmp/ptxt.txt || failed "Failed to partition myself. `cat /tmp/ptxt.txt` .. Ugh. ###3"
	format_my_disk
	mount_my_disk
	echo "Restoring from $prefab_fname_or_url and .../`basename $kernel_fname_or_url`"
	if echo "$prefab_fname_or_url" | fgrep http &> /dev/null ; then
		wget $prefab_fname_or_url -O - > $VFAT_MOUNTPOINT/.squashfs.sqfs || failed "install_from_prefab_sqfs() -- Unable to download $prefab_fname_or_url"
		wget $kernel_fname_or_url -O - > $VFAT_MOUNTPOINT/.kernel.dat || failed "install_from_prefab_sqfs() -- Unable to download $kernel_fname_or_url"
	else
		pv $prefab_fname_or_url  > $VFAT_MOUNTPOINT/.squashfs.sqfs || failed "install_from_prefab_sqfs() -- Failed to save $prefab_fname_or_url --- L err?"
		cp -f $kernel_fname_or_url $VFAT_MOUNTPOINT/.kernel.dat || failed "install_from_prefab_sqfs() -- Failed to save $kernel_fname_or_url --- L err?"
	fi
	sign_and_install_kernel
	unmount_my_disk &> /dev/null || echo -en ""
}


install_from_prefab_stageX() {
	[ "$1" = "" ] && failed "install_from_prefab_stageX() --- which prefab file/url?!"
	echo "Installing prefab stage X ($1)..."
	install_the_hard_way $1
}


install_from_the_beginning() {
	install_the_hard_way
	unmount_absolutely_everything &> /dev/null || echo -en ""
	save_IMG_file_for_posterity_if_possible
	pause_then_reboot	
}


install_from_prefab() {
	local prefab_fname_or_url=$1
	if echo $prefab_fname_or_url | fgrep ".img" &> /dev/null ; then
		install_from_prefab_img $prefab_fname_or_url
	elif echo $prefab_fname_or_url | fgrep ".sqfs" &> /dev/null ; then
		install_from_prefab_sqfs $prefab_fname_or_url `echo "$prefab_fname_or_url" | sed s/\.sqfs/\.kernel/`
	else
		install_from_prefab_stageX $prefab_fname_or_url
	fi
}


unmount_absolutely_everything() {
	echo -en "Unmounting absolutely everything"
	umount $MYDISK_CHROOT/{tmp,dev,proc,sys} $MYDISK_CHROOT || echo -en "Unable to unmount mydisk chroot"
	echo -en "."
	umount $MINIDISTRO_CHROOT/tmp/_root/{tmp,dev,proc,sys} $MINIDISTRO_CHROOT/tmp/_root || echo -en "Unable to unmount alarpy chroot"
	echo -en "."
	umount $MINIDISTRO_CHROOT/{tmp,dev,proc,sys} $MINIDISTRO_CHROOT || echo -en "Unable to unmount alarpy chroot"
	echo -en "."
	umount $PARTED_CHROOT/{tmp,dev,proc,sys} $PARTED_CHROOT || echo -en "Unable to unmount parted chroot"
	echo -en "."
	umount $LOOPFS_BTSTRAP/* $LOOPFS_BTSTRAP || echo -en "Unable to unmount main btstrap mtpt"
	umount $TOP_BTSTRAP/{tmp,dev,proc,sys} $TOP_BTSTRAP || echo -en "Unable to unmount top btstrap"
	echo -en "."
	echo "$TEMP_OR_PERM" > /tmp/TEMP_OR_PERM
	echo -en "."
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
	umount $TOP_BTSTRAP/{tmp,proc,sys,dev} $TOP_BTSTRAP || echo -en ""
	umount "$DEV"* &> /dev/null || echo -en ""
	umount /dev/mmcblk1* /dev/sd* /tmp/_* /tmp/.* 2> /dev/null || echo -en ""
	echo -en "."
}


##################################################################################################################################



mydevbyid=`deduce_my_dev`
DEV=`deduce_dev_name $mydevbyid`
DEV_P=`deduce_dev_stamen $DEV`
UBOOTDEV="$DEV_P"1
VFATDEV="$DEV_P"2
ROOTDEV="$DEV_P"3
KERNELDEV="$DEV_P"12
ROOTMOUNT=/tmp/_root.`basename $DEV`
BOOTMOUNT=/tmp/_boot.`basename $DEV`	
KERNMOUNT=/tmp/_kern.`basename $DEV`
mkdir -p $ROOTMOUNT $BOOTMOUNT $KERNMOUNT





#DISTRONAME=debianwheezy
#echo "Unmounting absolutely everything, just in case."
#unmount_absolutely_everything &> /dev/null || echo -en ""
#echo "Saving IMG file for infernal test porpoises"
#save_IMG_file_for_posterity_if_possible
#exit 0





# FYI...
# $DEV 		is typically /dev/mmcblk1
# $DEV_P 	is typically /dev/mmcblk1p
# UBOOTDEV	is typically /dev/mmcblk1p1
# ROOTDEV	is typically /dev/mmcblk1p3
# KERNELDEV is typically /dev/mmcblk1p12
# ROOTMOUNT	is typically /tmp/_root.mmcblk1

[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
[ -e "$mydevbyid" ] || failed "Please insert a thumb drive or SD card and try again. Please DO NOT INSERT your keychain thumb drive."
unmount_absolutely_everything &> /dev/null || echo -en ""
get_distro_type_the_user_wants		# sets $DISTRONAME
prefab_fname=`locate_prefab_file` || prefab_fname=""		# img, sqfs, _D, _C, ...; check Dropbox and local thumb drive
[ "$prefab_fname" = "" ] && install_from_the_beginning || install_from_prefab $prefab_fname
echo "YOU SHOULD NOT REACH THIS LINE"
exit 1
