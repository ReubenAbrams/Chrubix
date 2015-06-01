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



if [ "$USER" != "root" ] ; then
	SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
	fname=$SCRIPTPATH/`basename $0`
	sudo bash $fname $@
	exit $?
fi




ALARPY_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/alarpy.tar.xz"
PARTED_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/parted_and_friends.tar.xz"
echo "$0" | fgrep latest_that &> /dev/null || FINALS_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/finals"
CHRUBIX_URL="http://github.com/ReubenAbrams/Chrubix/archive/master.tar.gz"
OVERLAY_URL=https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz
RYO_TEMPDIR=/root/.rmo
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
LOGLEVEL=2
BIG_LOOPFS_FILE=/home/chronos/user/Downloads/.big.loopfs.file.dat

    



#if ifconfig | grep inet | fgrep 192.168.0 &> /dev/null ; then
#	WGET_PROXY="http://192.168.0.106:8080"
#	export http_proxy=$WGET_PROXY
#	export WGET_PROXY=$WGET_PROXY
#fi




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
	local dev dev_p btstrap
	dev=$1
	dev_p=$2
	btstrap=$3

#	clear
	echo -en "Partitioning "$dev"."
	sync;sync;sync; umount $root/{dev/pts,dev,proc,sys,tmp} &> /dev/null || echo -en "."
	sync;sync;sync; umount "$dev_p"* &> /dev/null || echo -en "."
	sync;sync;sync; umount "$dev"* &> /dev/null || echo -en "."
	chroot_this $btstrap "parted -s $dev mklabel gpt" || echo "Warning. Parted was removed from ChromeOS recently. You might have to partition your SD card on your PC or Mac."
	chroot_this $btstrap "cgpt create -z $dev"
	chroot_this $btstrap "cgpt create $dev"
	chroot_this $btstrap "cgpt add -i  1 -t kernel -b  8192 -s 32768 -l U-Boot -S 1 -T 5 -P 10 $dev"
	chroot_this $btstrap "cgpt add -i 12 -t data   -b 40960 -s 32768 -l Script $dev"
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	splitpoint=$(($lastblock/2-1200999))

	chroot_this $btstrap "cgpt add -i  2 -t data   -b 73728 -s `expr $splitpoint - 73728` -l Kernel $dev"
	chroot_this $btstrap "cgpt add -i  3 -t data   -b $splitpoint -s `expr $lastblock - $splitpoint` -l Root $dev"
	chroot_this $btstrap "partprobe $dev"
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
		ln -sf Chrubix/bash/$f $root/usr/local/bin/$f || echo "Cannot do $f softlink"
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
	echo $distroname > $lockfile
}


restore_from_stage_X_backup_if_possible() {
	mkdir -p /tmp/a /tmp/b
	mount /dev/sda1 /tmp/a &> /dev/null || echo -en ""
	mount /dev/sdb1 /tmp/b &> /dev/null || echo -en ""
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
	mount /dev/sda1 /tmp/a &> /dev/null || echo -en ""
	mount /dev/sdb1 /tmp/b &> /dev/null || echo -en ""
	rm -f /tmp/.kernel.dat
	
	fnA=/tmp/a/$distroname/$distroname.sqfs
	fnB=/tmp/b/$distroname/$distroname.sqfs
	for fname in $fnA $fnB ; do
		if [ -e "$fname" ] ; then
			if [ "$temp_or_perm" = "temp" ] ; then
				echo -en "\rCopying squashfs file to / directory of main partition of destination device\n"
				find /tmp/[a,b]/$distroname/$distroname.kernel &> /dev/null || failed "Squashfs file is present but kernel file is not. Boo..."
				pv $fname > $root/.squashfs.sqfs || failed "Failed to copy the squashfs file across."
				cp /tmp/[a,b]/$distroname/$distroname.kernel /tmp/.kernel.dat # FIXME Move into grab_sqfs_kernel_and_install_it()
				grab_sqfs_kernel_and_install_it $distroname $root $dev_p
				return 0
			fi
		fi
	done
	squrl=$FINALS_URL/$distroname/$distroname.sqfs
#	echo "squrl = $squrl"
	if wget --spider $squrl -O - > $root/.squashfs.sqfs &> /dev/null ; then
		if [ "$temp_or_perm" = "temp" ] ; then
			wget $squrl -O - > $root/.squashfs.sqfs && echo "Squashfs file downloaded and installed OK" || failed "Failed to restrieve squashfs file from URL"
			echo "Restored ($distroname, squash fs) from Dropbox"
			grab_sqfs_kernel_and_install_it $distroname $root $dev_p
			return 0
		fi
	else
		echo -en "\r Online squashfs not found. " > /dev/stderr
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
	echo "console=tty1  $extra_params_A root=$rootdev rootwait $readwrite quiet systemd.show_status=0 loglevel=$LOGLEVEL lsm.module_locking=0 init=/sbin/init $extra_params_B" > $old_btstrap/tmp/kernel.flags
	tar -cJ /usr/share/vboot | tar -Jx -C $old_btstrap
	cp -f $vmlinux_path $old_btstrap/tmp/vmlinux.file	
	chroot_this $old_btstrap "vbutil_kernel --pack /tmp/vmlinuz.signed --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 \
--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config /tmp/kernel.flags \
--vmlinuz /tmp/vmlinux.file --arch arm &&" || failed "Failed to sign kernel"
	sync;sync;sync;sleep 1
	dd if=$old_btstrap/tmp/vmlinuz.signed of=$writehere &> /dev/null && echo -en "..." || failed "Failed to write kernel to $writehere"
	echo "OK."
}



