#!/bin/bash
#
# redo_mbr.sh
# - write hybrid initramfs
# - rebuild kernel
# - write to kernel device (e.g. /dev/mmcblk1p1)
#
#################################################################################


LOGLEVEL="2"		# .... or "6 debug verbose" .... or "2 debug verbose" or "2 quiet"
BOOMFNAME=/etc/.boom
BOOT_PROMPT_STRING="boot: "
TEMPDIR=/tmp
SNOWBALL=nv_uboot-snow.kpart.bz2
RYO_TEMPDIR=/root/.rmo
BOOM_PW_FILE=/etc/.sha512bm
KERNEL_CKSUM_FNAME=.k.bl.ck
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
KERNEL_SRC_BASEDIR=$SOURCES_BASEDIR/linux-chromebook
INITRAMFS_DIRECTORY=$RYO_TEMPDIR/initramfs_dir
INITRAMFS_CPIO=$RYO_TEMPDIR/uInit.cpio.gz
RANDOMIZED_SERIALNO_FILE=/etc/.randomized_serno
RAMFS_BOOMFILE=.sha512boom
GUEST_HOMEDIR=/tmp/.guest
STOP_JFS_HANGUPS="echo 0 > /proc/sys/kernel/hung_task_timeout_secs"
SQUASHFS_FNAME=/.squashfs.sqfs





