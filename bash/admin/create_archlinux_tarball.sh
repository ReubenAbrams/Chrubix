#!/bin/bash
#
# create_archlinux_tarball.sh
# - generates an ArchLinux tarball from within ChromeOS
# - asks user to upload it to Dropbox etc.
# - terminates
#
# To run, type:-
# cd && wget bit.ly/1iBQSx9 -O xx && sudo bash xx
#################################################################################


NOPHEASANTS="Nope"			# if not left blank, the new kernel will use a whitelist and a randomize margic number (for btrfs, jfs, xfs)
NOKTHX="Nope"
LOGLEVEL="2"		# .... or "6 debug verbose" .... or "2 debug verbose" or "2 quiet"
BOOMFNAME=/etc/.boom
BOOT_PROMPT_STRING="boot: "
TEMPDIR=/tmp
SNOWBALL=nv_uboot-snow.kpart.bz2
ARCHLINUX_ARCHITECTURE=armv7h
RYO_TEMPDIR=/root/.rmo
BOOM_PW_FILE=/etc/.sha512bm
KERNEL_CKSUM_FNAME=.k.bl.ck
SPLITPOINT=NONONONONONONONO
CRYPTOROOTDEV=/dev/mapper/cryptroot			# do not tamper with this, please
CRYPTOHOMEDEV=/dev/mapper/crypthome
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
KERNEL_SRC_BASEDIR=$SOURCES_BASEDIR/linux-chromebook
INITRAMFS_DIRECTORY=$RYO_TEMPDIR/initramfs_dir
INITRAMFS_CPIO=$RYO_TEMPDIR/uInit.cpio.gz
RANDOMIZED_SERIALNO_FILE=/etc/.randomized_serno
RAMFS_BOOMFILE=.sha512boom
GUEST_HOMEDIR=/tmp/.guest
DISTRO=ArchLinux
STOP_JFS_HANGUPS="echo 0 > /proc/sys/kernel/hung_task_timeout_secs"
if ping -W2 -c1 192.168.1.73 ; then
	WGET_PROXY="192.168.1.73:8080"
elif ping -W2 -c1 192.168.1.66 ; then
	WGET_PROXY="192.168.1.66:8080"
else
	WGET_PROXY=""
fi
[ "$WGET_PROXY" != "" ] && export http_proxy=$WGET_PROXY









download_mkfs_n_kernel() {
	local root boot kern dev dev_p fstype petname tmpfile
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	petname=$6
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	randomized_serno="`cat $root$RANDOMIZED_SERIALNO_FILE`" || failed "Unable to find my randomized serno"
	echo "Setting up build environment"
	rm -Rf $root/$RYO_TEMPDIR
	mkdir -p $root/$RYO_TEMPDIR

	echo "Downloading sources"
	chroot_this $root "cd $RYO_TEMPDIR; git clone git://github.com/archlinuxarm/PKGBUILDs.git" && echo -en "..." || failed "Failed to git clone kernel source"
	chroot_pkgs_download $root $KERNEL_SRC_BASEDIR
	chroot_pkgs_download $root $SOURCES_BASEDIR/btrfs-progs	"PKGBUILD btrfs-progs.install initcpio-hook-btrfs initcpio-install-btrfs"
	chroot_pkgs_download $root $SOURCES_BASEDIR/jfsutils		"PKGBUILD inttypes.patch"
	chroot_pkgs_download $root $SOURCES_BASEDIR/xfsprogs		"PKGBUILD"
}



modify_mkfs_n_kernel() {
	local root boot kern dev dev_p fstype petname serialno haystack tmpfile cores linepos relfname fname
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	petname=$6
	cores=$7
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	serialno=`get_dev_serialno $dev`
	haystack="`deduce_whitelist "$dev"`"          # $serialno" # Don't need to include serialno. Whitelist will add it automatically because it's plugged in already.
	[ "$serialno" = "" ] && failed "Failed to get dev serialno of $dev"

	echo "Modifying..."
	modify_all $root "$serialno" "$haystack"
	echo -en "Building a temporary prefab initramfs..."
	make_initramfs_saralee $root "" &> $tmpfile && echo "Done." || failed "Failed to make prefab initramfs -- `cat $tmpfile`"

	# enable SMP compiling
	mv $root/etc/makepkg.conf $root/etc/makepkg.conf.orig
	cat $root/etc/makepkg.conf.orig | sed s/#MAKEFLAGS.*/MAKEFLAGS=\"-j$cores\"/ | sed s/\!ccache/ccache/ > $root/etc/makepkg.conf
}




make_mkfs_n_kernel() {
	local root boot kern dev dev_p fstype petname serialno haystack tmpfile cores linepos relfname fname
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	petname=$6
	cores=$7
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM

	echo "Making new tarball with kernel"
	chroot_pkgs_make $root $SOURCES_BASEDIR/btrfs-progs  4900 || failed "Failed to make btrfs-progs"
	chroot_pkgs_make $root $SOURCES_BASEDIR/jfsutils    56000 || failed "Failed to make jfsutils"
	chroot_pkgs_make $root $SOURCES_BASEDIR/xfsprogs    24600 || failed "Failed to make xfsprogs"
	chroot_pkgs_make $root $KERNEL_SRC_BASEDIR 301800 || failed "Failed to make kernel"
	echo -en "Building a temporary prefab initramfs for a second time..."
	make_initramfs_saralee $root "" &> $tmpfile && echo "Done." || failed "Failed to make prefab initramfs -- `cat $tmpfile`"
}



chroot_pkgs_download() {
	local fdir res file_to_download f stuff_from_website root tmpfile
	root=$1
	fdir=`dirname $2`
	f=`basename $2`
	stuff_from_website="$3"
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	res=0
	mkdir -p $root/$fdir/$f
	cd $root/$fdir/$f
	echo -en "Downloading $f..."
	if [ -f "$root/$fdir/$f/PKGBUILD" ] ; then
		echo -en "Still working..." # echo "No need to download anything. We have PKGBUILD already."
	elif [ "$stuff_from_website" = "" ] ; then
		file_to_download=aur.archlinux.org/packages/${f:0:2}/$f/$f.tar.gz
#		echo "Downloading $file_to_download to `pwd`/.."
		wget --quiet -O - $file_to_download | tar -zx -C .. && echo -en "..." || failed "Failed to download $file_to_download"
	else
		for fname in $stuff_from_website ; do
			file_to_download=$root/$fdir/$f/$fname
			echo -en "$fname"...
			rm -Rf $file_to_download
			wget --quiet http://projects.archlinux.org/svntogit/packages.git/plain/trunk/$fname?h=packages/$f -O - > $file_to_download && echo -en "..." || failed "Failed to download $fname for $f"
		done
	fi
	echo -en "Calling make"
#	if ! echo "$f" | grep java-service-wrapper &> /dev/null ; then
		mv PKGBUILD PKGBUILD.ori || failed "pkgs_download() --- unable to find PKGBUILD"
		cat PKGBUILD.ori | sed s/march/phr34k/ | sed s/\'libutil-linux\'// | sed s/\'java-service-wrapper\'// | sed s/arch=\(.*/arch=\(\'$ARCHLINUX_ARCHITECTURE\'\)/ | sed s/phr34k/march/ > PKGBUILD
#	fi
	echo -en "pkg..."
	if [ "$f" = "linux-chromebook" ] ; then
		mv PKGBUILD PKGBUILD.wtfgoogle
		cat PKGBUILD.wtfgoogle | sed s/chromium\.googlesource.*kernel.*gz/dl.dropboxusercontent.com\\\/u\\\/59916027\\\/klaxon\\\/135148b515275c24d691f10ba74c0c5b8d56af63.tar.gz/ > PKGBUILD
	fi
	chroot_this $root "cd $2; makepkg --skipchecksums --asroot --nobuild -f" &> $tmpfile || failed "`cat $tmpfile` --- chroot_pkgs_download() -- failed to download $2"
	[ "$res" -eq "0" ] && echo "OK." || echo "Failed."
	return $res
}



chroot_pkgs_install() {
	local mycall pkgs res f needed_str
	[ "$3" = "" ] && needed_str="--needed" || needed_str=""
	res=0
	if [ "$1" = "/" ] && [ -d "$2" ]; then	# $2 is a directory? OK. Install all (recursively) found (living in supplied folder) local packages, locally.
			echo "Searching $2 for packages"
			yes "" | pacman -U `find $2 -type f | grep -x ".*\.pkg\.tar\.xz"`	|| res=1
	elif [ -d "$1$2" ] ; then				# $1$2 is a directory? OK. Install in chroot all (recur'y) found (in folder) chroot packages, chroot-ily.
			mycall="pacman -U \`find $2 -type f | grep -x \".*\\.pkg\\.tar\\.xz\"\`"
			chroot_this $1 "yes \"\" | $mycall"									|| res=3
	elif [ "$1" = "/" ] ; then				# Install specific (Internet-based) packages locally
			yes "" | pacman -S $needed_str $2										|| res=5
	else									# Install specific (Internet-based) packages in a chroot
			chroot_this $1 "yes \"\" | pacman -S $needed_str $2"					|| res=7
	fi
	return $res
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
	chroot_this $1 "cd $2; makepkg --skipchecksums --asroot --noextract -f" 2>&1 | pv $pvparam > $tmpfile|| failed "`cat $tmpfile` --- failed to chroot make $2 within $1"
	rm -f $tmpfile
}



chroot_pkgs_refresh() {
	local mycall
		mycall="pacman -Sy"
	chroot_this $1 "yes \"\" | $mycall" || echo "chroot_pkgs_refresh() -- WARNING --- '$mycall' (chrooted) returned an error"
}





chroot_pkgs_upgradeall() {
	local mycall
		mycall="pacman -Syu"
	chroot_this $1 "yes \"\" | $mycall" || echo "chroot_pkgs_upgradeall() -- WARNING --- '$mycall' (chrooted) returned an error"
}



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