grab_sqfs_kernel_and_install_it() {
	local distroname root dev_p 
	distroname=$1
	root=$2
	dev_p=$3
	
	echo "9999" > $root/.checkpoint.txt
	umount /tmp/a /tmp/b &> /dev/null || echo -en ""
	# FYI, $root is mounted on /dev/mmcblk1p3 (or similar).
	mkdir -p $root/.ro
	kernelpath=/tmp/.kernel.dat

	if [ "$SECRET_SQUIRREL_KERNEL" = "on" ] ; then
		rebuild_and_install_kernel___oh_crap_this_might_take_a_while $distroname $root/.squashfs.sqfs $dev_p
	else
		[ -e "$kernelpath" ] || wget $FINALS_URL/$distroname/$distroname.kernel -O - > $kernelpath
		sign_and_write_custom_kernel $root "$dev_p"1 "$dev_p"3 $kernelpath "" ""  || failed "Failed to sign/write custom kernel"
	fi
}


download_kernelrebuilding_skeleton() {
	local buildloc distroname fnA fnB my_command success
	distroname=$1
	buildloc=$2
	if [ -e "$buildloc/PKGBUILDs/core/pacman/makepkg.conf" ] ; then
		echo "Already got the skeleton. Cool."
		return 0
	fi
	echo "Downloading the kernel-rebuilding skeleton to $buildloc ..."
#	rm -Rf $buildloc
	mkdir -p $buildloc
	fnA="/tmp/a/$distroname/"$distroname"_PKGBUILDs.tgz"
	fnB="/tmp/b/$distroname/"$distroname"_PKGBUILDs.tgz"
	success=""
	mkdir -p /tmp/a
	mount /dev/sda1 /tmp/a 2> /dev/null || echo -en ""
	mount /dev/sdb1 /tmp/a 2> /dev/null || echo -en ""
	if pv $fnA | tar -zx -C $buildloc ; then
		echo "Restored skeleton from sda1"
	elif pv $fnB | tar -zx -C $buildloc ; then
		echo "Restored skeleton from sdb1"
	else
		wget $FINALS_URL/$distroname/"$distroname"_PKGBUILDs.tgz -O - | tar -zx -C $buildloc
	fi
	echo "Done."
}	



make_folder_read_writable() {
 	local our_master_folder subfolder_name zipname srcpath
 	our_master_folder=$1
 	subfolder_name=$2
 	srcpath=$our_master_folder$subfolder_name
 	zipname=/tmp/shenanigans.`echo "$srcpath" | tr '/' '_'`.tgz
	echo -en "$subfolder_name..."
	tar -cz $srcpath 2> /dev/null > $zipname || failed "Failed to tar $srcpath"
	mount tmpfs $srcpath -t tmpfs
	tar -zxf $zipname -C /
	rm -f $zipname
}	



