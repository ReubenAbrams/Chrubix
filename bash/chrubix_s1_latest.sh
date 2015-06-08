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
set -e
mount | grep /dev/mapper/encstateful &> /dev/null || failed "Run me from within ChromeOS, please."
ALARPY_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/alarpy.tar.xz"
PARTED_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/parted_and_friends.tar.xz"
echo "$0" | fgrep latest_that &> /dev/null || FINALS_URL="https://dl.dropboxusercontent.com/u/59916027/chrubix/finals"
CHRUBIX_URL="http://github.com/ReubenAbrams/Chrubix/archive/master.tar.gz"
OVERLAY_URL=https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz
RYO_TEMPDIR=/root/.rmo
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
LOGLEVEL=2
SPLITPOINT=15000998
HIDDENLOOP=/dev/loop3			# hiddendev uses this (if it is hidden) :)


















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



partition_the_device() {
	local dev dev_p btstrap splitpoint
	dev=$1
	dev_p=$2
	btstrap=$3
	splitpoint=$4

#	echo "partition_the_device($dev, $dev_p, $btstrap, $splitpoint) --- starting"
	sync;sync;sync; umount $root/{dev/pts,dev,proc,sys,tmp} &> /dev/null || echo -en "."
	sync;sync;sync; umount "$dev_p"* &> /dev/null &> /dev/null  || echo -en "."
	sync;sync;sync; umount "$dev"* &> /dev/null &> /dev/null  || echo -en "."
	sync;sync;sync; umount /media/removable/* &> /dev/null  || echo -en "."
	sync;sync;sync
	chroot_this $btstrap "parted -s $dev mklabel gpt" || echo "Warning. Parted was removed from ChromeOS recently. You might have to partition your SD card on your PC or Mac."
	chroot_this $btstrap "cgpt create -z $dev" || failed "Failed to create -z $dev"
	chroot_this $btstrap "cgpt create $dev" || failed "Failed to create $dev"
	chroot_this $btstrap "cgpt add -i  1 -t kernel -b  8192 -s 32768 -l U-Boot -S 1 -T 5 -P 10 $dev" || failed "Failed to create 1"
	chroot_this $btstrap "cgpt add -i 12 -t data   -b 40960 -s 32768 -l Script $dev" || failed "Failed to create 12"
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2` || failed "Failed to calculate lastblock"

	if [ "$splitpoint" = "" ] ; then
		chroot_this $btstrap "cgpt add -i  3 -t data   -b 73728 -s `expr $lastblock - 73728` -l Root $dev" || failed "Failed to create 3"
	else
		chroot_this $btstrap "cgpt add -i  3 -t data   -b 73728 -s `expr $splitpoint - 73728` -l Root $dev" || failed "Failed to create 3"
		chroot_this $btstrap "cgpt add -i  2 -t data   -b $splitpoint -s `expr $lastblock - $splitpoint` -l Kernel $dev" || failed "Failed to create 2"
	fi
	chroot_this $btstrap "partprobe $dev"
	sync;sync;sync
}







install_chrubix() {
	local root dev rootdev hiddendev kerndev distro proxy_string
	root=$1
	dev=$2
	rootdev=$3
	hiddendev=$4
	kerndev=$5
	distroname=$6
	
	[ "$SIZELIMIT" != "" ] || failed "Set SIZELIMIT before calling install_chrubix(), please."
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
| sed s/\$hiddendev/\\\/dev\\\/`basename $hiddendev`/ \
| sed s/\$kerndev/\\\/dev\\\/`basename $kerndev`/ \
| sed s/\$distroname/$distroname/ \
| sed s/\$splitpoint/$(($SPLITPOINT*512))/ \
| sed s/\$sizelimit/$SIZELIMIT/ \
> chrubix.sh || failed "Failed to rejig chrubix.sh.orig"
	cd /
}



restore_stage_X_from_backup() {
	local distroname device root
	distroname=$1
	fname=$2
	root=$3
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
	tar -cJ /usr/share/vboot 2> /dev/null | tar -Jx -C $old_btstrap
	cp -f $vmlinux_path $old_btstrap/tmp/vmlinux.file	
	chroot_this $old_btstrap "vbutil_kernel --pack /tmp/vmlinuz.signed --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 \
--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config /tmp/kernel.flags \
--vmlinuz /tmp/vmlinux.file --arch arm &&" || failed "Failed to sign kernel"
	sync;sync;sync;sleep 1
	dd if=$old_btstrap/tmp/vmlinuz.signed of=$writehere &> /dev/null && echo -en "..." || failed "Failed to write kernel to $writehere"
	echo -en "OK. Signed & written kernel. "
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
			# hiddendev instead of rootdev?
		sign_and_write_custom_kernel $root $ubootdev $rootdev $kernelpath "" ""  || failed "Failed to sign/write custom kernel"
	fi
}


download_kernelrebuilding_skeleton() {
	local buildloc distroname fnA fnB my_command success savefile
	distroname=$1
	buildloc=$2
	savefile=$3
	if [ -e "$buildloc/PKGBUILDs/core/pacman/makepkg.conf" ] ; then
		echo "Already got the skeleton. Cool."
		return 0
	fi
	echo "Downloading the kernel-rebuilding skeleton to $buildloc ..."
#	rm -Rf $buildloc
	mkdir -p $buildloc
	fnA="/tmp/a/$distroname/"$distroname"_PKGBUILDs.tar.xz"
	fnB="/tmp/b/$distroname/"$distroname"_PKGBUILDs.tar.xz"
	success=""
	mkdir -p /tmp/a
	mount /dev/sda1 /tmp/a 2> /dev/null || echo -en ""
	mount /dev/sdb1 /tmp/a 2> /dev/null || echo -en ""
	if pv $fnA | tee $savefile | tar -Jx -C $buildloc ; then
		echo "Restored skeleton from sda1"
	elif pv $fnB | tee $savefile | tar -Jx -C $buildloc ; then
		echo "Restored skeleton from sdb1"
	else
		wget $FINALS_URL/$distroname/"$distroname"_PKGBUILDs.tar.xz -O - | tee $savefile | tar -Jx -C $buildloc
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
	tar -c $srcpath 2> /dev/null | gzip -1 > $zipname || failed "Failed to tar $srcpath"
	mount tmpfs $srcpath -t tmpfs
	tar -zxf $zipname -C /
	rm -f $zipname
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
		folders="/lib /etc /usr/local /root /usr/local/share/man /usr/share/man /usr/share/doc" # /sbin /usr/sbin"
	else
		folders="/root /etc /usr/local/bin"
	fi
	for f in $folders ; do
		make_folder_read_writable $masterfolder $f
	done

	echo "Done."
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



rebuild_and_install_kernel___oh_crap_this_might_take_a_while() {
	local distroname sqfs_file dev_p url squrl buildloc our_master_folder dev f i g fspath subpath pristine_fname orig_fname
	distroname=$1
	sqfs_file=$2
	dev_p=$3
	dev=`echo "$dev_p" | sed s/p//`
	our_master_folder=/tmp/_chrubix_shenanigans

# Prep the build folder
	unmount_shenanigans $our_master_folder

	prep_shenanigans_folder $our_master_folder $sqfs_file 
	prep_shenanigans_folder $our_master_folder/tmp/_root $sqfs_file

	mkdir -p $our_master_folder/tmp/_root/$RYO_TEMPDIR
	mount "$dev_p"2 $our_master_folder/tmp/_root/$RYO_TEMPDIR || failed "Failed to mount big loop device"	
	download_kernelrebuilding_skeleton $distroname $our_master_folder/tmp/_root/$RYO_TEMPDIR /tmp/.PKGBUILDs.tar.xz
	
	wget $OVERLAY_URL -O - | tar -Jx -C $our_master_folder/usr/local/bin/Chrubix || failed "Failed to install latest Chrubix sources. Shuggz."
	chmod +x $our_master_folder/usr/local/bin/*.sh
	
	touch $our_master_folder/tmp/_root/$RYO_TEMPDIR/meee

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
	mv /tmp/.PKGBUILDs.tar.xz $g &
	bkgd_proc=$!
	f=$our_master_folder/tmp/_root/etc/.randomized_serno			#	echo "Copying $f to $g"
	cp -f $f $g/ || failed "Unable to salvage RSN"
# Make and install the mk*fs binaries
    for fspath in `ls -d $our_master_folder/tmp/_root$SOURCES_BASEDIR/*fs*` ; do
    	echo -en "Test-making `basename $fspath` ... "
        for subpath in `ls -d $fspath/*fs*`; do
        	if [ -e "$subpath/Makefile" ] ; then
        		pppp=$SOURCES_BASEDIR/`basename $fspath`/`basename $subpath`
	        	chroot_this $our_master_folder/tmp/_root "cd $pppp && make" &> /tmp/_oh_crud.txt || failed "`cat /tmp/_oh_crud.txt` --- Failed to make and install new mk*fs binaries."  #  && make install
#	        elif [ -d "$subpath" ] ; then
#	        	echo "Warning - no makefile at $subpath"
#	        else
#	        	echo "Ignoring $subpath"
	        fi
        done
        echo "Done."
	done

	make_sure_mkfs_code_was_successfully_modified $our_master_folder/tmp/_root$SOURCES_BASEDIR 
	echo -en "Rebuilding kernel and writing it to $dev ..."
			# hiddendev instead of rootdev?
	chroot_this $our_master_folder "/usr/local/bin/redo_mbr.sh $dev /tmp/_root $rootdev" &> /tmp/_oh_croo.txt || failed "`cat /tmp/_oh_croo.txt` --- Failed to make and install new kernel + boot loader."
# Save PKGBUILDs, in case the user wants to permanize the OS later
	cd $our_master_folder/tmp/_root$RYO_TEMPDIR
	echo -en "Saving modified source code, just in case you need it later..."
	
	cd $our_master_folder/tmp/_root$RYO_TEMPDIR
	tar -c `find PKGBUILDs -cnewer meee -type f` | xz > $g/.PKGBUILDs.additional.tar.xz

	mkdir -p /tmp/qqqqq/usr/sbin
	cp -f `find . -name jfs_mkfs` /tmp/qqqqq/usr/sbin/
	cp -f `find . -name mkfs.btrfs` /tmp/qqqqq/usr/sbin/
	cp -f `find . -name mkfs.xfs` /tmp/qqqqq/usr/sbin/
	cd /tmp/qqqqq
	tar -cJ * > $g/.mkfs.tar.xz
	
	while ps $bkgd_proc &> /dev/null ; do
		echo "Waiting for cp PKGBUILDs to finish."
		sleep 1
	done
	
# our_master_folder/tmp/_root
	[ -e "$g/.PKGBUILDs.tar.xz" ] || failed "Unable to find $our_master_folder/tmp/_root/.PKGBUILDs.tar.xz :-( The mower slipped."
# our_master_folder/tmp/_root
	[ -e "$g/.PKGBUILDs.additional.tar.xz" ] || failed "Unable to find $our_master_folder/tmp/_root/.PKGBUILDs.additional.tar.xz :-( I don't know how."
	tar -cz /usr/bin/vbutil* /usr/bin/futility > $g/.vbtools.tgz 2>/dev/null || failed "Failed to save vbutil*"
	tar -cz /usr/share/vboot > $g/.vbkeys.tgz 2> /dev/null || failed "Failed to save your keys" #### MAKE SURE CHRUBIX HAS ACCESS TO Y-O-U-R KEYS and YOUR vbutil* binaries ####
	tar -cz /lib/firmware > $g/.firmware.tgz 2>/dev/null || failed "Failed to save firmware"

# Done... :)
	echo "Done. Groovy."
	make_sure_mkfs_code_was_successfully_modified $our_master_folder/tmp/_root$SOURCES_BASEDIR 
	cd /
	unmount_shenanigans $our_master_folder	
	umount "$dev_p"2 || echo -en ""
	rmdir $our_master_folder
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



delete_p2_and_resize_p3() {
	local dev btstrap cgpt_output
	dev=$1
	btstrap=$2
	cgpt_output=/tmp/my_cgpt_output.txt

	chroot_this $btstrap "cgpt show $dev" > $cgpt_output
	end_of_real_p2=`cat   $cgpt_output | tr -s '\t' ' ' | grep Label | fgrep " 2 " | cut -d' ' -f3`
	start_of_real_p2=`cat $cgpt_output | tr -s '\t' ' ' | grep Label | fgrep " 2 " | cut -d' ' -f2`
	start_of_real_p3=`cat $cgpt_output | tr -s '\t' ' ' | grep Label | fgrep " 3 " | cut -d' ' -f2`
	echo "p3 starts at $start_of_real_p3"
	echo "p2 ends   at $end_of_real_p2"
	chroot_this $btstrap "echo -en \"p\\nrm 2\\nresize 3 $start_of_real_p3 $end_of_real_p2\\nq\\n\"" # | parted /dev/mmcblk1"
	return 0
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



save_lots_of_random_files() {
	local my_partition_device mountpoint
	my_partition_device=$1
	mountpoint=/tmp/$RANDOM
	mkdir -p $mountpoint
	mount $my_partition_device $mountpoint || failed "Failed to mount $my_partition_device to save lots of random files"
	echo "Hi there $my_partition_device" > $mountpoint/hithere.txt
	umount $mountpoint
	rmdir $mountpoint || failed "Failed to delete $mountpoint after saving random files to $my_partition_device"
}
	



verify_lots_of_random_files() {
	local my_partition_device mountpoint
	my_partition_device=$1
	mountpoint=/tmp/$RANDOM
	mkdir -p $mountpoint
	mount $my_partition_device $mountpoint || failed "Failed to mount $my_partition_device to save lots of random files"
	[ -e $mountpoint/hithere.txt ] || failed "hithere.txt is missing from $my_partition_device" 
	txt=`cat $mountpoint/hithere.txt`
	[ "$txt" = "Hi there $my_partition_device" ] || failed "hithere.txt contains $txt and not 'Hi there $my_partition_device'"
	umount $mountpoint
	rmdir $mountpoint || failed "Failed to delete $mountpoint after saving random files to $my_partition_device"
}
















unmount_absolutely_everything() {
	echo -en "OK. "
	echo "$temp_or_perm" > /tmp/temp_or_perm
	echo "$SECRET_SQUIRREL_KERNEL" > /tmp/secret.squirrel
	sudo stop powerd 2> /dev/null || echo -en ""
	umount "$dev"* &> /dev/null || echo -en ""
	umount /dev/loop1 &> /dev/null || echo -en ""
	umount /dev/loop2 &> /dev/null || echo -en ""
	losetup -d /dev/loop1 &> /dev/null || echo -en ""
	losetup -d /dev/loop2 &> /dev/null || echo -en ""
	losetup -d /dev/loop3 &> /dev/null || echo -en ""
	unmount_bootstrap_stuff $btstrap
	umount "$dev"* &> /dev/null || echo -en ""
	if mount | grep "$dev" | grep "$root" &> /dev/null ; then
		umount "$dev"* &> /dev/null || failed "Already partitioned and mounted. Reboot and try again..."
	fi
}


prep_parted_if_necessary() {
	if [ ! -e "$btstrap/bin/parted" ] ; then
		echo -en "Thinking..."
		umount $btstrap 2> /dev/null || echo -en ""
		mkdir -p $btstrap
		losetup -d /dev/loop1 &> /dev/null || echo -en ""
		dd if=/dev/zero of=/tmp/_alarpy.dat bs=1024k count=500 2> /dev/null
		losetup /dev/loop1 /tmp/_alarpy.dat
		mke2fs /dev/loop1 &> /dev/null || failed "Failed to mkfs the temp loop partition"
		mount /dev/loop1 $btstrap
		if [ ! -f "/home/chronos/user/Downloads/.bt.tar.xz" ] ; then
			wget $PARTED_URL -O - > /home/chronos/user/Downloads/.bt.tar.xz || failed "Failed to download/install parted and friends"
		fi
	fi
	tar -Jxf /home/chronos/user/Downloads/.bt.tar.xz -C $btstrap
}




partition_absolutely_everything() {
	dd if=/dev/zero of="$dev" bs=32k count=1 2>/dev/null || echo -en ""
	echo -en "Partitioning"
	mount devtmpfs  $btstrap/dev -t devtmpfs	|| echo -en ""
	mount sysfs     $btstrap/sys -t sysfs		|| echo -en ""
	mount proc      $btstrap/proc -t proc		|| echo -en ""
	mount tmpfs     $btstrap/tmp -t tmpfs		|| echo -en ""
	if [ "$hiddendev" = "$HIDDENLOOP" ] ; then
### ---- SAFE VERSION ---- 
		partition_the_device $dev $dev_p $btstrap $SPLITPOINT 2> /tmp/ptxt.txt || failed "Failed to partition myself. `cat /tmp/ptxt.txt` .. Ugh. ###3"
		save_current_partitions_layout $dev /tmp/GPT_THREE
		chroot_this $btstrap "echo -en \"rm 2\nq\n\" | parted $dev" &> /tmp/ptxt.txt || failed "Failed to delete partition #2 --- `cat /tmp/ptxt.txt`"
		partition_the_device $dev $dev_p $btstrap ""          2> /tmp/ptxt.txt || failed "Failed to partition myself. `cat /tmp/ptxt.txt` .. Ugh. ###2"
		save_current_partitions_layout $dev /tmp/GPT_TWO

### ---- DANGEROUS VERSION ----
#partition_the_device $dev $dev_p $btstrap $SPLITPOINT 2> /tmp/ptxt.txt || failed "Failed to partition myself. `cat /tmp/ptxt.txt` .. Ugh. ###3"
#echo Y | mkfs -t ext2 "$dev_p"2 &> /dev/null && echo -en "." || failed "Failed to format p2"
#echo Y | mkfs -t ext2 "$dev_p"3 &> /dev/null && echo -en "." || failed "Failed to format p2"
#mkdir -p 		/tmp/hidden_p2
#mount "$dev_p"2 /tmp/hidden_p2 || failed "Failed to mount hidden sausage A"
#echo "hi $dev $dev_p there" > /tmp/hidden_p2/hi.txt
#umount			/tmp/hidden_p2
#rmdir		    /tmp/hidden_p2
#partition_the_device $dev $dev_p $btstrap ""          2> /tmp/ptxt.txt || failed "Failed to partition myself. `cat /tmp/ptxt.txt` .. Ugh. ###2"
	else
		partition_the_device $dev $dev_p $btstrap $SPLITPOINT          2> /tmp/ptxt.txt || failed "Failed to partition myself. `cat /tmp/ptxt.txt` .. Ugh. ###2"
	fi
}


format_and_mount_root_and_spare() {
	local peedev cmd
	echo -en "Formatting"
	cmd=""
	for peedev in "$dev_p"2 "$dev_p"3 ; do
		if [ -e "$peedev" ] ; then
				# mkfs.vfat -F 32	???
			echo Y | mkfs -t ext2 $peedev &> /dev/null && echo -en "." || failed "Failed to format $peedev in format_and_mount_root_and_spare()"
		fi
	done
	
	mkdir -p $root
	losetup -d $rootdev &>/dev/null || echo -en ""
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2` || failed "Failed to calculate lastblock"
	maximum_length=$(($lastblock-$SPLITPOINT-8))
	SIZELIMIT=$(($maximum_length*512))

	if [ "$hiddendev" = "$HIDDENLOOP" ] ; then	
		echo -en "\nFormatting hiddendev $hiddendev ..."
		# We are creating a loopback device that ignores the first 4GB(ish) of /dev/mmcblk1p3.
		# So, in effect, #HIDDENLOOP is an ersatz /dev/mcblk1p2 .... but it is hiding at the end of p3. :)

		cmd="losetup -o $(($SPLITPOINT*512)) --sizelimit $SIZELIMIT $hiddendev $rootdev"
		$cmd || failed "Failed to set up $HIDDENLOOP as partition #3's device. GRR. Sausage has not been hidden."
		echo Y | mkfs -t ext2 $hiddendev &> /dev/null && echo -en "." || failed "Failed to format $hiddendev"
		mkdir -p /tmp/torpor
		mount $hiddendev /tmp/torpor		
		echo "Created on `date`" > /tmp/torpor/.creationdate.txt
		umount /tmp/torpor
		echo -en "Done. "
	fi
	mount $mount_opts $rootdev $root || failed "Failed to mount hidden sausage B at $root"
	
	mkdir -p $btstrap,/tmp/a,$btstrap/{dev,proc,tmp,sys},$root/{dev,proc,tmp,sys}
	mkdir -p $btstrap/dev $btstrap/sys $btstrap/proc $btstrap/tmp
	mount devtmpfs  $btstrap/dev -t devtmpfs	|| echo -en ""
	mount sysfs     $btstrap/sys -t sysfs		|| echo -en ""
	mount proc      $btstrap/proc -t proc		|| echo -en ""
	mount tmpfs     $btstrap/tmp -t tmpfs		|| echo -en ""

	mkdir -p $btstrap/tmp/_root
	mount $mount_opts $rootdev $btstrap/tmp/_root || failed "Failed to mount hidden sausage C at $btstrap/tmp/_root"
	mkdir -p $btstrap/tmp/_root/{dev,proc,tmp,sys}
	
	mount devtmpfs $btstrap/tmp/_root/dev -t devtmpfs	|| echo -en ""
	mount tmpfs $btstrap/tmp/_root/tmp -t tmpfs			|| echo -en ""
	mount proc $btstrap/tmp/_root/proc -t proc			|| echo -en ""
	mount sys $btstrap/tmp/_root/sys -t sysfs			|| echo -en ""
	echo "$cmd" > $root/.losetup
	chmod +x $root/.losetup || echo -en ""
}


actually_install_chrubix_yall() {
	sudo crossystem dev_boot_usb=1 dev_boot_signed_only=0 || echo "WARNING - failed to configure USB and MMC to be bootable"	# dev_boot_signed_only=0
	if [ "$temp_or_perm" = "temp" ] && restore_from_squash_fs_backup_if_possible ; then
		echo "Restored from squashfs. Good."
	else
		echo "OK. For whatever reason, we aren't using squashfs. Fine."
		if restore_from_stage_X_backup_if_possible ; then
			echo "Restored from stage X. Good."
		else
			echo "OK. Starting from beginning..."
			oh_well_start_from_beginning
		fi
		install_chrubix $btstrap $dev $rootdev $hiddendev $kerneldev $distroname		# might have to swap p2 and p3 ;) [hidden sausage]
		call_chrubix $btstrap || failed "call_chrubix() returned an error. Failing."
	fi
}


post_install_cleanup() {
	sudo start powerd || echo -en ""
	echo -en "$distroname has been installed on $dev\nPress <Enter> to reboot. Then, press <Ctrl>U to boot into Linux."
	read line
	
	sync; umount $old_btstrap/{dev,sys,proc,tmp} 2> /dev/null || echo -en ""
	losetup -d /dev/loop1 &> /dev/null || echo -en ""
	unmount_bootstrap_stuff $btstrap
	
	
	unmount_everything       $root $boot $kern $dev_p || echo -en ""
	
	umount "$dev_p"* 2> /dev/null || echo -en ""
	
	echo "Done."
	sync;sync;sync
	sudo reboot
}



##################################################################################################################################


#set +e
#dev=/dev/mmcblk1
#lockfile=/tmp/.chrubix.distro.`basename $dev`
#SECRET_SQUIRREL_KERNEL=on
#distroname=`cat $lockfile`
#dev=/dev/mmcblk1
#dev_p="$dev"p
#rebuild_and_install_kernel___oh_crap_this_might_take_a_while debianwheezy /tmp/_root.mmcblk1/.squashfs.sqfs $dev_p
#failed "Nefarious walruses"




btstrap=/home/chronos/user/Downloads/.bootstrap
fstab_opts="defaults,noatime,nodiratime" #commit=100
mount_opts="-o $fstab_opts"
temp_or_perm=temp
mydevbyid=`deduce_my_dev`
dev=`deduce_dev_name $mydevbyid`
dev_p=`deduce_dev_stamen $dev`
lockfile=/tmp/.chrubix.distro.`basename $dev`
ubootdev="$dev_p"1
rootdev="$dev_p"3
kerneldev="$dev_p"12
hiddendev=$HIDDENLOOP		# "$dev_p"2 or $HIDDENLOOP
root=/tmp/_root.`basename $dev`		# Don't monkey with this...
boot=/tmp/_boot.`basename $dev`		# ...or this...
kern=/tmp/_kern.`basename $dev`		# ...or this!
[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
[ -e "$mydevbyid" ] || failed "Please insert a thumb drive or SD card and try again. Please DO NOT INSERT your keychain thumb drive."
get_distro_type_the_user_wants
ask_if_secret_squirrel	 # SECRET_SQUIRREL_KERNEL="on"
unmount_absolutely_everything
prep_parted_if_necessary
partition_absolutely_everything

old_btstrap=$btstrap
btstrap=$root/.bootstrap

format_and_mount_root_and_spare
actually_install_chrubix_yall
post_install_cleanup
exit 0