chunkymunky() {
# Modify kernel's MMC or USB code in the following ways:-
# - if the detected device is on our whitelist, good :) support it :)
# - if the detected device is our "All clear" device (our registered boot device), good :) from now on, all devices are kosher!
# - if the detected device is neither 'all clear' dev nor on our whitelist, bad :( we reject it (and probably crash the kernel in the process)
	local myvar_name serialno haystack do_if_bad_serno snprintf_or_strcpy functext tolower do_if_good_serno last_eight opening_decs my_if int_or_str parole_clause remove_device varname
# Generate an inline C 'function' to display a given string & try to match it against the approved serial numbers
	varname=$1
	serialno="$2"
	knowngoodserials="$3"
	my_if="(needle!=NULL \\&\\& strlen(needle)>0 \\&\\& strstr(haystack,needle))"
	[ "$4" != "" ] && my_if="$4 \\|\\| $my_if"
	int_or_str=$5
	[ "$extra_if" != "" ] && extra_if="\\|\\| $extra_if"
	echo "$varname" | grep "udev" &> /dev/null && remove_device="usb_remove_device(udev);" || remove_device="mmc_remove_card(card);"
	opening_decs="char ndlbuff[32]={'\\\\0'}; char *needle=ndlbuff; char haystack[]=\\\"$knowngoodserials\\\"; "
	tolower="char \\*sss; for(sss=needle; \\*sss; sss++) { if (\\*sss>='A' \\&\\& \\*sss<='Z') \\*sss=\\*sss + 32; }"
	last_eight="while(strlen(needle)>8) { needle++; } "
	parole="if (strstr(needle,\\\"$serialno\\\") || strstr(\\\"$serialno\\\",needle)) { setPheasant(getPheasant()+1); printk(KERN_INFO \\\"I've caught a pheasant: %s\\\\n\\\", needle); } "
	do_if_good_serno="if (getPheasant()) { printk(KERN_INFO \\\"G,dc pheasant: %s\\\\n\\\", needle); } else { printk(KERN_INFO \\\"Good pheasant: %s\\\\n\\\", needle); } "
	do_if_bad_serno=" if (getPheasant()) { printk(KERN_INFO \\\"B,dc pheasant: %s\\\\n\\\", needle); } else { printk(KERN_ERR \\\"Bad pheasant... %s\\\\n\\\", needle); $remove_device } "
	if [ "$int_or_str" = "int" ] ; then
		snprintf_or_strcpy="snprintf(needle, 31, \\\"%08x\\\", $varname)"
	elif [ "$int_or_str" = "str" ] ; then
		snprintf_or_strcpy="snprintf(needle, 31, \\\"%s\\\", $varname)"
	else
		failed "$int_or_str - unknown chunkymunky param; should be int or str"
	fi
	functext="$opening_decs; $snprintf_or_strcpy; $tolower; $last_eight; $parole; if ($my_if) { $do_if_good_serno; } else { $do_if_bad_serno; }; "
	echo "$functext"
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




download_build_n_install_packages() {
	local res f pkgs root loops g tmpfile
	root=$1
	pkgs=$2
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	for f in $pkgs; do
		res=999
		loops=0
		while [ "$res" -ne "0" ] && [ "$loops" -le "10" ]; do
			chroot_pkgs_download		$root	$SOURCES_BASEDIR/$f "" &&res=0 || res=1
			loops=$(($loops+1))
		done
		[ "$res" -ne "0" ] && failed "Failed to download $f"
		chroot_pkgs_make	$root $SOURCES_BASEDIR/$f "" || failed "Failed to make $f"
		rm -Rf $root/var/lock	# opencryptoki (trousers?) leaves /var/lock in place. Bad! So, we have to work around it.
		chroot_pkgs_install	$root $SOURCES_BASEDIR/$f &> $tmpfile || failed "`cat $tmpfile` - Failed to install $f"
	done
	rm -f $tmpfile
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



format_partitions() {
	local dev dev_p temptxt
	dev=$1
	dev_p=$2
	temptxt=/tmp/$RANDOM$RANDOM$RANDOM
	echo -en "Formatting partitions..."
	echo -en "..."
	yes | mkfs.ext2 "$dev_p"2 &> $temptxt || failed "Failed to format p2 - `cat $temptxt`"
	echo -en "..."
	sleep 1; umount "$dev_p"* &> /dev/null || echo -en ""
	yes | mkfs.ext4 -v "$dev_p"3 &> $temptxt || failed "Failed to format p3 - `cat $temptxt`"
	echo -en "..."
	sleep 1; umount "$dev_p"* &> /dev/null || echo -en ""
	mkfs.vfat -F 16 "$dev_p"12 &> $temptxt || failed "Failed to format p12 - `cat $temptxt`"
	echo "Done."
	sleep 1; umount "$dev_p"* &> /dev/null || echo -en ""
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





get_number_ofcores() {
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




install_acpi_and_powerboom() {
	local f root
	root=$1
	echo "Configuring acpi and boom"
# Setup power button (10x => boom)
	echo -en "#!/bin/sh\nctrfile=/etc/.pwrcounter\n[ -e \"\$ctrfile\" ] || echo 0 > \$ctrfile\ncounter=\`cat \$ctrfile\`\ntime_since_last_pushed=\$((\`date +%s\`-\`stat -c %Y \$ctrfile\`))\n[ \"\$time_since_last_pushed\" -le \"1\" ] || counter=0\ncounter=\$((\$counter+1))\necho \$counter > \$ctrfile\nif [ \"\$counter\" -ge \"10\" ]; then\ne  cho \"Power button was pushed 10 times in rapid succession\" > $BOOMFNAME\n  exec /usr/local/bin/boom.sh\nfi\nexit 0\n" > $root/usr/local/bin/power_button_pushed.sh
	chmod +x $root/usr/local/bin/power_button_pushed.sh
	[ -e "$root/etc/acpi/handler.sh.orig" ] || mv $root/etc/acpi/handler.sh $root/etc/acpi/handler.sh.orig
	cat $root/etc/acpi/handler.sh.orig | sed s/"logger 'LID closed'"/"logger 'LID closed'; systemctl suspend"/ | sed s/"logger 'PowerButton pressed'"/"logger 'PowerButton pressed'; \\/usr\\/local\\/bin\\/power_button_pushed.sh"/ > $root/etc/acpi/handler.sh
	chmod +x $root/etc/acpi/handler.sh
	echo "f /sys/class/backlight/pwm-backlight.0/brightness 0666 - - - 800" > $root/etc/tmpfiles.d/brightness.conf
	chroot_this $root "systemctl enable acpid" || echo "WARNING - unable to enable acpid"
}




install_kernel() {
	local root boot kern dev dev_p specialbootblock fstype kernel_twelve_dev kernel_version_str recently_compiled_kernel signed_kernel tmpfile
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	cd /
	echo "Installing kernel"
		mkdir -p $boot/u-boot
		cp $root/boot/boot.scr.uimg $boot/u-boot
#cp $root/boot/{b,v}* $kern --- necessary?
		touch $root/boot/.mojo-jojo-was-here
		specialbootblock=nv_uboot-snow.kpart.bz2
		wget --quiet -O - http://commondatastorage.googleapis.com/chromeos-localmirror/distfiles/$specialbootblock > $TEMPDIR/$specialbootblock
		cat $TEMPDIR/$specialbootblock | bunzip2 > "$dev_p"1
		if [ "$WGET_PROXY" = "" ] ; then
			mv $root/etc/pacman.d/mirrorlist $root/etc/pacman.d/mirrorlist.orig
			cat $root/etc/pacman.d/mirrorlist.orig | sed s/#.*Server\ =/Server\ =/ > $root/etc/pacman.d/mirrorlist
		fi
		chroot_pkgs_refresh $root
		chroot_pkgs_install $root "linux-chromebook linux-headers-chromebook" &> $tmpfile || failed "`cat $tmpfile`" # necessary (dunno why)
}



install_gui_n_its_tools() {
	local res r pkgs do_it_again first_these root fstype loops
	root=$1
	fs=ext4 # During phase 1, everyhting is ext4. That way, when we've tweaked the kernel and rebooted, we can still read the fs. ;)
# FIXME Do we want xf86-video-fbdev, or do we want xf86-video-armsoc? Do we need xf86-input-mouse and/or xf86-input-keyboard?
	first_these="xorg-server xorg-xinit xorg-server-utils xorg-xmessage mesa xf86-video-fbdev xf86-video-armsoc xf86-input-synaptics mousepad icedtea-web-java7 rng-tools ttf-dejavu ntfs-3g gptfdisk xlockmore python3 python-setuptools python-pip bluez-libs alsa-plugins acpi sdl libcanberra libcanberra-gstreamer libcanberra-pulse pkg-config mplayer libnotify network-manager-applet wmii jwm dillo mpg123 talkfilters ffmpeg chromium xterm rxvt rxvt-unicode exo acpid bluez pulseaudio alsa-utils pm-utils notification-daemon syslog-ng nano cgpt parted bison flex expect autogen wmctrl expect java-runtime libxmu libxfixes libxpm pkg-config tor vidalia privoxy apache-ant junit xscreensaver gnome-keyring pyqt tzdata festival-us"
# We must have either urxvt or rxvt-unicode (they're the same thing, really)
	pkgs="$first_these lxde lxdm windowmaker"
	if [ "$pkgs" != "" ] ; then
		res=999
		loops=0
		while [ "$res" -ne "0" ] ; do
			chroot_pkgs_upgradeall $root
			chroot_pkgs_install $root "$pkgs" && res=0 || res=1
			loops=$(($loops+1))
			[ "$loops" -gt "20" ] && failed "We failed $loops times. We tried to install the Phase One packages, but we failed, precious."
		done
	fi
	cd $root/etc/X11/xorg.conf.d/
	rm *
	wget --quiet -O - bit.ly/1iH8lCr > x_alarm_chrubuntu.zip || failed "Failed to install x alarm chrubuntu zipfile" # Original came from http://craigerrington.com/blog/installing-arch-linux-with-xfce-on-the-samsung-arm-chromebook/ ---- thanks, Craig
	chroot_this $root "cd /etc/X11/xorg.conf.d/; unzip x_alarm_chrubuntu.zip" || failed "Failed to install Chromebook-friendly X11 config files"
	rm x_alarm_chrubuntu.zip # FIXME Use wget | tar -zx -C $root   :)
	f=10-keyboard.conf # Turn GB keyboard layout into US keyboard layout (config files were b0rked"
	mv $f $f.orig
	cat $f.orig | sed s/gb/us/ > $f
	mkdir -p $root/etc/tmpfiles.d
	echo "f /sys/devices/s3c2440-i2c.1/i2c-1/1-0067/power/wakeup - - - - disabled" >> $root/etc/tmpfiles.d/touchpad.conf
	echo "
(Parameter.set 'Audio_Method 'Audio_Command)
(Parameter.set 'Audio_Command \"aplay -q -c 1 -t raw -f s16 -r \$SR \$FILE\")
" >> $root/usr/share/festival/festival.scm

	echo "install_gui_n_its_tools - SUCCESS"
}



install_imptt_pkgs() {
	local root boot kern res loops
	root=$1
	boot=$2
	kern=$3
	res=999
	loops=0

	loops=0
	while [ ! -e "$root/usr/local/bin/dropbox_uploader.sh" ] ; do
		wget https://raw.github.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh --quiet -O - > $root/usr/local/bin/dropbox_uploader.sh || echo "WARNING - unable to download dropbox uploader. Retrying..."
		loops=$(($loops+1))
		[ "$loops" -ge "5" ] && failed "Failed to download dropbox uploader."
	done
	chmod +x $root/usr/local/bin/dropbox_uploader.sh
	chroot_pkgs_upgradeall $root
	chroot_pkgs_install $root "mkinitcpio"
	chroot_this $root "which mkinitcpio &> /dev/null" || failed "Please tell me how to install mkinitcpio"

# NB: We do not install jfsutils, xfsprogs, or btrfs-[progs|tools]. We build them from source; then we install our custom packages.
	while [ "$res" -ne "0" ] ; do
		chroot_pkgs_install $root "busybox curl systemd make gcc ccache patch git wget lzop pv ed sudo bzr xz automake autoconf bc cpio unzip libtool  dtc xmlto docbook-xsl uboot-mkimage wget cryptsetup dosfstools" && res=0 || res=1
		loops=$(($loops+1))
		[ "$loops" -gt "5" ] && failed "We failed $loops times. We tried to install the Phase One imptt pkgs, but we failed, precious."
	done

	mkdir -p $root/usr/local/bin/
}





move_all_data_from_p3_to_p2() {
	local root dev dev_p petname res f src_dev dest_dev dest_mount tmpfile
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	root=$1
	dev=$2
	dev_p=$3
	petname=$4
	src_dev=$5
	dest_dev=$6
	dest_mount=$7

# Migrate from p3 to p2
	if [ "$CRYPTOROOTDEV" != "" ] ; then
		res=999
		while [ "$res" -ne "0" ] ; do
			res=0
			echo -en "\n\n"
			echo "Type YES (not yes or Yes but YES). Then, please choose a strong"
			echo "password with which to encrypt root ('/'). Enter it three times."
			umount "$dev_p"2 || echo -en ""
			chroot_this $root "cryptsetup -v luksFormat "$dev_p"2 -c aes-xts-plain -y -s 512 -c aes -s 256 -h sha256 || res=1"
			[ "$res" -ne "0" ] && echo "Cryptsetup returned an error"
		done
		res=999
		while [ "$res" -ne "0" ]; do
			chroot_this $root "cryptsetup open "$dev_p"2 `basename $CRYPTOROOTDEV`" && res=0 || res=1
		done
		echo -en "\n\nRules for the 'boom' password:-\n1. Don't leave it blank.\n2. Don't use 'boom'.\n3. Don't reuse another password."
		res=999
		while [ "$res" -ne "0" ] ; do
			echo -en "\n\nChoose the 'boom' password : "
			read -s boompw
			echo -en "\nEnter a second time, please: "
			read -s boompwB
			echo ""
			if [ "$boompw" != "$boompwB" ]; then
				res=1
				echo "Passwords did not match"
			elif [ "$boompw" = "" ]; then
				res=2
				echo "A blank secondary password is not allowed"
			else
				res=0
			fi
		done
	fi

	echo "$boompw" | sha512sum | cut -d' ' -f1 > $root$BOOM_PW_FILE
	boompw=""
	boompwB=""

	echo -en "\nFormatting..."
	yes | mkfs.$fstype $format_opts $dest_dev &> $tmpfile ||failed "Failed to format for phase 2 - `cat $tmpfile`"	# Format p2 (or cryptroot) with kthx'd format

	echo -en "Cleaning up fstab..."
	mv $root/etc/fstab $root/etc/fstab.tmp
	cat $root/etc/fstab.tmp | grep -v " /boot " | grep -v " / " > $root/etc/fstab # fix p3's format str in fstab
	[ "$format_opts" = "" ] && [ "$fstype" != "ext4" ] && failed "For some reason, format_opts is blank again. Grr."

	echo -en "\nMigrating..."
	mount | grep "$src_dev " &> /dev/null || failed "copy_all_from_one_device_to_another() - $src_dev (source) is not mounted - weird"
	src_mount=$root
	mount | grep "$dest_dev " &> /dev/null&& failed "copy_all_from_one_device_to_another() - $dest_dev (dest) is already mounted - weird" || mkdir -p   $dest_mount
	mount $dest_dev $mount_opts $dest_mount || failed "Failed to mount $dest_dev (dest)"
	mkdir -p $dest_mount/{dev,proc,sys,tmp}
	for r in bin boot etc home lib mnt opt root run sbin srv usr var ; do
		echo -en "$r..."
		cp -af $src_mount/$r $dest_mount
	done
	echo "Done."
}




install_OS() {
	local root boot kern dev dev_p
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5

	[ -e "$root$RANDOMIZED_SERIALNO_FILE" ] && failed "Why are you re-rolling a custom kernel when I've already built a custom one?"
	randomized_serno=`generate_random_serial_number`

	echo "Downloading and installing OS. This will take several minutes."
#	wget -O - http://archlinuxarm.org/os/ArchLinuxARM-chromebook-latest.tar.gz | tar -zx -C $root || failed "Failed to dl/untar AL tarball"
	wget -O - bit.ly/QztPaD | tar -zx -C $root || failed "Failed to dl/untar AL tarball"
	wget --quiet -O - http://commondatastorage.googleapis.com/chromeos-localmirror/distfiles/$SNOWBALL > $TEMPDIR/$SNOWBALL
	mv $root/etc/resolv.conf $root/etc/resolv.conf.pristine || failed "Failed to save original resolv.conf"
	cp /etc/resolv.conf $root/etc/						    || failed "Failed to copy the ChromeOS resolv.conf into chroot"
	echo "$randomized_serno" > $root$RANDOMIZED_SERIALNO_FILE
	return 0
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

	cp $root$BOOM_PW_FILE $root$INITRAMFS_DIRECTORY/$RAMFS_BOOMFILE
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

	if [ "$rootdev" = "$CRYPTOROOTDEV" ] ; then
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
  echo \"\$password_str\" | cryptsetup open "$dev_p"2 `basename $CRYPTOROOTDEV`
  res=\$?
done
mount $mount_opts $CRYPTOROOTDEV /newroot
[ \"\$booming\" != \"\" ] && echo \"\$booming\" > /newroot/$BOOMFNAME || echo -en \"\"   # echo \"not booming... ok...\"
exit 0
"
	else
		login_shell_code="#!/bin/sh
mount $rootdev /newroot"
	fi

	echo "
proc  /proc      proc    defaults	0	0
tmpfs /run	 tmpfs	 defaults	0	0
devtmpfs /dev    devtmpfs defaults	0	0
sysfs	/sys	sysfs	defaults	0	0
proc	/proc	proc	defaults	0	0
" > $root$INITRAMFS_DIRECTORY/etc/fstab
	chmod 644 $root$INITRAMFS_DIRECTORY/etc/fstab

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
	umount /sys /proc	#Unmount all other mounts so that the ram used by the initramfs can be cleared after switch_root
	exec switch_root /newroot /sbin/init
else
	echo \"Failed to switch_root, dropping to a shell\"		#This will only be run if the exec above failed
	exec sh
fi
" > $root$INITRAMFS_DIRECTORY/init
# FYI, base64 uses -d in busybox but -D in the 'grown-up' version of base64; weird...!
	chmod 755 $root$INITRAMFS_DIRECTORY/init

	echo "$login_shell_code" > $root$INITRAMFS_DIRECTORY/log_me_in.sh
	chmod +x $root$INITRAMFS_DIRECTORY/log_me_in.sh
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



partition_device() {
	local dev dev_p
	dev=$1
	dev_p=$2
	ser=$3

	umount $root/{dev/pts,dev,proc,sys,tmp} &> /dev/null || echo -en "..."
	umount $root/{dev/pts,dev,proc,sys,tmp} &> /dev/null || echo -en "..."
	umount "$dev_p"* &> /dev/null || echo -en "..."
	umount "$dev_p"* &> /dev/null || echo -en "..."
	umount "$dev"* &> /dev/null || echo -en "..."
	umount "$dev"* &> /dev/null || echo -en "..."

	echo -en "Partitioning "$dev"...\r"
	parted -s $dev mklabel gpt
	cgpt create -z $dev
	cgpt create $dev
	cgpt add -i  1 -t kernel -b  8192 -s 32768 -l U-Boot -S 1 -T 5 -P 10 $dev
	cgpt add -i 12 -t data   -b 40960 -s 32768 -l Script $dev
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	lastblock=$(($lastblock-19999))	# FIXME Why do I do this?
	SPLITPOINT=$(($lastblock/2))

	cgpt add -i  2 -t data   -b 73728 -s `expr $SPLITPOINT - 73728` -l Kernel $dev
	cgpt add -i  3 -t data   -b $SPLITPOINT -s `expr $lastblock - $SPLITPOINT` -l Root $dev
	partprobe $dev
}



remove_junk_from_distro() {
	local root
	root=$1
	rm -Rf $root/var/cache/pacman/pkg
	rm -Rf $root/usr/share/gtk-doc
	rm -Rf $root/usr/share/man
	rm -Rf $root$KERNEL_SRC_BASEDIR/src/chromeos-3.4/Documentation
	rm -Rf $root/usr/src/linux-3.4.0-ARCH
	ln -sf $KERNEL_SRC_BASEDIR/src/chromeos-3.4 $root/usr/src/linux-3.4.0-ARCH || echo "That new ln of yours failed. Bummer."
	rm -Rf $root$RYO_TEMPDIR/ArchLinuxARM*.tar.gz $root/root/ArchLinuxARM*.tar.gz $root/ArchLinuxARM*.tar.gz
	rm -Rf $root$KERNEL_SRC_BASEDIR/*.tar.gz
	rm -Rf $root$KERNEL_SRC_BASEDIR/src/*.tar.gz
}





write_lxdm_post_login_script() {
	local unf
	liu=/tmp/.logged_in_user

	echo "
logger \"QQQ start of postlogin script\"
export DISPLAY=:0.0
echo \"\$USER\" > $liu

[ -e \"/usr/local/bin/chrubix.sh\" ] && sudo /usr/local/bin/chrubix.sh &> /tmp/.chrubix.err &

sleep 2
if ps -o pid -C wmaker &>/dev/null; then
  wmsystemtray &
  sleep 0.3
fi

if ! ps -o pid -C nm-applet &> /dev/null; then
  nm-applet &
fi
sleep 0.3


#nm-connection-editor &

. /etc/bash.bashrc
. /etc/profile
xscreensaver -no-splash &

logger \"QQQ end of postlogin script... but not really. Now, I'll keep an eye on the Internet. If it disconnects, I'll offer a manual login screen.\"

/usr/local/bin/keep_me_online.sh &

"


}



write_lxdm_post_logout_script() {
	local unf
	liu=/tmp/.logged_in_user

	echo "
rm -f $liu

logger \"QQQ - terminating current user session and restarting lxdm\"
killall PostLogin || echo -en \"\"
killall keep_me_online.sh || echo -en \"\"
# Terminate current user session
/usr/bin/loginctl terminate-session \$XDG_SESSION_ID
# Restart lxdm
/usr/bin/systemctl restart lxdm.service
"
}



write_lxdm_pre_login_script() {
	local unf
	liu=/tmp/.logged_in_user

	echo "
mkdir -p $GUEST_HOMEDIR
chmod 700 $GUEST_HOMEDIR
#echo -en \"[Desktop]
#Session=/usr/bin/startlxde              # wmaker!
#\" > $GUEST_HOMEDIR/.dmrc
chown -R guest.guest $GUEST_HOMEDIR
$STOP_JFS_HANGUPS
"
}



write_lxdm_xresources_addendum() {
# ------- vvv XRESOURCES vvv ------- Make sure rxvf etc. will use chromium to open a web browser if user clicks on http:// link
	echo "
UXTerm*VT100*translations: #override Shift <Btn1Up>: exec-formatted("/usr/local/bin/run_browser_as_guest.sh '%t'", PRIMARY)
UXTerm*charClass: 33:48,36-47:48,58-59:48,61:48,63-64:48,95:48,126:48
URxvt.perl-ext-common: default,matcher
URxvt.url-launcher: /usr/local/bin/run_browser_as_guest.sh
URxvt.matcher.button: 1
"
}





setup_dbus_and_sudo() {
	local root dev dev_p petname
	root=$1
	dev=$2
	dev_p=$3
	petname=$4
	mkdir -p $root/usr/share/dbus-1/services
	echo -en "[D-BUS Service]\nName=org.freedesktop.Notifications\nExec=/usr/lib/notification-daemon-1.0/notification-daemon\n" > $root/usr/share/dbus-1/services/org.gnome.Notifications.service # See https://wiki.archlinux.org/index.php/Desktop_notifications
	sync; tweak_fstab_n_locale     $root                     $dev_p $petname	# FIXME remove this ... after testing :)
	echo "
%wheel ALL=(ALL) ALL
ALL ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff,/usr/bin/systemctl halt,/usr/bin/systemctl reboot,/usr/local/bin/tweak_lxdm_and_reboot,/usr/local/bin/tweak_lxdm_and_shutdown,/usr/local/bin/run_as_guest.sh,/usr/local/bin/chrubix.sh
" >> $root/etc/sudoers
	echo -en "search localhost\nnameserver 8.8.8.8\n" >> $root/etc/resolv.conf
}


fix_autogenerator_wagon() {
	local root autogenerator_fname
	root=$1
	autogenerator_fname="/usr/lib/systemd/system-generators/systemd-gpt-auto-generator"
	[ -e "$root$autogenerator_fname" ] && mv $root$autogenerator_fname $root/etc/.ssgsgag.disabled # to stop silly error messages
	cp $root/usr/bin/true $root$autogenerator_fname
}



redo_mbr() {
	local dev_p root
	root=$1
	dev_p=$2
	[ -e "$root$BOOM_PW_FILE" ] || failed "No boom pw cksum file"
	rm -f $root$KERNEL_SRC_BASEDIR/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg
	rm -f $root/root/.vmlinuz.signed
	rm -f `find $root$KERNEL_SRC_BASEDIR | grep initramfs | grep lzma | grep -vx ".*\.h"`
	make_initramfs_hybrid $root $CRYPTOROOTDEV
	chroot_pkgs_make $root $KERNEL_SRC_BASEDIR 39600
	sign_and_write_custom_kernel $root "$dev_p"1 $CRYPTOROOTDEV "cryptdevice="$dev_p"2:`basename $CRYPTOROOTDEV`" "" # TODO try "$dev_p"3
}



install_chrubix() {
	local root
	root=$1
	mkdir -p $root/usr/local/bin/Chrubix
	wget bit.ly/1hIK2nQ --quiet -O - | tar -Jx -C $root/usr/local/bin/Chrubix || failed "Failed to install chrubix Python code"
	echo "#!/bin/sh
if [ \"\$USER\" != \"root\" ] ; then
  echo \"Please type sudo in front of the call to run me.\"
  exit 1
fi
if ping -c1 -W5 8.8.8.8 &> /dev/null ; then
  rm -Rf   /usr/local/bin/Chrubix /usr/local/bin/1hq8O7s
  mkdir -p /usr/local/bin/Chrubix
  wget bit.ly/1hIK2nQ --quiet -O - | tar -Jx -C /usr/local/bin/Chrubix
  wget bit.ly/1hq8O7s --quiet -O - > /usr/local/bin/Chrubix/src/1hq8O7s
fi
export DISPLAY=:0.0
cd /usr/local/bin/Chrubix/src
python3 main.py
exit \$?
" > $root/usr/local/bin/chrubix.sh
}



build_chrubix_on_mmc() {
	local mydevbyid dev dev_p orig_dev petname root boot kern cores fstype src_dev dest_dev src_mount dest_mount fsurl fscommand
	root=/tmp/_root # /tmp/$RANDOM$RANDOM$RANDOM
	boot=/tmp/_boot # /tmp/$RANDOM$RANDOM$RANDOM
	kern=/tmp/_kern # /tmp/$RANDOM$RANDOM$RANDOM
	mydevbyid=$1
	cores=1									# 1 # `get_number_ofcores`
	[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
	[ -e "$mydevbyid" ] || failed "Please insert a thumb drive or SD card and try again. Please DO NOT INSERT your keychain thumb drive."
	dev=`deduce_dev_name $mydevbyid`
	dev_p=`deduce_dev_stamen $dev`
	petname=`find_boot_drive | cut -d'-' -f3 | tr '_' '\n' | tail -n1 | awk '{print substr($0,length($0)-7);}' | tr '[:upper:]' '[:lower:]'`
	orig_dev=$mydevbyid
	set_the_fstab_format_and_mount_opts

# TEST PORPOISES
# Eventually, this whole procedure will run from start to finish... and then save the filesystem to a tarball on $kern ("$dev_p"2).
# That tarball will be uploaded to Dropbox, whence it will be downloaded & used by stage1.sh :)

	partition_device $dev $dev_p $petname
	format_partitions $dev $dev_p
	sync; mount_everything         $root $boot $kern $dev $dev_p
	fsurl=`find /home/chronos -name alarm-root.tar.xz 2> /dev/null | head -n1`
	[ "$fsurl" != "" ] && fscommand="cat $fsurl" || fsurl=bit.ly/1idXPUN
	echo "Please wait while I write the root filesystem from $fsurl to "$dev"..."
	if ! $fscommand | tar -Jx -C $root ; then
		echo "Fine. We'll do things the hard way."
		sync; install_OS               $root $boot $kern $dev $dev_p || failed "Failed to install OS..."
		mkdir -p $root/{dev,sys,proc,tmp}
		mount devtmpfs $root/dev -t devtmpfs|| failed "Failed to mount /dev"
		mount sysfs $root/sys -t sysfs		|| failed "Failed to mount /sys"
		mount proc $root/proc -t proc		|| failed "Failed to mount /proc"
		mount tmpfs $root/tmp -t tmpfs		|| failed "Failed to mount /tmp"
		sync; tweak_package_manager	   $root
		sync; install_kernel           $root $boot $kern $dev $dev_p
		sync; install_imptt_pkgs       $root $boot $kern
		sync; setup_gui_kernel_n_tools $root $boot $kern $dev $dev_p $petname $cores # install GUI; build kernel; install tor etc.
		sync; tweak_fstab_n_locale     $root                  $dev_p $petname
		sync; install_timezone		   $root	|| failed "install_timezone() failed"
		sync; setup_postinstall        $root
		sign_and_write_custom_kernel   $root "$dev_p"1 "$dev_p"3 "" ""		# FIXME is this necessary?
		install_acpi_and_powerboom     $root
		add_reboot_user			 $root	|| failed "add_reboot_user() failed"
		add_shutdown_user		 $root	|| failed "add_shutdown_user() failed"
		add_guest_user			 $root	|| failed "add_guest_user() failed"
		fix_autogenerator_wagon $root	|| failed "Failed to fix GPT autogenerator" # It generates annoying messages
		wget --quiet -O - bit.ly/1mj99jZ | tar -zx -C $root || echo "WARNING --- unable to install vbutil.tgz (vbutil_kernel etc.)"
		setup_dbus_and_sudo		 $root $dev $dev_p $petname || failed "setup_dbus_and_sudo() failed"
		add_guest_browser_script $root	|| failed "add_guest_browser_script() failed"
		activate_gui_and_wifi	 $root	|| failed "activate_gui_and_wifi() failed"
		install_chrubix			 $root  || failed "Failed to install Chrubix"
		chmod +x $root/usr/local/bin/*
		tweak_chrome			 $root	|| failed "tweak_chrome() failed"
		#chroot_pkgs_install $root "gnome-keyring" || failed "Unable to install gnome-keyring"  # Why whould we need to?
		download_build_n_install_packages $root "freenet wmsystemtray" # i2p (one day) .. and trousers opencryptoki tpm-tools
		configure_tor_and_privoxy	 $root	|| failed "Failed to setup privacy tools"
		for r in dev/pts dev sys proc tmp ; do
			umount $root/$r &> /dev/null || echo -en "..."
		done
		cd $root
		remove_junk_from_distro		   $root
		tar -cJ * > $kern/alarm-root.tar.xz
		failed "Please copying $kern/alarm-root.tar.xz to your /home/user/chronos/Downloads folder :)"
	else
		echo "Please delete /home/user/chronos/Downloads/alarm-root.tar.xz and try again... Or, if you want to install ArchLinux, use this instead:"
		echo "# cd && wget bit.do/that -O chrubix && sudo bash chrubix"
		echo ""
		failed "Terminating :-p"
	fi
}



do_phase2_audio_stuff() {
	local f
	echo -en "Adjusting mixer etc."
	amixer sset Speaker unmute &> /dev/null  || echo "WARNING - unable to set speaker on unmute"
	amixer sset Speaker 30%    &> /dev/null  || echo "WARNING - unable to set speaker volume"
	for f in `amixer | grep Speaker | cut -d"'" -f2 | tr ' ' '^'`; do
		g=`echo "$f" | tr '^' ' '`
		amixer sset "$g" unmute &> /dev/null && echo -en "..." || echo "Unable to unmute $g"
	done
	which alsactl &> /dev/null && alsactl store &> /dev/null # I've no idea if this helps or not

	echo "#!/bin/sh
tmpfile=/tmp/\$RANDOM\$RANDOM\$RANDOM
echo \"\$1\" | text2wave > \$tmpfile
aplay \$tmpfile &> /dev/null
rm -f \$tmpfile
" > /usr/local/bin/sayit.sh
	chmod +x /usr/local/bin/sayit.sh

	echo "Done."
}



sizeof() {
	echo $(du -sb "$1" | awk '{ print $1 }')
}



setup_display_manager() {                   # This paves the way for phase 3. WE MUST start as root when doing phase 3.
	local f unf root dejavu_lockfile
	local root
	root=$1
	f=/etc/lxdm/lxdm.conf
	[ -e "$root$f" ] || failed "$root$f does not exist. Setup_display_manager() cannot run properly. That sucks."
	cat $root$f | \
sed s/.*autologin=.*/autologin=guest/ | \
sed s/.*skip_password=.*/skip_password=1/ | \
sed s/.*session=.*/session=\\\/usr\\\/bin\\\/wmaker/ > $root$f.first
cat $root$f | sed s/.*autologin=.*/###autologin=/ | sed s/.*skip_password=.*/skip_password=1/ > $root$f.second

	write_lxdm_post_login_script		>> $root/etc/lxdm/PostLogin
	generate_startx_addendum			>> $root/etc/lxdm/PreLogin
	write_lxdm_pre_login_script			>> $root/etc/lxdm/PreLogin
	echo ". /etc/X11/xinitrc/xinitrc"	>> $root/etc/lxdm/Xsession
	write_lxdm_post_logout_script		>> $root/etc/lxdm/PostLogout
	write_lxdm_xresources_addendum		>> $root/root/.Xresources

rm -f $root$f
touch $root/etc/.first_time_ever

# Setup ersatz lxdm
	echo "#!/bin/sh

if [ -e \"/etc/.first_time_ever\" ] ; then
	cp $f.first $f
	echo \"### Woah... It's my first time EVER...\" >> $f
	rm -f /etc/.first_time_ever
#	touch /tmp/.okConnery.thisle.44
elif [ -e \"/tmp/.okConnery.thisle.44\" ] ; then
	cp $f.second $f
	echo \"### Second time around, eh?\" >> $f
else
    cp $f.first $f
	echo \"### Be gentle. It's my first time.\" >> $f
	touch /tmp/.okConnery.thisle.44
fi
lxdm
exit \$?
" > $root/usr/local/bin/ersatz_lxdm.sh
	chmod +x $root/usr/local/bin/ersatz_lxdm.sh

	chroot_this $root "systemctl enable lxdm" || failed "Failed to activate lxdm display manager"
	[ -h "$root/etc/systemd/system/display-manager.service" ] || failed "lxdm han't registered itself in systemd"
	cat $root/usr/lib/systemd/system/lxdm.service | sed s/ExecStart=.*/ExecStart=\\\/usr\\\/local\\\/bin\\\/ersatz_lxdm.sh/ > /tmp/.t.t
	cat /tmp/.t.t > $root/usr/lib/systemd/system/lxdm.service # $root/usr/lib/systemd/system/lxdm.service

	echo "#!/bin/sh

export DISPLAY=:0.0
while [ "black" != "white" ] ; do
  if ! ifconfig | fgrep \"inet \" | fgrep -v 127.0.0.1 &>/dev/null ; then
    sleep 5
    if ! ifconfig | fgrep \"inet \" | fgrep -v 127.0.0.1 &>/dev/null; then
      urxvt -geometry 120x20+0+320 -name \"WiFi Setup\" -e sh -c \"/usr/local/bin/wifi_manual.sh\" &
      procno=\$!
      while ! ifconfig | fgrep \"inet \" | fgrep -v 127.0.0.1 &>/dev/null; do
        sleep 0.5
      done
      sleep 1
      kill \$procno || echo -en \"\"
    fi
  fi
done
" > $root/usr/local/bin/keep_me_online.sh
	chmod +x $root/usr/local/bin/keep_me_online.sh
}



install_timezone() {
	local utc_hr loc_hr gmt_diff new_tz root
	root=$1
	utc_hr=`date -u +%H | sed s/00/0/ | sed s/01/1/ | sed s/02/2/ | sed s/03/3/ | sed s/04/4/ | sed s/05/5/ | sed s/06/6/| sed s/07/7/ | sed s/08/8/ | sed s/09/9/`
	loc_hr=`date +%H | sed s/00/0/ | sed s/01/1/ | sed s/02/2/ | sed s/03/3/ | sed s/04/4/ | sed s/05/5/ | sed s/06/6/| sed s/07/7/ | sed s/08/8/ | sed s/09/9/`
	gmt_diff=$(($loc_hr-$utc_hr))
	new_tz=GMT"$gmt_diff"
	ln -sf /usr/share/zoneinfo/posix/Etc/$r $root/etc/localtime
}







setup_rootpassword() {
	local res root
	root=$1
	res=999
	while [ "$res" -ne "0" ] ; do
		echo -en "\nNow, please choose a root password.\n"
		chroot_this $root "passwd" && res=0 || res=1
	done
}



configure_tor_and_privoxy() {
	local f proxy_str root
	root=$1

	echo "Configuring tor and privoxy"
	echo "
#this directs ALL requests to the tor proxy
forward-socks4a / localhost:9050 .
forward-socks5 / localhost:9050 .
#this forwards all requests to I2P domains to the local I2P proxy without dns requests
forward .i2p localhost:4444
#this forwards all requests to Freenet domains to the local Freenet node proxy without dns requests
forward ksk@ localhost:8888
forward ssk@ localhost:8888
forward chk@ localhost:8888
forward svk@ localhost:8888
" >> $root/etc/privoxy/config

# Enable them, but don't bother starting any of them. We're about to reboot, after all.

# FIXME Is this necessary? YES. These tools are started (not enabled) by post-login script. They are NOT enabled at boot-up. They are STARTED automatically by the postlogin script.
	for f in privoxy tor freenet; do # i2p
		chroot_this $root "systemctl enable $f"
	done
}





activate_gui_and_wifi() {
	local my_dm res f root
	root=$1

	echo -en "Enabling GUI..."
	chroot_this $root "which lxdm 2> /dev/null" && echo -en "" || failed "Where is lxdm? I need lxdm (the display manager). Please install it."
	chroot_this $root "which kdm 2> /dev/null" && chroot_this "systemctl disable kdm" || echo -en ""
	setup_display_manager $root      # Necessary, to make sure we log in as root (into GUI) at start of phase 3
	f=$root/etc/WindowMaker/WindowMaker
	if [ -e "$f" ] ; then
		mv $f $f.orig
		cat $f.orig | sed s/MouseLeftButton/flibbertygibbet/ | sed s/MouseRightButton/MouseLeftButton/ | sed s/flibbertygibbet/MouseRightButton/ > $f
	fi
# If the user is online, start the Display Manager. If not, start nmcli (which will let the user choose a wifi connection).
	generate_wifi_manual_script   > $root/usr/local/bin/wifi_manual.sh
	generate_wifi_auto_script     > $root/usr/local/bin/wifi_auto.sh
	chmod +x $root/etc/X11/xinit/xinitrc
	cd /tmp
	echo -en "Disabling old netctl" # See https://wiki.archlinux.org/index.php/NetworkManager#nmcli_examples
	chroot_this $root "systemctl disable netctl.service" && echo -en "..." || echo -en ",,,"
	chroot_this $root "systemctl disable netcfg.service" && echo -en "..." || echo -en ",,,"
	chroot_this $root "systemctl disable netctl"	     && echo -en "..." || echo -en ",,,"
	chroot_this $root "systemctl enable NetworkManager" || failed "Unable to enable NetworkManager"

	echo "Done."
}





generate_wifi_auto_script() {
	echo -en "#/bin/sh
lockfile=/tmp/.go_online_auto.lck
try_to_connect() {
  local lst res netname_tabbed netname
  logger \"QQQ wifi-auto --- Trying to connect to the Internet...\"
  r=\"\`nmcli con status | grep -v \"NAME.*UUID\" | wc -l\`\"
  if [ \"\$r\" -gt \"0\" ] ; then
    if ping -W5 -c1 8.8.8.8 ; then
	  logger \"QQQ wifi-auto --- Cool, we're already online. Fair enough.\"
      return 0
    else
      logger \"QQQ wifi-auto --- ping failed. OK. Trying to connect to Internet.\"
    fi
  fi
  lst=\"\`nmcli con list | grep -v \"UUID.*TYPE.*TIMESTAMP\" | sed s/\\ \\ \\ \\ /^/ | cut -d'^' -f1 | tr ' ' '^'\`\"
  res=999
  for netname_tabbed in \$lst \$lst \$lst ; do # try thrice
    netname=\"\`echo \"\$netname_tabbed\" | tr '^' ' '\`\"
	logger \"QQQ wifi-auto --- Trying \$netname\"
	nmcli con up id \"\$netname\"
	res=\$?
	[ \"\$res\" -eq \"0\" ] && break
	echo -en \".\"
	sleep 1
  done
  if [ \"\$res\" -eq \"0\" ]; then
	logger \"QQQ wifi-auto --- Successfully connected to WiFi - ID=\$netname\"
  else
	logger \"QQQ wifi-auto --- failed to connect; Returning res=\$res\"
  fi

  return \$res
}
# -------------------------
logger \"QQQ wifi-auto --- trying to get online automatically\"
if [ -e \"\$lockfile\" ] ; then
  p=\"\`cat \$lockfile\`\"
  while ps \$p &> /dev/null ; do
    logger \"QQQ wifi-auto --- Already running at \$\$. Waiting.\"
	sleep 1
  done
fi
echo \"\$\$\" > \$lockfile
chmod 700 \$lockfile
try_to_connect
res=\$?
rm -f \$lockfile
exit \$?
"
}




generate_wifi_manual_script() {
	echo -en "#/bin/sh
lockfile=/tmp/.go_online_manual.lck
manual_mode() {
logger \"QQQ wifi-manual --- starting\"
res=999
#clear
  while [ \"\$res\" -ne \"0\" ] ; do
    echo -en \"Searching...\"
	all=\"\"
	while [ \"\`echo \"\$all\" | wc -c\`\" -lt \"4\" ] ; do
		all=\"\`nmcli device wifi list | grep -v \"SSID.*BSSID\" | sed s/'    '/^/ | cut -d'^' -f1 | awk '{printf \", \" substr(\$0,2,length(\$0)-2);}' | sed s/', '//\`\"
		sleep 1
		echo -en \".\"
	done
    echo \"\n\nAvailable networks: \$all\" | wrap -w 79
    echo \"\"
    echo -en \"WiFi ID: \"
	read id
	[ \"\$id\" = \"\" ] && return 1
	echo -en \"WiFi PW: \"
	read pw
	echo -en \"Working...\"
	nmcli dev wifi connect \"\$id\" password \"\$pw\" && res=0 || res=1
	[ \"\$res\" -ne \"0\" ] && echo \"Bad ID and/or password. Try again.\" || echo \"Success\"
  done
  return 0
}
# -------------------------
manual_mode
exit \$?
"
}




generate_startx_addendum() {
	echo "
# dpms, no audio bell; see https://www.notabilisfactum.com/blog/?page_id=7
logger \"QQQ start of startx addendum\"
export DISPLAY=:0.0
xhost +
logger \"QQQ startx 0000\"
localectl set-locale en_US.utf8
localectl set-keymap us
logger \"QQQ startx aaaa\"
setxkbmap us
localectl set-x11-keymap us
xset s off
logger \"QQQ startx bbbb\"
xset -dpms
xset -b
xset m 30/10 3
logger \"QQQ startx cccc\"
syndaemon -t -k -i 1 -d    # disable mousepad for 1s after typing finishes
logger \"QQQ startx end of startx addendum\"
"
}




add_guest_browser_script() {
	local root
	root=$1
	echo "H4sIAF52SVMAA1WMvQrCMBzE9zzF2YYukkYfoBbBVQXnTKZ/TaBJpEmhQx/eUNTidMd9/MqNvFsvo2EsudfD9tTIbGQXhKOa346X0/X8L3UekzYBgjyK8gtQnu+Vp8kmKN4qX+AA/mEybVzosJ3WJI4QPZ4jxQShfzmqCgPFZod5Xgxv2eDW28LnuWBvkUV8bboAAAA=" | base64 -d | gunzip > $root/usr/local/bin/run_as_guest.sh
	chmod +x $root/usr/local/bin/run_as_guest.sh

	echo "#!/bin/sh
sudo /usr/local/bin/run_as_guest.sh \"export DISPLAY=:0.0; chromium --user-data-dir=$GUEST_HOMEDIR \$1\"
exit \$?
" > $root/usr/local/bin/run_browser_as_guest.sh					# Yes, we use $GUEST_HOMEDIR, not \$GUEST_HOMEDIR :-)
	chmod +x $root/usr/local/bin/run_browser_as_guest.sh
}







add_guest_user() {
	local root tmpfile
	root=$1
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	echo -en "Adding guest user..."
	mkdir -p $root$GUEST_HOMEDIR
	chroot_this $root "useradd guest -d $GUEST_HOMEDIR"
	chmod 700 $root$GUEST_HOMEDIR
	chroot_this $root "chown -R guest.guest $GUEST_HOMEDIR"
	mv $root/etc/shadow $tmpfile
	cat $tmpfile | sed s/'guest:!:'/'guest::'/ > $root/etc/shadow
	echo "Done."
	chroot_this $root "usermod -a -G tor guest"
	rm -f $tmpfile
}



add_reboot_user() {
	local root tmpfile
	root=$1
	add_zz_user_SUB $root reboot
	return $?
}



add_shutdown_user() {
	local root tmpfile
	root=$1
	add_zz_user_SUB $root shutdown
	return $?
}



add_zz_user_SUB() {
	local username tmpfile userhome cmd f root
	root=$1
	username=$2
	cmd=$username
	[ "$username" = "shutdown" ] && cmd=poweroff
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	userhome=$root/etc/.$username
	echo -en "Adding $username user..."
	mkdir -p $root$userhome
	chroot_this $root "useradd $username -d $userhome"
	chmod 700 $root$userhome
	chroot_this $root "chown -R $username.$username $userhome"
	mv $root/etc/shadow $tmpfile
	cat $tmpfile | sed s/$username':!:'/$username'::'/ > $root/etc/shadow
	rm -f $tmpfile
	echo "#!/bin/sh

sudo tweak_lxdm_and_$username
" > $root$userhome/.profile
	chmod +x $root$userhome/.profile
	chroot_this $root "chown $username.$username $userhome/.profile"

#	echo "cmd=$cmd"
	echo "#!/bin/sh
sync;sync;sync
systemctl $cmd
exit 0
" > $root/usr/local/bin/tweak_lxdm_and_$username
	chmod +x $root/usr/local/bin/tweak_lxdm_and_$username

	echo "Done."
}




tweak_chrome() {
	local root chromefile
	root=$1
	chromefile=$root/`chroot_this $root "which chromium"` || failed "Fannot find chromium"
	[ ! -e "$chromefile.forreals" ] && mv $chromefile $chromefile.forreals
	echo -en "#!/bin/sh
if ps -o pid -C privoxy &>/dev/null; then
#if ps wax | grep privoxy | grep -v grep ; then
  chromium.forreals --proxy-server=http://localhost:8118 \$@
else
  chromium.forreals \$@
fi
exit \$?
" > $chromefile
	chmod +x $chromefile
}




function ctrl_c() {
	echo "** Trapped CTRL-C"
}



modify_all() {
# Modify all source files - kernel, mkbtrfs, mkxfs, etc. - in preparation for their recompiling
	local serialno haystack randomized_serno root
	root=$1
	serialno=$2
	haystack=$3
	[ "$serialno" = "" ] && failed "modify_all() --- blank serialno"
	[ "$haystack" = "" ] && failed "modify_all() --- blank haystack"
	[ -e "$root$RANDOMIZED_SERIALNO_FILE" ] && randomized_serno=`cat $root$RANDOMIZED_SERIALNO_FILE` || failed "You've already mod'd src. Why call me?"
	[ "$serialno" = "" ] && failed "modify_all() was supplied with an empty serialno"
	[ "$haystack" = "" ] && failed "modify_all() was supplied with an empty haystack"
	echo "Modifying source files; serialno=$serialno; haystack=$haystack"
	modify_kernel_config_file $root $KERNEL_SRC_BASEDIR/src/chromeos-3.4
	modify_kernel_init_source $root/$KERNEL_SRC_BASEDIR/src/chromeos-3.4 # FIXME This probably isn't needed UNLESS kthx and/or pheasants
	modify_magics_and_superblocks $randomized_serno "$haystack"
	modify_kernel_usb_source $root/$KERNEL_SRC_BASEDIR/src/chromeos-3.4 $serialno "$haystack"
	modify_kernel_mmc_source $root/$KERNEL_SRC_BASEDIR/src/chromeos-3.4 $serialno "$haystack"
	[ "$NOPHEASANTS" != "" ] && echo "$NOPHEASANTS" > $root/etc/.nopheasants || rm -f $root/etc/.nopheasants
	[ "$NOKTHX" != "" ] && echo "$NOKTHX"      > $root/etc/.nokthx || rm -f $root/etc/.nokthx
	tweak_sources_according_to_noktxh_and_nopheasants_variables $root
}



modify_kernel_config_file() {
# Enable block devices, initramfs, built-in xfs, etc.
	local fname pwd res chromeos_kernel_src
	root=$1
	chromeos_kernel_src=$2
	pwd=`pwd`
	cd $1/$chromeos_kernel_src
	fname=.config
	[ ! -e "$fname.orig" ] && mv $fname $fname.orig
	touch $fname
	cat $fname.orig | sed s/XFS_FS=m/XFS_FS=y/ | sed s/JFFS2_FS=m/JFFS2_FS=y/ | sed s/CONFIG_ECRYPT_FS=m/CONFIG_ECRYPT_FS=y/ > $fname
	echo -en "Modifying kernel makefile..."
	if [ "$INITRAMFS_DIRECTORY" != "" ] ; then
		echo "CONFIG_BLK_DEV_RAM=y
CONFIG_BLK_DEV_RAM_COUNT=1
CONFIG_BLK_DEV_RAM_SIZE=8192
CONFIG_BLK_DEV_RAM_BLOCKSIZE=1024
CONFIG_INITRAMFS_SOURCE=\"$INITRAMFS_DIRECTORY\"
CONFIG_INITRAMFS_COMPRESSION_LZMA=y
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
BLK_DEV_RAM=y
BLK_DEV_RAM_COUNT=1
BLK_DEV_RAM_SIZE=8192
BLK_DEV_RAM_BLOCKSIZE=1024
INITRAMFS_SOURCE=\"$INITRAMFS_DIRECTORY\"
INITRAMFS_ROOT_UID=0
INITRAMFS_ROOT_GID=0
INITRAMFS_COMPRESSION_LZMA=y
CONFIG_DECOMPRESS_LZMA=y
CONFIG_RD_LZMA=y
CONFIG_HAVE_KERNEL_LZMA=y
BLK_DEV_XIP=n
CONFIG_DM_MIRROR=m
CONFIG_DM_RAID=m
CONFIG_DM_SNAPSHOT=m
CONFIG_DM_ZERO=m
CONFIG_DM_UEVENT=m
CONFIG_DM_THIN_FINISHING=m
CONFIG_TRUSTED_KEYS=y
CONFIG_ENCRYPTED_KEYS=y
CONFIG_SECURITY_DMESG_RESTRICT=y
CONFIG_SECURITY=y
CONFIG_CRYPTO_GF128MUL=y
CONFIG_CRYPTO_XTS=y
CONFIG_CRYPTO_ANSI_CPRNG=y
" >> $fname
	fi
	echo "CONFIG_ECRYPT_FS_MESSAGING=n" >> $fname
	chroot_this $root "cd $chromeos_kernel_src; echo -en \"4\\n\\n\\n\\n\\n\\n\\n\" | make oldconfig" &> /tmp/.makemenuconfig && res=0 || res=1    # The '4' is for the LZMA compression thingumabob.
	cp -f $fname ../../config
	cd $pwd
	if [ "$res" -ne "0" ] ; then
		cat /tmp/.makemenuconfig
		failed "Kernel make FAILED."
	else
		echo "Done."
	fi
}



modify_kernel_mmc_source() {
# Modify mmc-related kernel sources, to make sure unfriendly MMC devices are rejected
	local serialno mmc_file sd_file haystack replacement key_str extra_if root
	chromeos_kernel_src=$1
	serialno=$2
	haystack=$3
	extra_if="needle==NULL \\|\\| strlen(needle)==0"
	echo "Modifying kernel mmc source"
	mmc_file=`find $chromeos_kernel_src/drivers/mmc -name mmc.c`
	sd_file=`find  $chromeos_kernel_src/drivers/mmc -name sd.c`

	echo "Modifying $mmc_file"
	key_str="Select card, "
	replacement="$key_str `chunkymunky "card->cid.serial" "$serialno" "$haystack" "$extra_if" int`"
	modify_kernel_source_file "$mmc_file" "$key_str" "$replacement"

	echo "Modifying $sd_file"
	key_str="if read-only switch"
	replacement="$key_str \*\/ `chunkymunky "card->cid.serial" "$serialno" "$haystack" "$extra_if" int` \/\* "
	modify_kernel_source_file "$sd_file" "$key_str" "$replacement"
}



modify_kernel_source_file() {
	local key_str replacement data_file
	data_file=$1
	key_str=$2
	replacement=$3
	[ ! -e "$data_file.pristine.phezPristine" ] && cp $data_file $data_file.phezPristine
	[ ! -e "$data_file.orig" ] && mv $data_file $data_file.orig
	echo "// modified automatically by $0 on `date`
extern int getPheasant(void);
extern void setPheasant(int);

" > $data_file
	grep "$key_str" $data_file.orig > /dev/null || failed "Unable to find \"$key_str\" in $data_file.orig"
	cat $data_file.orig | sed s/"$key_str"/"$replacement"/ >> $data_file # | sed -e ':loop' -e 's/\;\ /\;\n/' -e 't loop' >> $data_file
	rm $data_file.orig
	cp -f $data_file $data_file.phezSullied
	rm $data_file
	[ ! -e "$data_file.phezPristine" ] && failed "$data_file.pristine missing"
	[ ! -e "$data_file.phezSullied"  ] && failed "$data_file.sullied missing"
}



modify_kernel_usb_source() {
# Modify mmc-related kernel sources, to make sure unfriendly USB devices are rejected
	local serialno core_file haystack replacement key_str extra_if noserno is_hub_or_webcam is_utterly_dead chromeos_kernel_src
	chromeos_kernel_src=$1
	serialno=$2
	haystack=$3
	noserno="(needle==NULL \\|\\| strlen(needle)==0 \\|\\| !strcmp(needle, \\\"(null)\\\"))"
	is_hub_or_webcam="(udev->product!=NULL \\&\\& strlen(udev->product)>0 \\&\\& (strstr(udev->product, \\\"Hub\\\") \\|\\| strstr(udev->product, \\\"WebCam\\\")))"
	is_utterly_dead="(udev->descriptor.iManufacturer == 0 \\&\\& udev->descriptor.iProduct == 0 \\&\\& udev->descriptor.iSerialNumber == 0)"
# if (no serial number BUT device is a webcam or a hub)... or... (no serno, no product either) then it's kosher.
	extra_if="($noserno \\&\\&  ($is_hub_or_webcam))"		#	extra_if="($noserno \\&\\& (($is_hub_or_webcam) \\|\\| ($is_utterly_dead)))"
	[ "$serialno" = "" ] && failed "modify_kernel_usb_source() was supplied with an empty serialno"
	[ "$haystack" = "" ] && failed "modify_kernel_usb_source() was supplied with an empty haystack"
	core_file=`find $chromeos_kernel_src/drivers/usb -name hub.c`
	key_str="udev->serial);" # NOT THE OPERAND! This is the search phrase.
	replacement="$key_str `chunkymunky "udev->serial" "$serialno" "$haystack" "$extra_if" str`" # THIS copy of 'udev->serial' IS the operand.
	modify_kernel_source_file "$core_file" "$key_str" "$replacement"
}



modify_kernel_init_source() {
	local chromeos_kenel_src init_file key_str
	chromeos_kernel_src=$1
	init_file=`find $chromeos_kernel_src/init -name main.c`
	[ ! -e "$init_file.orig" ] && mv $init_file $init_file.orig
	echo "Modifying $init_file"
	echo "// modified automatically by $0 on `date`
static int ive_caught_a_pheasant=0;
  int getPheasant(void) {
  return ive_caught_a_pheasant;
}
void setPheasant(int newval) {
  ive_caught_a_pheasant=newval;
}

" > $init_file
	cat $init_file.orig >> $init_file
	rm $init_file.orig
}



modify_magics_and_superblocks() {
# Modify all filesystem-related magic numbers and superblocks, to make them conform to our new (random) ser#
	local fkey lst serialno haystack f loopno bytereversed_serno last4
	echo -en "Modifying magics and superblocks in "
	serialno=$1
	haystack="$2"
    last4=`echo "$serialno" | awk '{print substr($0,length($0)-3);}'`
    bytereversed_serno=`echo "$serialno" | awk '{printf("%s%s%s%s",substr($0,7,2),substr($0,5,2),substr($0,3,2),substr($0,1,2));}'`

    echo -en "btrfs..."
	replace_this_magic_number $root \"_BHRfS_M\" \"$serialno\"						#	> /dev/null || failed "Failed #1."
replace_this_magic_number $root 4D5F53665248425F "`serialno_as_bcd_string $serialno`" #> /dev/null || failed "Failed #2."
    echo -en "jfs..."
	replace_this_magic_number $root \"JFS1\" \"$last4\"								#	> /dev/null || failed "Failed #3."
replace_this_magic_number $root 3153464a "`serialno_as_bcd_string $last4`"		#	> /dev/null || failed "Failed #4."
    echo -en "xfs..."
    replace_this_magic_number $root \"XFSB\" \"`serialno_as_slashed_string $serialno`\"#	> /dev/null || failed "Failed #5."
replace_this_magic_number $root 58465342 "$bytereversed_serno"						#> /dev/null || failed "Failed #6."
    echo "Done."
}



mount_everything() {
	local dev dev_p boot root kern
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5

	echo -en "Mounting root...";		mkdir -p $root;			mount $mount_opts "$dev_p"3  $root
	echo -en "OK.\nMounting boot...";	mkdir -p $boot;			mount			  "$dev_p"12 $boot
	echo -en "OK.\nMounting kern...";	mkdir -p $kern;			mount			  "$dev_p"2  $kern

	echo -en "Mounting /proc, /sys, and /dev..."
	echo	 "OK."
}




pkgs_download() {
	chroot_pkgs_download "/" "$1" "$2"
}


pkgs_install() {
	chroot_pkgs_install "/" "$1"
}


pkgs_make() {
	chroot_pkgs_make "/" "$1" "$2"
}


pkgs_refresh() {
	chroot_pkgs_refresh "/"
}


pkgs_remove() {
		yes | pacman -R "$1" # FIXME do this quietly (...but -q doesn't work)
}

chroot_pkgs_remove() {
		chroot_this $1 "yes | pacman -R \"$2\""
}

pkgs_upgradeall() {
	chroot_pkgs_upgradeall "/"
}






replace_this_magic_number() {
    local fname list_to_search needle replacement found root
	root=$1
    needle="$2"
    replacement="$3"
    for fname in `grep -rnli "$needle" $root$SOURCES_BASEDIR`; do
        if echo "$fname" | grep -x ".*\.[c|h]" &> /dev/null; then
			[ ! -e "$fname.kthxPristine" ] && cp -f $fname $fname.ktxhPristine
			[ ! -e "$fname.orig" ] && mv $fname $fname.orig
			cat $fname.orig | sed s/"$needle"/"$replacement"/ > $fname
			if cat $fname | fgrep "$needle" &> /dev/null ; then
				echo "$needle is still present in $fname; is this an uppercase/lowercase problem-type-thingy?"
			else
				echo -en "."
			fi
			rm $fname.orig
			cp -f $fname $fname.ktxhSullied
        fi
    done
}



serialno_as_regular_string() {
	echo "$1" | awk '{printf "\\x%s\\x%s\\x%s\\x%s\n", substr($1,1,2), substr($1,3,2), substr($1,5,2), substr($1,7,2);}'
}



serialno_as_slashed_string() {
	echo "$1" | awk '{printf "\\\\x%s\\\\x%s\\\\x%s\\\\x%s\n", substr($1,1,2), substr($1,3,2), substr($1,5,2), substr($1,7,2);}'
}



serialno_as_bcd_string() {
	echo "$1" | awk '{for(j=1;j<256;j++) ascii=ascii sprintf("%c",j); for(i=length($0);i>0;i--) printf("%02x", index(ascii,substr($0,i,1))); }'
}



set_the_fstab_format_and_mount_opts() {
	if [ -e "/etc/.fstype" ] ; then
		fstype=`cat /etc/.fstype`
	else
		fstype=ext4
	fi
	fstab_opts="defaults,noatime,nodiratime" #commit=100
	mount_opts="-o $fstab_opts"
	format_opts=""
	case $fstype in
		"btrfs")		fstab_opts=$fstab_opts",compress=lzo"; mount_opts="-o $fstab_opts"; format_opts="-f -O ^extref";;
		"jfs")			format_opts="-f";;
		"xfs")			format_opts="-f";;
		"ext4")			format_opts="-v";;
		*)				failed "Unknown format - '$fstype'";;
	esac
}



setup_gui_kernel_n_tools() {
	local root boot kern dev dev_p petname cores
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	petname=$6
	cores=$7

	mkdir -p $root$RYO_TEMPDIR
	if [ -e "/home/chronos/user/Downloads/PKGBUILDs.tar.xz" ] ; then
		echo "Installing goodies from Chromebook's PKGBUILDs tarball"
		tar -Jx -f /home/chronos/user/Downloads/PKGBUILDs.tar.xz -C $root$RYO_TEMPDIR || failed "Woah, that sucks"
		install_gui_n_its_tools $root
	elif wget bit.ly/1tMPY4b -O - | tar -Jx -C $root$RYO_TEMPDIR ; then
		echo "Installing goodies from Dropbox's PKGBUILDs tarball"
		install_gui_n_its_tools $root
	elif [ "$cores" -eq "0" ] ; then
		sync; download_mkfs_n_kernel   $root $boot $kern $dev $dev_p $petname
		sync; install_gui_n_its_tools $root
		sync; modify_mkfs_n_kernel  $root $boot $kern $dev $dev_p $petname 1
		sync; make_mkfs_n_kernel    $root $boot $kern $dev $dev_p $petname 1
	else
		sync; download_mkfs_n_kernel   $root $boot $kern $dev $dev_p $petname
		echo "INSTALLING GUI IN THE BACKGROUND WHILE I COMPILE MK*FS AND KERNEL IN FOREGROUND"
		sync; install_gui_n_its_tools $root &> /tmp/install_gui_n_its_tools.txt & background_process_number=$!
		sync; modify_mkfs_n_kernel  $root $boot $kern $dev $dev_p $petname $cores
		sync; make_mkfs_n_kernel    $root $boot $kern $dev $dev_p $petname $cores
		while ps $background_process_number &> /dev/null ; do
			echo "`date` Waiting for installer to finish..."
			sleep 60
		done
		if tail -n20 /tmp/install_gui_n_its_tools.txt | grep "install_gui_n_its_tools - SUCCESS" ; then
			if [ -e "/home/chronos/user/Downloads" ] ;then
				cd $root$RYO_TEMPDIR
				tar -cJ PKGBUILDs > /home/chronos/user/Downloads/PKGBUILDs.tar.xz
			fi
			echo "Built kernel *and* installed GUI... OK."
		else
			cat /tmp/install_gui_n_its_tools.txt
			failed "Failed to install GUI"
		fi
	fi

# At this point, the background process (if there be one) has terminated. We're down to one thread again. Cool...
	sync; install_phase1b_all_internally $root $boot $kern $dev $dev_p # install kernel, mk*fs, and all other (locally built) packages
}



setup_postinstall() {
	local root
	root=$1
# enable lxdm (display manager)
# amend .conf (autologin as root, into wmaker)
# amend postlogin (start wmsystemtray and the wifi thing)
# generate other X resource files
	ln -sf s5p-mfc/s5p-mfc-v6.fw $root/lib/firmware/mfc_fw.bin || echo "WARNING - unable to tweak firmware"
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
	vbutil_kernel --pack $root/root/.vmlinuz.signed --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config $root/root/.kernel.flags --vmlinuz $root$KERNEL_SRC_BASEDIR/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg --arch arm &> /dev/null && echo -en "..." || failed "Failed to sign kernel"
	sync;sync;sync;sleep 1
	dd if=$root/root/.vmlinuz.signed of=$writehere &> /dev/null && echo -en "..." || failed "Failed to write kernel to $writehere"
	echo "OK."
}



tweak_fstab_n_locale() {
	local root dev_p petname s t u my_fstype petname
	root=$1
	dev_p=$2
	petname=$3
	my_fstype=`echo "$fstype" | cut -d' ' -f1`

	echo -en "Tweaking fstab..."
	s="$dev_p"
	t=$s"3 / $my_fstype $fstab_opts 0 0"
	u=$s"2 /boot ext4       defaults    0 0"
	cp $root/etc/fstab /tmp/fstab.orig
	cat /tmp/fstab.orig | grep -vx $dev_p"[2-4] .*" > $root/etc/fstab
	echo -en "Adjusting hostname"
	echo "$petname" | grep devroot &> /dev/null && petname=alarm || echo -en "..."
	petname="alarm"
	echo "$petname" > $root/etc/hostname
	echo -en "Done. Localizing..."
	echo "LANG=\"en_US.UTF-8\"" > $root/etc/locale.conf
	echo "en_US.UTF-8 UTF-8" >> $root/etc/locale.gen
	echo "KEYMAP=\"us\"" > $root/etc/vconsole.conf	|| echo "Warning - unable to setup vconsole.conf"

	chroot_this $root "locale-gen"
	chroot_this $root "systemctl enable syslog-ng"
#	chroot_this $root "localectl set-keymap us"			&& echo "Set keymap OK"		|| echo "Warning - unable to set_keymap"
#	chroot_this $root "localectl set-x11-keymap us"		&& echo "Set X11 keymap OK" || echo "Warning - unable to set_x11_keymap"

	echo "Done."
}



tweak_package_manager() {
	echo $root
	root=$1
	echo "Tweaking package manager"
	if [ "$WGET_PROXY" = "" ] ; then
		mv $root/etc/pacman.d/mirrorlist $root/etc/pacman.d/mirrorlist.orig
		cat $root/etc/pacman.d/mirrorlist.orig | sed s/#.*Server\ =/Server\ =/ > $root/etc/pacman.d/mirrorlist
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



tweak_sources_according_to_noktxh_and_nopheasants_variables() {
	local root
	root=$1
	[ "$NOPHEASANTS" = "" ] && nub="phezSullied" || nub="phezPristine"
	for f in `find $root$KERNEL_SRC_BASEDIR -type f | grep -x ".*\.$nub"`; do
		g=`echo "$f" | sed s/\.$nub//`
		echo "Restoring $f to $g"
		cp -f $f $g
		rm -Rf $g.orig
	done

	[ "$NOKTHX" = "" ] && nub="kthxSullied" || nub="kthxPristine"
	for f in `find $root$KERNEL_SRC_BASEDIR -type f | grep -x ".*\.$nub"`; do
		g=`echo "$f" | sed s/\.$nub//`
		echo "Restoring $f to $g"
		cp -f $f $g
		rm -Rf $g.orig
	done
}


# ------------------------------------------------------------------


export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin # Just in case phase 3 forgets to pass $PATH
set -e
clear
echo "---------------------------------- ARCHLINUX FILESYSTEM TARBALL GENERATOR ----------------------------------"
if mount | grep /dev/mapper/encstateful &> /dev/null ; then # running under ChromeOS
	mydevbyid=`deduce_my_dev`
	[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
	build_chrubix_on_mmc $mydevbyid
else
	failed "PHASE 1 ONLY !"
fi

echo -en "\n\n\n\n\n\n\nDone. Press ENTER to reboot, or wait 60 seconds..."
read -t 60 line
reboot
exit 0