prep_loopback_file_for_rebuilding_kernel() {
	if ! losetup /dev/loop2 2>/dev/null | fgrep $BIG_LOOPFS_FILE &> /dev/null; then	
		echo "Creating loopback file for rebuilding the kernel..."
		dd if=/dev/zero bs=1024k count=2200 > $BIG_LOOPFS_FILE 2> /dev/null
		losetup /dev/loop2 $BIG_LOOPFS_FILE
		mke2fs /dev/loop2 &> /dev/null || failed "Failed to mkfs the temp loop partition"
	fi
}



prep_shenanigans_folder() {
	local masterfolder squashfs_file folders
	masterfolder=$1
	squashfs_file=$2
	echo -en "Preparing $masterfolder"
	mkdir -p $masterfolder
# Shenanigans folder => mount squashfs; then mount tmp, dev, etc.
	mount -t squashfs -o loop $squashfs_file $masterfolder
	mount devtmpfs  $masterfolder/dev -t devtmpfs
	mount sysfs     $masterfolder/sys -t sysfs		
	mount proc      $masterfolder/proc -t proc		
	mount tmpfs     $masterfolder/tmp -t tmpfs	
	
	if echo "$masterfolder" | fgrep "/tmp/_root" > /dev/null ; then
		folders="/lib /etc /usr/local /root /usr/local/share/man /sbin /usr/sbin"
	else
		folders="/root /etc /usr/local/bin"
	fi
	for f in $folders ; do
		make_folder_read_writable $masterfolder $f
	done

	echo "Done."
}


unmount_shenanigans() {
	local f q
	for q in 1 2 3 ; do
		for f in `mount | sort -r | fgrep $1 | cut -d' ' -f3`; do
			umount $f &> /dev/null || echo -en ""
		done
		chroot $1/tmp/_root "umount /sys /proc /tmp /dev" &> /dev/null || echo -en ""
		umount $1/{sys,proc,tmp,dev} &> /dev/null || echo -en ""
		umount $1/{sys,proc,tmp,dev} &> /dev/null || echo -en ""
		umount $1/tmp/_root &> /dev/null || echo -en ""
		umount $1 &> /dev/null || echo -en ""
	done
#	umount $1/tmp/_root/root/.rmo || echo -en ""
#	umount $1/tmp/_root || echo -en ""
	mount | fgrep $1 && failed "Failed to unmount all shenanigans"
}