chroot_this() {
	[ -d "$1" ] || failed "chroot_this() --- first parameter is not a directory; weird; '$1'"
	local res tmpfile proxy_info
	tmpfile=/tmp/do-me.$RANDOM$RANDOM$RANDOM.sh
	[ "$WGET_PROXY" != "" ] && proxy_info="export http_proxy=$WGET_PROXY" || proxy_info=""
	echo -en "#!/bin/sh\n$proxy_info\n$2\nexit \$?\n" > $1/$tmpfile
	chmod +x $1/$tmpfile
	chroot $1 $tmpfile && res=0 || res=1
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





chroot_pkgs_make() {
	local pwd builddir buildcmd tmpfile verno pvparam what_am_i_building
	[ "$3" = "" ] && pvparam="" || pvparam="-s $3"
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	what_am_i_building="`basename $2`"
	if [ "$what_am_i_building" = "linux-chromebook" ]; then
		echo "Rebuilding the kernel and its initial rootfs"
	else
		echo "Building $what_am_i_building"
	fi
	[ -e "$1$2" ] || failed "Because $2 (in $1) does not exist. I cannot chroot into it or even build it."
	chroot_this $1 "cd $2; makepkg --skipchecksums --asroot --noextract -f" || failed "Failed to chroot make $2 within $1"
# 2>&1 | pv $pvparam > $tmpfile|| failed "`cat $tmpfile` --- failed to chroot make $2 within $1"
	rm -f $tmpfile
}



deduce_homedrive() {
	homedev=`mount | grep " / " | cut -d' ' -f1`
	ls -l /dev/disk/by-id/* | grep "`basename $homedev`" | tr ' ' '\n' | grep /dev/disk/by-id | sed s/\-part[0-9]*//
}



deduce_my_dev() {
	local mydevbyid mydevsbyid_a mydevsbyid_b possibles d dev mountdev
	if [ "$1" = "" ] ; then
	    mydevsbyid_a=`find /dev/disk/by-id/usb-* 2> /dev/null | grep -vx ".*part[0-9].*"`
	    mydevsbyid_b=`find /dev/disk/by-id/mmc-* 2> /dev/null | grep -vx ".*part[0-9].*"`
	    homedev=`deduce_homedrive`
            [ "$homedev" = "" ] && homedev=/dev/mmcblk0
	    possibles=""
	    for d in $mydevsbyid_a $mydevsbyid_b ; do
	        if [ "`ls -l $d | grep mmcblk0`" = "" ] && [ ! "`ls -l $d | grep $homedev`" ] ; then
	            possibles="$possibles $d"
	        fi
	    done
	    mydevbyid=`echo "$possibles" | tr ' ' '\n' | tail -n1`
	    dev=`deduce_dev_name $mydevbyid`
	    if [ "$dev" = "$mountdev" ] ; then
	        mydevbyid=`echo "$possibles" | tr ' ' '\n' | grep -vx "$dev" | tail -n1`
	    fi
	else
	    dev=$1
	    if ! echo "$dev" | grep "/disk/by-id/" &> /dev/null ; then
	        bname=`basename $dev`
		echo "bname=$bname" > /dev/stderr
	        mydevbyid=/dev/disk/by-id/`ls -l /dev/disk/by-id/ | grep -x ".*$bname" | tr ' ' '\n' | grep "_"`
	    else
	        mydevbyid=$dev
	    fi
        echo "B mydevbyid = $mydevbyid" > /dev/stderr
	fi
	echo $mydevbyid
}



deduce_serial_numbers_from_thumbprints() {
	local lst
	lst=" "
	filenames=`find $1 -type f 2> /dev/null`
	for f in $filenames ; do
		lst="`get_dev_serialno /dev/disk/by-id/unk/$f` $lst"
	done
	echo "$lst" | tr '[:upper:]' '[:lower:]'
}



deduce_whitelist() {
# Include the following in the whitelist:-
# - devices that are built into the laptop (webcam, built-in solid-state disk)
# - devices that are currently plugged in (external thumb/mmc disk)
# - anything else visible at present
	local LOVSN duh
	duh="s5p-ehci nos-ohci xhci-hcd xhci-hcd"
	additional_serial_numbers=`dmesg | grep SerialNumber: | sed s/.*SerialNumber:\ // | tr '[:upper:]' '[:lower:]' | awk '{print substr($0, length($0)-7);}' | tr -s '\n ' ' '`
	serialno="`get_dev_serialno $1`"
	[ "$serialno" = "" ] && failed "deduce_whitelist() deduced a blank serialno"
	LOVSN="`deduce_serial_numbers_from_thumbprints /root/.thumbprints` $additional_serial_numbers "
	echo "$duh $LOVSN" | tr -s ' ' '\n' | sort | uniq | tr '\n' ' ' | tr '[:upper:]' '[:lower:]'
}



failed() {
	echo "$1" >> /dev/stderr
	logger "QQQ - failed - $1"
	if mount | grep "cryptroot" &> /dev/null ; then
		echo -en "Press ENTER to continue."; read line
	fi
	exit 1
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

generate_random_serial_number() {
	echo $RANDOM $RANDOM $RANDOM $RANDOM | awk '{for(i=1;i<=4;i++) { printf("%02x", (int($i)+32)%(128-32));}};'
}





get_dev_serialno() {
	local dev mydevbyid bname petname
	dev=$1
	if ! echo "$dev" | grep "/disk/by-id/" &> /dev/null ; then
	        bname=`basename $dev` || failed "Unable to deduce basename from \"$dev\""
	        mydevbyid=/dev/disk/by-id/`ls -l /dev/disk/by-id/ | grep -x ".*$bname" | tr ' ' '\n' | grep "_"`
	else
	        mydevbyid=$dev
	fi
	petname=`echo "$mydevbyid" | tr '-' '\n' | fgrep -v ":" | tail -n1 | awk '{print substr($0, length($0)-7, 8)};'`
	echo "$petname" | tr '[:upper:]' '[:lower:]'
}




get_internal_serial_number() {
	ls /dev/disk/by-id/ | grep mmc-SEM | head -n1
}





get_number_of_cores() {
	local cores
	which lscpu &> /dev/null || failed "ChromeOS does not have lscpu. Bugger."
	cores="`lscpu | grep "CPU(s):" | tr -s ' ' '\n' | tail -n1`"
	[ "$cores" = "" ] && cores=2
	echo "$cores"
}




install_phase1b_all_internally() {
# Install modified kernel, mkfs binaries, modules, etc. on our local system
	local bootdev root boot kern dev dev_p tmpfile
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	echo "Installing kernel+mkfs internally"
	[ -e "$root/usr/lib/modules.orig" ] && rm -Rf $root/usr/lib/modules.orig
	[ -e "$root/usr/lib/modules" ] && mv $root/usr/lib/modules $root/usr/lib/modules.orig
	mkdir -p $root/usr/lib/modules
	chroot_pkgs_install $root $RYO_TEMPDIR/PKGBUILDs &> $tmpfile || failed "`cat $tmpfile` - Failed to install the recently built packages"
	cp -f $root/boot/{b,v}* $kern/																# p2
	cp -f $root/boot/{b,v}* $root/				# shouldn't be necessary
	rm -f $tmpfile
}







make_initramfs_homemade() {
	local f myhooks rootdev login_shell_code booming smileyface
	root=$1
	rootdev=$2
	thumbsup="H4sIAEN+NFMAA5VUWxLEIAj79xRMhvtx/78VAcVWtm1mZ6uUhFeVqIJ0cILuW+XKBY6M2t1Jy5P7H3N/qo5QX8l69wLh3TXGrwuJyjCBrzLml7AZllIXUR24nQ8ym9DVIHnb5vKBdTdktPLN/6rcAsBESJ+w7TeM7EKFzPBqRIXM+HK6AOqiH3VsWm3m800IFCOOo6BS4gaP8jaZeyvSyOBOr5TMDY6ms8OqlqN/JbC+++1wjqbb6jR+TKYFuhxszsdWtUIjpXcM62kLPUCJuN0mSFxvsWDTEz5EDCZLVDw2HEyxzM/XHYKqZEyeF1tckZM2Yq62lu6Ltk3j0V/BXwmJURdwyWuUS9R+VV7y0EIGAAA="
	barnie="H4sIAC9aQFMAA41Xz2vjOBS+96/QKEIqHlliYWmxiPNuiwk1hNanoE0e3lyGOXh6yUnjv32lOE4kO8n0QamR9H16v/VCyJdk35VL7mVVHrv9/ulLGNCspIISQindBfg76+1XoIqDFukSUsqY/DNY6itU53RnVeDLy942f0THWKKtewF0hLjl8jMnEuAxXOlEZ7QAh19+ARmA1E7+sOohgcwA0hWk5w9KBcFWWMsY549pZHMQD7Y9KTdYCUL5qyRqHki1V5fvyrlk6wZZZisZOBn7MK9uQuYAribVTl6VzHPu7C3doCXBXKO1GMiU7PL82Fm5WYvqQlG5tysIBa1OuFRkjhDukJwPXHIDecjD0pSCODci8K2QMQ4r5HLC5cB8886QG35iwhYi7Qs9GglQJUivZdYqKWh02jDDvQH/nu3Dltnu4tlMWzVSeWREVaiQUtY8u7NbNHsJkXa2Gb2OaLd2vAnt64CXTQc8prLP1uQq/zB5X+ZUCLk5LddrEYXPZ282OghCzhFysG659xvdfjzDeW0N5N8XZmWVk1wMNjdJGnimUSkM3wen8e/32pnesPI4mIvs57J+5/U/jAFfD/lbJfqMTOry3Wrmq+H4LQe+BGM2wyVId/kuh7b8OJfB4J9915c942xVhisBrIxYD/6PMVFshMlhZWhpu67TpefvgQ2qy3f9pDSDfidoEKTWcr4ks7Sj2LON+c8QffRXyYUxsFxyI5oQtgPzWW3SMqK07DSfldYQlI5vBQq1WDji6sqGDPSKPpWGVby0MQhpC23KooZ4FC+Zyo/KgEZblowD49ngWdwxSEkyntkoVc+Z4TOgz/tzV3G+0leXyIQsi7VutB2SJchh0s7OBE0UV6uvcHWKPNrVAL7TxZImzvHSBnTcqyDpW7FADHeuOH+tbRMdqu6hJ/hLg3ROR6vu7u1eioTAufr0f7MWyeoDAqySsmgbeULE+j8m8LsJQ6ODEye9Huf9NJY6LU0elKgnlxbTJprupgynJjxlwHldRDJ9bRAyWUwtf2jHYfr4+Q7z7KrJpY8ooJ29xf5JnCuO9p4l68zNOQKg01PMPXf4Mi302+2hoDAzVYobDy8J7zRWxb3RIoMZau6Wc8NxehqZK8bNHHGt4IFjHKHQVfdYDlZ/btsuIaojClleikm6ZsKidO+HFSghDGtIy4pFGTMWvupKERXk2k4skpkWp1516XB4Oe7HwM73fpq1aQFItklI/KB2xz5y6vIDI7g6WdcJx/puoUsG15ZUR8dgQhHvudU5Omov+4LFLmiuxw6iTtOkwCsFVj/MOzecv3A/+UeH/Ou5Ho/hjvpJJSVxsaFYbq2hlEylck2yiLziq+Nkhh06IlHBlKOEW3NmYvVZP7N1s9HauSrMDluAY7/CQ1HdcLdvO5MbgBFciGn6+hJ17q/vhFaeUzFNbgi2Wz6Syc5y9/vFEa6ngxCxwPyDHqaUjNJ7434Yatowqzlb+JoEo+ZE4VdVIMDHvxkI9sA/OwNGyF+LGzRfF7rrl2al6dP/22OCtXcOAAA="
	garfield="H4sIAJ5cQFMAA5WWW47DIAxF/7OKIP8hDdlQpOx/F1O/bR4pdTWdEu4xBhvCeb4boB2L5wDSqBVKmQq5Czu5oc1ByX2AvSCtV6l0g7a+aFGA3it+SFtANX9/I8ZC+hAoFrjrGakgZC0bGHVdT4dBFJb4W7iPXdd1njdyt1FljXmb1uO5hVgiPrePVV7E+x6ZAq4GWSdmKlHP89w3uCQa5UCjb60RRNiFoyHVNCOsBf19BqxpNg9JLz6zTLLYmgFTkrlPNPQIgjQGSOslmEQqYNGnkIKl0mWTbgJtOZ0jlIXEtWyAJC8pgqBxdqIGA4d/HqosTNaBfXkoMseawTimz8nD0B+lHzFNUCThUeCsaqiIWm9acv3DlH/oFWVtXd2wveiLdEdMuS+DoCBSp5T/FPETSsroCDW4pgAMSKde2MkziI6m/uBaAjKpHwGK6viRiMu1j3TMl4l0ydxDiu7FXwi0lMlNBhfbsX3KN9Mm6GVSU7q+kVJ3DGsF7sFIagaKb5WRnr2mwHdjCXDYmSOTad5HYTetcKeMtnGTLXDl9N8w8PvoGYfFwOkwS50DXufwNr7i9/B18HKEv/IDbR5Ad0q4CcV7jEUQfMdbHNagBIEecs6mk7BbTHVfcjYQL7fD6CDef0o46ocJmY8iV66+Bs1leFf0XeKjgLsxFyE2WHqQONQJ5HTE6aWXVnQgdwG1cCV+cZFjGF83ekBM75STIFYOBocdbo43+T6i4x9WhIAHTg0AAA=="

#	smileydecoder=""
	smileydecoder="echo \"$thumbsup\" | base64 -d | gunzip"           # yes, \"$garfield\"; no, the $ shouldn't be backslashed
	booming=""
	[ "$rootdev" != "" ] || failed "Please specify rootdev when calling make_initramfs_homemade(). Thanks."
	rm -Rf $root$INITRAMFS_DIRECTORY
	mkdir -p $root$INITRAMFS_DIRECTORY
	cd $root$INITRAMFS_DIRECTORY

	mkdir -p dev etc etc/init.d bin proc mnt tmp var var/shm bin sbin sys run
	chmod 755 . dev etc etc/init.d bin proc mnt tmp var var/shm

	cp $root$BOOM_PW_FILE $root$INITRAMFS_DIRECTORY/$RAMFS_BOOMFILE || echo "Warning - no boom pw file" > /dev/stderr
	cd $root$INITRAMFS_DIRECTORY/dev
	mknod tty c 5 0
	mknod console c 5 1
	chmod 666 tty console
	for i in 0 1 2 3 4 5 ; do
		mknod tty$i c 4 $i
	done
	chmod 666 tty0
	mknod ram0 b 1 0
	chmod 600 ram0
	mknod null c 1 3
	chmod 666 null

# Write fstab
	echo "
proc  /proc      proc    defaults	0	0
tmpfs /run	 tmpfs	 defaults	0	0
devtmpfs /dev    devtmpfs defaults	0	0
sysfs	/sys	sysfs	defaults	0	0
proc	/proc	proc	defaults	0	0
" > $root$INITRAMFS_DIRECTORY/etc/fstab
	chmod 644 $root$INITRAMFS_DIRECTORY/etc/fstab

# Write log_me_in.sh
	if echo "$rootdev" | grep /dev/mapper &>/dev/null ; then
			login_shell_code="#!/bin/sh
sha512boom=\"\`cat /$RAMFS_BOOMFILE\`\"
res=999
clear
while [ \"\$res\" != \"0\" ] ; do
  echo -en \"$BOOT_PROMPT_STRING\"
  read -s password_str_orig
  echo \"\"
  if [ \"\$password_str_orig\" = \"x\" ] ; then
    echo \"Temporarily shelling...\"
    sh
    continue
  fi
  password_sha512=\"\`echo \"\$password_str\" | sha512sum | cut -d' ' -f1\`\"
  definitely_booming=\"\"
  ctr=0
  password_str=\$password_str_orig
  if [ \"\$password_sha512\" != \"\" ] ; then
    while [ \"\$ctr\" -le \"\${#password_str}\" ] ; do
      i_after=\$((\${#password_str}-\$ctr))
      midpt=\$ctr
      possible_left=\"\${password_str:0:\$midpt}\"
      possible_rite=\"\${password_str:\$ctr:\$i_after}\"
      sha512_left=\"\`echo \"\$possible_left\" | sha512sum | cut -d' ' -f1\`\"
      sha512_rite=\"\`echo \"\$possible_rite\" | sha512sum | cut -d' ' -f1\`\"
      if [ \"\$sha512_left\" = \"\$sha512boom\" ] ; then
        definitely_booming=\$possible_left
        password_str=\$possible_rite
        break
      elif [ \"\$sha512_rite\" = \"\$sha512boom\" ] ; then
        definitely_booming=\$possible_rite
        password_str=\$possible_left
        break
      fi
      ctr=\$((\$ctr+1))
    done
  fi
  if [ \"\$definitely_booming\" != \"\" ] ; then
    booming=\"Boom at pw entry.\"
  fi
  echo \"\$password_str\" | cryptsetup open "$dev_p"2 `basename $rootdev`
  res=\$?
done
mount $mount_opts $rootdev /newroot
[ \"\$booming\" != \"\" ] && echo \"\$booming\" > /newroot/$BOOMFNAME || echo -en \"\"   # echo \"not booming... ok...\"
exit 0
"
	else
		login_shell_code="#!/bin/sh
mount $rootdev /newroot
if [ -e \"/newroot/$SQUASHFS_FNAME\" ]; then
  umount /newroot
  mkdir -p /deviceroot
  mount $rootdev /deviceroot
  mkdir -p /ro /rw
  mount -o loop,squashfs /deviceroot/$SQUASHFS_FNAME /ro
  mount -t unionfs -o dirs=/rw:/ro=ro none /newroot        # mount -t unionfs -o dirs=/home/rw.fs=rw:/newroot=ro unionfs user1
#  mount tmpfs /newroot/tmp -t tmpfs
#  for mydir in etc var root ; do
#    cp -af /newroot/\$mydir /newroot/tmp/.squashfs.rw.ahoy/
#    mount  /newroot/\$mydir /newroot/tmp/.squashfs.rw.ahoy/\$mydir
#  done
#  [ -e \"/preboot_configurer.sh\" ] && /preboot_configurer.sh	# We use GREETER (Python 3) now. Yay. :-)
fi
"
	fi

# Save log_me_in.sh :)
	echo "$login_shell_code" > $root$INITRAMFS_DIRECTORY/log_me_in.sh
	chmod +x $root$INITRAMFS_DIRECTORY/log_me_in.sh

# Now, create /init :-)
	echo "#!/bin/busybox sh
PATH=\"/bin:/sbin:/usr/bin:/usr/sbin\"
mount -t proc proc /proc
mount -t sysfs sysfs /sys
$STOP_JFS_HANGUPS
mdev -s
mkdir -p /newroot
/log_me_in.sh
if [ \"\$?\" -eq \"0\" ] && [ -x \"/newroot/sbin/init\" ] ; then
#	$smileydecoder
#    echo \"\"
#	echo \"'A man is not idle because he is absorbed in thought. There is visible labor and there is invisible labor.' - Victor Hugo\"
#	umount /sys /proc	#Unmount all other mounts so that the ram used by the initramfs can be cleared after switch_root
    echo \"Normally, I would call exec switch_root /newroot /sbin/init now; instead, I shall shell out\"
    sh
	exec switch_root /newroot /sbin/init
else
	echo \"Failed to switch_root, dropping to a shell\"		#This will only be run if the exec above failed
	exec sh
fi
" > $root$INITRAMFS_DIRECTORY/init
# FYI, base64 uses -d in busybox but -D in the 'grown-up' version of base64; weird...!
	chmod 755 $root$INITRAMFS_DIRECTORY/init

	cd $root$INITRAMFS_DIRECTORY/bin
	if [ -e "$root/usr/bin/busybox" ] ; then
		cp $root/usr/bin/busybox busybox
	else
		failed "Unable to find busybox on your disk"
	fi
	for f in [ ar awk basename cat chgrp chmod chown chroot chvt clear cp cut date dc dd deallocvtdf dirname dmesg du dumpkmap dutmp echo false fbset fdflush find free freeramdisk fsck.minix grep gunzip gzip halt head hostid hostname id init insmod kill killall length linuxrc ln loadacm loadfont loadkmap logger logname lsmod makedevs mkdir mdev mkfifo mkfs.minix mknod mkswap mktemp more mount mt mv nc nslookup ping pivot_root poweroff printf ps pwd reboot rm rmdir rmmod sed setkeycodes sh sleep sort swapoff swapon switch_root syn c syslogd tail tar tee telnet test touch tr tri true tty umount uname uniq update uptime usleep uudecode uuencode wc which whoami yes zcat ; do
		ln -sf busybox $f
	done
	chmod 4555 busybox
	cd $root$INITRAMFS_DIRECTORY/sbin
	ln -sf ../init .
	cd $root$INITRAMFS_DIRECTORY/bin
	ln -sf ../init .
	cd $pwd
}


make_initramfs_hybrid() {
	local pwd tmpfile mytemptarball
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	mytemptarball=/tmp/$RANDOM$RANDOM$RANDOM.tgz
	pwd=`pwd`

	make_initramfs_homemade $1 $2  || failed "Failed to make custom initramfs -- `cat $tmpfile`"
	cd $1$INITRAMFS_DIRECTORY
	tar -cz . > $mytemptarball
	cd $pwd
	echo -en "..."

	make_initramfs_saralee $1 $2 || failed "Failed to make prefab initramfs  -- `cat $tmpfile`"
	echo -en "..."
	cd $1$INITRAMFS_DIRECTORY
	tar -zxf $mytemptarball || failed "Failed to merge the two"
	cd $pwd
}


make_initramfs_saralee() {
	local f myhooks root autogenerator_fname
	root=$1
	rm -Rf $root$INITRAMFS_DIRECTORY
	mkdir -p $root$INITRAMFS_DIRECTORY
	cd $root$INITRAMFS_DIRECTORY
	f=$root/etc/mkinitcpio.conf
	[ -e "$f" ] || failed "Error A while creating ramdisk"
	[ -e "$f.orig" ] || mv $f $f.orig
	cat $f.orig | grep -vx "#.*" | grep -v "HOOKS" | grep -v "COMPRESSION" > $f || echo -en "..."
	myhooks="base systemd autodetect modconf block keyboard keymap encrypt filesystems fsck"
	[ -e "/lib/initcpio/wiperam_on_shutdown" ] && myhooks="$myhooks wiperam_on_shutdown"
	echo "
HOOKS=\"$myhooks\"
COMPRESSION=\"lzma\"
" >> $f
	if [ "$root" = "/" ] ; then
		cd $INITRAMFS_DIRECTORY
		mkinitcpio -k 3.4.0-ARCH -g $INITRAMFS_CPIO
		rm -Rf $INITRAMFS_DIRECTORY/*
		lsinitcpio -x $INITRAMFS_CPIO
	else
		chroot_this $root "cd $INITRAMFS_DIRECTORY; mkinitcpio -k 3.4.0-ARCH -g $INITRAMFS_CPIO"
		rm -Rf $root$INITRAMFS_DIRECTORY/*
		chroot_this $root "cd $INITRAMFS_DIRECTORY; lsinitcpio -x $INITRAMFS_CPIO"
	fi
	cd $pwd
}




redo_mbr() {
	local root dev_p rootdev
	root=$1
	dev_p=$2
	rootdev=$3
	echo "redo_mbr($1,$2,$3)"
#	echo "root = $root"
#	echo "Looking for $root$BOOM_PW_FILE"
#	echo "Here's what 'ls' says..."
#	ls $root$BOOM_PW_FILE || echo -en ""

#	[ -e "$root$BOOM_PW_FILE" ] || echo "WARNING - No boom pw cksum file"
	[ -e "$root$KERNEL_SRC_BASEDIR/src" ] || failed "Cannot find $root$KERNEL_SRC_BASEDIR/src source folder"
	rm -f $root$KERNEL_SRC_BASEDIR/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg
	rm -f $root/root/.vmlinuz.signed
	rm -f `find $root$KERNEL_SRC_BASEDIR | grep initramfs | grep lzma | grep -vx ".*\.h"`
	make_initramfs_hybrid $root $rootdev
	chroot_pkgs_make $root $KERNEL_SRC_BASEDIR 39600
	if echo "$rootdev" | grep /dev/mapper &>/dev/null ; then
		sign_and_write_custom_kernel $root "$dev_p"1 $rootdev "cryptdevice="$dev_p"2:`basename $rootdev`" "" || failed "Failed to sign/write custm kernel"
	else
# I assume rootdev == "$dev_p"2
		sign_and_write_custom_kernel $root "$dev_p"1 $rootdev "" || failed "Failed to sign/write custm kernel"
	fi
}





sizeof() {
	echo $(du -sb "$1" | awk '{ print $1 }')
}




sign_and_write_custom_kernel() {
	local writehere rootdev extra_params_A extra_params_B readwrite root
	root=$1
	writehere=$2
	rootdev=$3
	extra_params_A=$4
	extra_params_B=$5
# echo "sign_and_write_custom_kernel() -- writehere=$writehere rootdev=$rootdev "

	echo -en "Writing kernel to boot device (replacing nv_u-boot)..."
	dd if=/dev/zero of=$writehere bs=1k 2> /dev/null || echo -en "..."
	echo "$extra_params_A $extra_params_b" | grep crypt &> /dev/null && readwrite=ro || readwrite=rw # TODO Shouldn't it be rw always?
	echo "console=tty1  $extra_params_A root=$rootdev rootwait $readwrite quiet systemd.show_status=0 loglevel=$LOGLEVEL lsm.module_locking=0 init=/sbin/init $extra_params_B" > $root/root/.kernel.flags
	vbutil_kernel --pack $root/root/.vmlinuz.signed --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config $root/root/.kernel.flags --vmlinuz $root$KERNEL_SRC_BASEDIR/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg --arch arm && echo -en "..." || failed "Failed to sign kernel"
	sync;sync;sync;sleep 1
	dd if=$root/root/.vmlinuz.signed of=$writehere &> /dev/null && echo -en "..." || failed "Failed to write kernel to $writehere"
	echo "OK."
}




# ------------------------------------------------------------------


export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin # Just in case phase 3 forgets to pass $PATH to the xterm call to me
set -e
if [ "$#" -ne "3" ] ; then
	failed "redo_mbr.sh <dev> <mountpoint> <root device or crypto root dev> ----- e.g. redo_mbr.sh /dev/mmcblk1 /tmp/_root /dev/mapper/cryptroot"
fi

dev=$1					# disk, e.g. /dev/mmcblk1
root=$2					# root folder
my_root_disk_device=$3

dev_p=`deduce_dev_stamen $dev`
petname=`find_boot_drive | cut -d'-' -f3 | tr '_' '\n' | tail -n1 | awk '{print substr($0,length($0)-7);}' | tr '[:upper:]' '[:lower:]'`
cores=1
#echo "redo_mbr($root,$dev_p,$my_root_disk_device) --- calling"
redo_mbr $root $dev_p $my_root_disk_device
res=$?
#echo "Exiting w/ res=$res"
exit $res