make_sure_mkfs_code_was_successfully_modified() {
	cd $1/btrfs*/btrfs*/
	fgrep 65248425 *.h && failed "BTRFS magic# still present in sources!" || echo -en ""
	cd $1/xfs*/xfs*/
	fgrep 58465342 */*.h && failed "XFSB magic# still present in sources!" || echo -en ""
	cd $1/jfs*/jfs*/
	fgrep JFS1 */*.h && failed "JFS magic# still present in sources!" || echo -en ""
	cd /
	echo "FYI, make_sure_mkfs_code_was_successfully_modified() says the code WAS modified OK."
}



rebuild_and_install_kernel___oh_crap_this_might_take_a_while() {
	local distroname sqfs_file dev_p url squrl buildloc our_master_folder dev f i g  fspath subpath
	distroname=$1
	sqfs_file=$2
	dev_p=$3
	dev=`echo "$dev_p" | sed s/p//`
	our_master_folder=/tmp/_chrubix_shenanigans

# Prep the build folder
	unmount_shenanigans $our_master_folder
	while ps $bkgd_proc > /dev/null ; do
		echo "Waiting for dd to finish"
		sleep 1
	done

	prep_shenanigans_folder $our_master_folder $sqfs_file 
	prep_shenanigans_folder $our_master_folder/tmp/_root $sqfs_file

	mkdir -p $our_master_folder/tmp/_root/$RYO_TEMPDIR
	mount /dev/loop2 $our_master_folder/tmp/_root/$RYO_TEMPDIR || failed "Failed to mount big loop device"	
	download_kernelrebuilding_skeleton $distroname $our_master_folder/tmp/_root/$RYO_TEMPDIR
	
	wget $OVERLAY_URL -O - | tar -Jx -C $our_master_folder/usr/local/bin/Chrubix || failed "Failed to install latest Chrubix sources. Shuggz."
	chmod +x $our_master_folder/usr/local/bin/*.sh

# Unzip the mk*fs sources
	for fspath in `ls -d $our_master_folder/tmp/_root$SOURCES_BASEDIR/*fs*` ; do
		archive_here=`find $fspath -type f | grep "tar.[x,g]z" | tr ' ' '\n' | head -n1`
		echo "Extracting tarball for `basename $fspath` <== `basename $archive_here`"
		cd $fspath
		echo "$archive_here" | fgrep tar.xz >/dev/null && tar -Jxf $archive_here || tar -zxf $archive_here
	done
# Modify the mk*fs sources
	chroot_this $our_master_folder "/usr/local/bin/modify_sources.sh $dev /tmp/_root yes yes" || failed "Failed to modify_sources.sh"	# There's no point in screwing with the magic numbers of filesystems IF we're using a read-only filesystem.
	make_sure_mkfs_code_was_successfully_modified $our_master_folder/tmp/_root$SOURCES_BASEDIR

# Copy the ser# across
	f=`basename $dev`												#	echo "f=$f"
	g="`mount | fgrep "$f " | head -n1 | cut -d' ' -f3`"			# echo "g=$g"
	f=$our_master_folder/tmp/_root/etc/.randomized_serno			#	echo "Copying $f to $g"
	cp -f $f $g/ || failed "Unable to salvage RSN"
# Make and install the mk*fs binaries
    for fspath in `ls -d $our_master_folder/tmp/_root$SOURCES_BASEDIR/*fs*` ; do
    	echo -en "Test-making `basename $fspath` ... "
        for subpath in `ls -d $fspath/*fs*`; do
        	if [ -e "$subpath/Makefile" ] ; then
        		pppp=$SOURCES_BASEDIR/`basename $fspath`/`basename $subpath`
	        	chroot_this $our_master_folder/tmp/_root "cd $pppp; make" &> /tmp/_oh_crud.txt || failed "`cat /tmp/_oh_crud.txt` --- Failed to make and install new mk*fs binaries."
	        elif [ -d "$subpath" ] ; then
	        	echo "Warning - no makefile at $subpath"
	        else
	        	echo "Ignoring $subpath"
	        fi
        done
        echo "Done."
	done

	echo -en "Rebuilding kernel and writing it to $dev ..."
	make_sure_mkfs_code_was_successfully_modified $our_master_folder/tmp/_root$SOURCES_BASEDIR 
	chroot_this $our_master_folder "/usr/local/bin/redo_mbr.sh $dev /tmp/_root $dev_p"3	&> /tmp/_oh_croo.txt || failed "`cat /tmp/_oh_croo.txt` --- Failed to make and install new kernel + boot loader."
	make_sure_mkfs_code_was_successfully_modified $our_master_folder/tmp/_root$SOURCES_BASEDIR 
# Save PKGBUILDs, in case the user wants to permanize the OS later
	cd $our_master_folder/tmp/_root$RYO_TEMPDIR
	echo "Saving customized PKGBUILDs, just in case you need it later."
	tar -cz PKGBUILDs | pv > $g/.PKGBUILDs.tgz
	tar -cz /usr/bin/vbutil* /usr/bin/futility > $g/.vbtools.tgz 2>/dev/null || failed "Failed to save vbutil*"
	tar -cz /usr/share/vboot > $g/.vbkeys.tgz 2> /dev/null || failed "Failed to save your keys" #### MAKE SURE CHRUBIX HAS ACCESS TO Y-O-U-R KEYS and YOUR vbutil* binaries ####
	tar -cz /lib/firmware > $g/.firmware.tgz 2>/dev/null || fialed "Failed to save firmware"
# Done... :)
	echo "Done. Groovy."
	make_sure_mkfs_code_was_successfully_modified $our_master_folder/tmp/_root$SOURCES_BASEDIR 
	cd /
	unmount_shenanigans $our_master_folder	
	losetup -d /dev/loop2
	rmdir $our_master_folder
	rm -f $BIG_LOOPFS_FILE
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
"
		echo -en "(T)emporary or (P)ermanent? "
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




oh_well_start_from_beginning() {
	cd /
	echo "OK. There was no Stage D available on a thumb drive or online."	
	echo "Installing bootstrap filesystem..."
	wget $ALARPY_URL -O - | tar -Jx -C $btstrap 2> /dev/null || failed "Failed to download/install alarpy.tar.xz"
	echo ""
	echo "en_US.UTF-8 UTF-8" >> $btstrap/etc/locale.gen
	chroot_this $btstrap "locale-gen"
	echo "LANG=\"en_US.UTF-8\"" >> $btstrap/etc/locale.conf
	echo "nameserver 8.8.8.8" >> $btstrap/etc/resolv.conf
	echo "Woohoo."
}


ask_if_secret_squirrel() {
	local $line
	line="bonzer"
	while [ "$line" != "Y" ] && [ "$line" != "y" ] && [ "$line" != "n" ] && [ "$line" != "N" ] ; do
		echo -en "Are you afraid of the evil maid? "
		read line
	done
	if [ "$line" = "Y" ] || [ "$line" = "y" ] ; then
		SECRET_SQUIRREL_KERNEL=on
	else
		SECRET_SQUIRREL_KERNEL=off
	fi
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
	echo "$temp_or_perm" > $btstrap/.temp_or_perm.txt
	ln -sf ../../bin/python3 $btstrap/usr/local/bin/python3
	echo "************ Calling CHRUBIX, the Python powerhouse of pulchritudinous perfection ************"
	echo "yep, use latest" > $root/tmp/.USE_LATEST_CHRUBIX_TARBALL
	chroot_this $btstrap "/usr/local/bin/chrubix.sh" || failed "Because chrubix reported an error, I'm aborting... and I'm leaving everything mounted."
}



##################################################################################################################################


#bkgd_proc=9999
#set +e
#dev=/dev/mmcblk1
#lockfile=/tmp/.chrubix.distro.`basename $dev`
#distroname=`cat $lockfile`
#dev=/dev/mmcblk1
#dev_p="$dev"p
#rebuild_and_install_kernel___oh_crap_this_might_take_a_while debianwheezy /tmp/_root.mmcblk1/.squashfs.sqfs /dev/mmcblk1p
#failed "Nefarious walruses"





set -e
mount | grep /dev/mapper/encstateful &> /dev/null || failed "Run me from within ChromeOS, please."
btstrap=/home/chronos/user/Downloads/.bootstrap
mydevbyid=`deduce_my_dev`
[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
[ -e "$mydevbyid" ] || failed "Please insert a thumb drive or SD card and try again. Please DO NOT INSERT your keychain thumb drive."
dev=`deduce_dev_name $mydevbyid`
dev_p=`deduce_dev_stamen $dev`
fstab_opts="defaults,noatime,nodiratime" #commit=100
mount_opts="-o $fstab_opts"
root=/tmp/_root.`basename $dev`		# Don't monkey with this...
boot=/tmp/_boot.`basename $dev`		# ...or this...
kern=/tmp/_kern.`basename $dev`		# ...or this!
lockfile=/tmp/.chrubix.distro.`basename $dev`
temp_or_perm=temp
SECRET_SQUIRREL_KERNEL="on" 						#	ask_if_secret_squirrel

get_distro_type_the_user_wants
prep_loopback_file_for_rebuilding_kernel $BIG_LOOPFS_FILE &
bkgd_proc=$!

echo -en "OK. "
echo "$temp_or_perm" > /tmp/temp_or_perm
echo "$SECRET_SQUIRREL_KERNEL" > /tmp/secret.squirrel
sudo stop powerd || echo -en ""
for btstrap in /tmp/_root.mmcblk1/.bootstrap /home/chronos/user/Downloads/.bootstrap ; do	
	umount $btstrap/tmp/_root/{dev,tmp,proc,sys} 2> /dev/null || echo -en ""
	umount $btstrap/tmp/posterity 2> /dev/null || echo -en ""
	umount $btstrap/tmp/_root/{dev,tmp,proc,sys} 2> /dev/null || echo -en ""
	umount $btstrap/tmp/posterity 2> /dev/null || echo -en ""
	umount $btstrap/tmp/_root 2> /dev/null || echo -en ""
	umount $btstrap/{dev,tmp,proc,sys} 2> /dev/null || echo -en ""
	umount /tmp/_root*/.ro /tmp/_root.*/.* 2> /dev/null || echo -en ""
done

if mount | grep "$dev" | grep "$root" &> /dev/null ; then
	umount "$dev"* &> /dev/null || failed "Already partitioned and mounted. Reboot and try again..."
fi

if [ ! -e "$btstrap/bin/parted" ] ; then
	umount $btstrap 2> /dev/null || echo -en ""
	mkdir -p $btstrap
	losetup -d /dev/loop1 2> /dev/null || echo -en ""
	dd if=/dev/zero of=/tmp/_alarpy.dat bs=1024k count=500 2> /dev/null
	losetup /dev/loop1 /tmp/_alarpy.dat
	mke2fs /dev/loop1 &> /dev/null || failed "Failed to mkfs the temp loop partition"
	mount /dev/loop1 $btstrap
	if [ ! -f "/home/chronos/user/Downloads/.bt.tar.xz" ] ; then
		wget $PARTED_URL -O - > /home/chronos/user/Downloads/.bt.tar.xz || failed "Failed to download/install parted and friends"
	fi
fi
tar -Jxf /home/chronos/user/Downloads/.bt.tar.xz -C $btstrap

echo -en "Partitioning"
mount devtmpfs  $btstrap/dev -t devtmpfs	|| echo -en ""
mount sysfs     $btstrap/sys -t sysfs		|| echo -en ""
mount proc      $btstrap/proc -t proc		|| echo -en ""
mount tmpfs     $btstrap/tmp -t tmpfs		|| echo -en ""

echo -en "..."
umount /dev/mmcblk1* &> /dev/null || echo -en ""
if ! partition_device $dev $dev_p $btstrap &> /tmp/partitioning_stuff.txt ; then
	cat /tmp/partitioning_stuff.txt
	failed "Failed to partition $dev"
fi
format_partitions $dev $dev_p $btstrap || failed "Failed to format $dev"
echo "Done."

old_btstrap=$btstrap
btstrap=$root/.bootstrap

mkdir -p $root
mount $mount_opts "$dev_p"3  $root
mkdir -p $btstrap
mkdir -p /tmp/a

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

if [ "$temp_or_perm" = "temp" ] && restore_from_squash_fs_backup_if_possible ; then
	echo "Restored from squashfs. Good."
else
	echo "OK. For whatever reason, we aren't using squashfs. Fine."
	if restore_from_stage_X_backup_if_possible ; then
		echo "Restored from stage X. Good."
	else
		clear
		echo "OK. Starting from beginning."
		oh_well_start_from_beginning
	fi
	install_chrubix $btstrap $dev "$dev_p"3 "$dev_p"2 "$dev_p"1 $distroname
	call_chrubix $btstrap || failed "call_chrubix() returned an error. Failing."
fi

echo ":-)"

echo -en "$distroname has been installed on $dev\nPress <Enter> to reboot. Then, press <Ctrl>U to boot into Linux."

sync; umount $old_btstrap/{dev,sys,proc,tmp} 2> /dev/null || echo -en ""
losetup -d /dev/loop1 2> /dev/null || echo -en ""
sync; umount $btstrap/tmp/_root/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
sync; umount $btstrap/tmp/_root/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
sync; umount $btstrap/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
sync; umount $btstrap/{tmp,proc,sys,dev} 2> /dev/null || echo -en ""
unmount_everything       $root $boot $kern $dev_p

# Wipe spare partition completely. That way, we can reformat it later & put super secret squirrel stuff on it if we want.
dd if=/dev/zero of="$dev_p"2 bs=1024k count=1 2> /dev/null
sync;sync;sync

sudo start powerd || echo -en ""
read line && reboot		# read -t 60 line || reboot; reboot

exit 0
