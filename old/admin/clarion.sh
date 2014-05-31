#!/bin/bash
#
# clarion.sh
# - customized to be more firendly to non-ArchLinux OSes
# - partition, format, and prep a thumb drive to run ArchLinux
# - if asked, roll a custom kernel
#
# wget bit.ly/1pCmy3H -O - | gunzip -dc > clarion.sh && sudo bash clarion.sh
#
# PHASE ONE		install OS+gui onto ext sd; build mk*fs and a custom kernel; reboot with/into them
# PHASE TWO		encrypt p2 as root; copy all files from p3 to p2; boot from p2
# PHASE THREE	encrypt&mount /home; fix sound; install boom safeguards, inc. pwr btn; activate GUI
#
####################################################################################################
#
# Stop DPMS< blanking< ACPI silliness< etc.
# http://crunchbang.org/forums/viewtopic.php?id=13990
# https://wiki.archlinux.org/index.php/acpid
# https://wiki.archlinux.org/index.php/Display_Power_Management_Signaling
# http://raspberrypi.stackexchange.com/questions/752/how-do-i-prevent-the-screen-from-going-blank
# https://www.notabilisfactum.com/blog/?page_id=7   <-- brightness up/down
#
# SAMSUNG CHROMEBOOK info
# https://wiki.debian.org/InstallingDebianOn/Samsung/ARMChromebook
# http://virtuallyhyper.com/2014/02/install-arch-linux-samsung-chromebook/
# http://www.galexander.org/chromebook/
# http://archlinuxarm.org/platforms/armv7/samsung/samsung-chromebook
# http://marcin.juszkiewicz.com.pl/2013/04/15/hardware-acceleration-on-chromebook/ <-- h/w GUI acceleration
# https://wiki.archlinux.org/index.php/Samsung_Chromebook_(ARM)
#
# CONFIGURE LXDM
# https://wiki.archlinux.org/index.php/LXDM#Globally



# FIXME set NOPHEASANTS to "" and EOD_PADDING to 0

NOPHEASANTS="NOPHEASANTS"		# if this is left blank, the new kernel will reject all USB/MMC until the one is found on which the OS resides
NOKTHX="NOKTHX"			# if this is left blank, the new kernel will use regular (not randomized) markers for filesystems
LOGLEVEL="2"		# .... or "6 debug verbose" .... or "2 debug verbose" or "2 quiet"
rootsizeMB=5000		# ____MB for root part'n
eodpaddingMB=0	# blank space (MB) at end of disk (for test purposes)
DISTRO=ArchLinux	# ArchLinux, Debian, ...?
BOOMFNAME=/etc/.boom
BOOT_PROMPT_STRING="boot: "
TEMPDIR=/tmp
SNOWBALL=nv_uboot-snow.kpart.bz2
DEBIAN_BRANCH=jessie # wheezy
DEBIAN_ARCHITECTURE=armhf
ARCHLINUX_ARCHITECTURE=armv7h
RYO_TEMPDIR=/root/.rmo
BOOM_PW_FILE=/etc/.sha512bm
KERNEL_CKSUM_FNAME=.k.bl.ck
SPLITPOINT=$(($rootsizeMB*2048))
EOD_PADDING=$(($eodpaddingMB*2048))
CRYPTOROOTDEV=/dev/mapper/cryptroot			# do not tamper with this, please
CRYPTOHOMEDEV=/dev/mapper/crypthome
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
KERNEL_SRC_BASEDIR=$SOURCES_BASEDIR/linux-chromebook
INITRAMFS_DIRECTORY=$RYO_TEMPDIR/initramfs_dir
INITRAMFS_CPIO=$RYO_TEMPDIR/uInit.cpio.gz
RANDOMIZED_SERIALNO_FILE=/etc/.randomized_serno
GUEST_HOMEDIR=/tmp/.guest
STOP_JFS_HANGUPS="echo 0 > /proc/sys/kernel/hung_task_timeout_secs"
if ping -W2 -c1 192.168.1.73 ; then
	WGET_PROXY="192.168.1.73:8080"
elif ping -W2 -c1 192.168.1.66 ; then
	WGET_PROXY="192.168.1.66:8080"
else
	WGET_PROXY=""
fi
[ "$WGET_PROXY" != "" ] && export http_proxy=$WGET_PROXY



activate_phase2_gui_and_wifi() {
	local my_dm res f

	echo -en "Enabling GUI..."
	which lxdm || failed "Where is lxdm? I need lxdm (the display manager). Please install it."
	if which kdm &> /dev/null ; then
		systemctl disable kdm || echo "Warning - unable to disable kdm"
		systemctl stop kdm || echo "Warning - unable to stop kdm"
	fi
	setup_phase2_display_manager        # Necessary, to make sure we log in as root (into GUI) at start of phase 3
	f=/etc/WindowMaker/WindowMaker
	if [ -e "$f" ] ; then
		mv $f $f.orig
		cat $f.orig | sed s/MouseLeftButton/flibbertygibbet/ | sed s/MouseRightButton/MouseLeftButton/ | sed s/flibbertygibbet/MouseRightButton/ > $f
	fi

# If the user is online, start the Display Manager. If not, start nmcli (which will let the user choose a wifi connection).
	generate_wifi_manual_script   > /usr/local/bin/wifi_manual.sh
	generate_wifi_auto_script     > /usr/local/bin/wifi_auto.sh
	chmod +x /etc/X11/xinit/xinitrc /usr/local/bin/*.sh

	cd /tmp
	echo -en "Disabling old netctl" # See https://wiki.archlinux.org/index.php/NetworkManager#nmcli_examples
	ifconfig down mlan0 &> /dev/null && echo -en "..." || echo -en ",,,"
	rm -f /etc/netctl/*Original*	 && echo -en "..." || echo -en ",,," # FIXME This shouldn't be necessary
	systemctl disable netctl.service && echo -en "..." || echo -en ",,,"
	systemctl disable netcfg.service && echo -en "..." || echo -en ",,,"
	systemctl disable netctl	     && echo -en "..." || echo -en ",,,"
	pkgs_remove "netctl"			 && echo -en "..." || echo -en ",,,"

	echo "...Done."
#	echo "Connecting via network-manager"
	rm -f /etc/NetworkManager/system-connections/*
#	systemctl start NetworkManager || failed "Unable to start NetworkManager" # for some reason, we go straight to GUI if I run this line. :-/
#	sleep 1
#	clear
	systemctl start NetworkManager || failed "Unable to start NetworkManager" # for some reason, we go straight to GUI if I run this line. :-/
	/usr/local/bin/wifi_manual.sh || failed "Failed to connect to Internet via networkmanager :-("
	echo "Enabling network manager and GUI"
	systemctl enable NetworkManager || failed "Unable to enable NetworkManager"
	systemctl enable lxdm || failed "Failed to activate lxdm display manager"
	echo "Done."
}



add_phase2_guest_browser_script() {
	echo "H4sIAF52SVMAA1WMvQrCMBzE9zzF2YYukkYfoBbBVQXnTKZ/TaBJpEmhQx/eUNTidMd9/MqNvFsvo2EsudfD9tTIbGQXhKOa346X0/X8L3UekzYBgjyK8gtQnu+Vp8kmKN4qX+AA/mEybVzosJ3WJI4QPZ4jxQShfzmqCgPFZod5Xgxv2eDW28LnuWBvkUV8bboAAAA=" | base64 -d | gunzip > /usr/local/bin/run_as_guest.sh
	chmod +x /usr/local/bin/run_as_guest.sh

	echo "#!/bin/sh
sudo /usr/local/bin/run_as_guest.sh \"export DISPLAY=:0.0; chromium --user-data-dir=/tmp/.guest \$1\"
exit \$?
" > /usr/local/bin/run_browser_as_guest.sh
	chmod +x /usr/local/bin/run_browser_as_guest.sh
}



add_phase2_guest_user() {
	local tmpfile
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	echo -en "Adding guest user..."
	mkdir -p $GUEST_HOMEDIR
	useradd guest -d $GUEST_HOMEDIR
	chmod 700 $GUEST_HOMEDIR
	chown -R guest.guest $GUEST_HOMEDIR
	mv /etc/shadow $tmpfile
	cat $tmpfile | sed s/'guest:!:'/'guest::'/ > /etc/shadow
	echo "Done."
	usermod -a -G tor guest
	rm -f $tmpfile
}



add_phase2_reboot_user() {
	add_phase2_zz_user_SUB reboot
	return $?
}



add_phase2_shutdown_user() {
	add_phase2_zz_user_SUB shutdown
	return $?
}



add_phase2_zz_user_SUB() {
	local username tmpfile userhome cmd f
	username=$1
	cmd=$username
	[ "$username" = "shutdown" ] && cmd=poweroff
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	userhome=/etc/.$username
	echo -en "Adding $username user..."
	mkdir -p $userhome
	useradd $username -d $userhome
	chmod 700 $userhome
	chown -R $username $userhome
	mv /etc/shadow $tmpfile
	cat $tmpfile | sed s/$username':!:'/$username'::'/ > /etc/shadow
	rm -f $tmpfile
	echo "#!/bin/sh

sudo tweak_lxdm_and_$username
" > $userhome/.profile
	chmod +x $userhome/.profile
	chown $username.$username $userhome/.profile

#	echo "cmd=$cmd"
	echo "#!/bin/sh
sync;sync;sync
systemctl $cmd
exit 0
" > /usr/local/bin/tweak_lxdm_and_$username
	chmod +x /usr/local/bin/tweak_lxdm_and_$username

	echo "Done."
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



download_phase1_mkfs_n_kernel() {
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
	if [ "$DISTRO" = "ArchLinux" ] ; then
		chroot_this $root "cd $RYO_TEMPDIR; git clone git://github.com/archlinuxarm/PKGBUILDs.git" && echo -en "..." || failed "Failed to git clone kernel source"
	elif [ "$DISTRO" = "Debian" ] ; then
		failed "How should I dl kernel for Debian?"
	else
		failed "How should I dl kernel for '$DISTRO'?"
	fi

	chroot_pkgs_download $root $KERNEL_SRC_BASEDIR
	chroot_pkgs_download $root $SOURCES_BASEDIR/btrfs-progs	"PKGBUILD btrfs-progs.install initcpio-hook-btrfs initcpio-install-btrfs"
	chroot_pkgs_download $root $SOURCES_BASEDIR/jfsutils		"PKGBUILD inttypes.patch"
	chroot_pkgs_download $root $SOURCES_BASEDIR/xfsprogs		"PKGBUILD"
}



modify_phase1_mkfs_n_kernel() {
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

	echo "Rolling my own mk*fs and kernel for $dev; nophez=$NOPHEASANTS; serialno=$serialno"
	[ "$NOKTHX" != "" ] && echo -en "; nokthx=$NOKTHX"
	echo ""
	if [ "$DISTRO" = "ArchLinux" ]; then
		if [ -e "$RYO_TEMPDIR/PKGBUILDs" ] ; then
			for f in `find $SOURCES_BASEDIR -type f 2> /dev/null | fgrep "pkg.tar.xz"` ; do
				rm $f
			done
		fi
		# enable SMP compiling
		mv $root/etc/makepkg.conf $root/etc/makepkg.conf.orig
		cat $root/etc/makepkg.conf.orig | sed s/#MAKEFLAGS.*/MAKEFLAGS=\"-j$cores\"/ | sed s/\!ccache/ccache/ > $root/etc/makepkg.conf
#		btrfsprogs=btrfs-progs
	else
#		btrfsprogs=btrfs-tools
		failed "download_phase1_mkfs_and_kernel() --- what should '$DISTRO' do?"
	fi
}




make_phase1_mkfs_n_kernel() {
	local root boot kern dev dev_p fstype petname serialno haystack tmpfile cores linepos relfname fname
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	petname=$6
	cores=$7
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM

	chroot_pkgs_make $root $KERNEL_SRC_BASEDIR		   301800 || failed "Failed to make kernel"
	chroot_pkgs_make $root $SOURCES_BASEDIR/btrfs-progs  4900 || failed "Failed to make $btrfsprogs"
	chroot_pkgs_make $root $SOURCES_BASEDIR/jfsutils    56000 || failed "Failed to make jfsutils"
	chroot_pkgs_make $root $SOURCES_BASEDIR/xfsprogs    24600 || failed "Failed to make xfsprogs"
	echo -en "Building a temporary prefab initramfs for a second time..."
	make_initramfs_saralee $root "" &> $tmpfile && echo "Done." || failed "Failed to make prefab initramfs -- `cat $tmpfile`"
}



chroot_pkgs_download() {
	local fdir res file_to_download f stuff_from_website root tmpfile loops
	root=$1
	fdir=`dirname $2`
	f=`basename $2`
	stuff_from_website="$3"
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	res=0
	mkdir -p $root/$fdir/$f
	cd $root/$fdir/$f
	echo -en "Downloading $f..."
	if [ "$DISTRO" = "ArchLinux" ] ; then
		if [ -f "$root/$fdir/$f/PKGBUILD" ] ; then
			echo -en "Still working..." # echo "No need to download anything. We have PKGBUILD already."
		elif [ "$stuff_from_website" = "" ] ; then
			file_to_download=aur.archlinux.org/packages/${f:0:2}/$f/$f.tar.gz
#			echo "Downloading $file_to_download to `pwd`/.."
			wget --quiet -O - $file_to_download | tar -zx -C .. && echo -en "..." || failed "Failed to download $file_to_download"
		else
			for fname in $stuff_from_website ; do
				file_to_download=$root/$fdir/$f/$fname
				echo -en "$fname"...
				rm -Rf $file_to_download
				res=999
				loops=0
				while [ "$res" -ne "0" ] && [ "$loops" -le "20" ]; do
					wget --quiet https://projects.archlinux.org/svntogit/packages.git/plain/trunk/$fname?h=packages/$f -O - > $file_to_download && res=0 || res=1
					loops=$(($loops+1))
				done
				[ "$res" -ne "0 " ] && failed "Failed to download $fname for $f"
			done
		fi
		echo -en "Calling make"
#		if ! echo "$f" | grep java-service-wrapper &> /dev/null ; then
			mv PKGBUILD PKGBUILD.ori || failed "pkgs_download() --- unable to find PKGBUILD"
			cat PKGBUILD.ori | sed s/march/phr34k/ | sed s/\'libutil-linux\'// | sed s/\'java-service-wrapper\'// | sed s/arch=\(.*/arch=\(\'$ARCHLINUX_ARCHITECTURE\'\)/ | sed s/phr34k/march/ > PKGBUILD
#		fi
		echo -en "pkg..."
		if [ "$f" = "linux-chromebook" ] ; then
			mv PKGBUILD PKGBUILD.wtfgoogle
			cat PKGBUILD.wtfgoogle | sed s/chromium\.googlesource.*kernel.*gz/dl.dropboxusercontent.com\\\/u\\\/59916027\\\/klaxon\\\/135148b515275c24d691f10ba74c0c5b8d56af63.tar.gz/ > PKGBUILD
		fi
		chroot_this $root "cd $2; makepkg --skipchecksums --asroot --nobuild -f" &> $tmpfile || failed "`cat $tmpfile` --- chroot_pkgs_download() -- failed to download $2"
	elif [ "$DISTRO" = "Debian" ] ; then
		failed "pkgs_download() - what would Debian do?"
	else
		failed "pkgs_download() - what would '$DISTRO' do?"
	fi
	[ "$res" -eq "0" ] && echo "OK." || echo "Failed."
	return $res
}



chroot_pkgs_install() {
	local mycall pkgs res f
	res=0
	if [ "$1" = "/" ] && [ -d "$2" ]; then	# $2 is a directory? OK. Install all (recursively) found (living in supplied folder) local packages, locally.
		if [ "$DISTRO" = "ArchLinux" ] ; then
			echo "Searching $2 for packages"
			yes "" | pacman -U `find $2 -type f | grep -x ".*\.pkg\.tar\.xz"`	|| res=1
		elif [ "$DISTRO" = "Debian" ] ; then
			dpkg -i `find $2 -type f | grep -x ".*\.deb"`						|| res=2
		else
			failed "chroot_pkgs_install() - what would '$DISTRO' do?"
		fi
	elif [ -d "$1$2" ] ; then				# $1$2 is a directory? OK. Install in chroot all (recur'y) found (in folder) chroot packages, chroot-ily.
		if [ "$DISTRO" = "ArchLinux" ] ; then
			mycall="pacman -U \`find $2 -type f | grep -x \".*\\.pkg\\.tar\\.xz\"\`"
			chroot_this $1 "yes \"\" | $mycall"									|| res=3
		elif [ "$DISTRO" = "Debian" ] ; then
			mycall="dpkg -i \`find $2 -type f | grep -x \".*\\.deb\"\`"
			chroot_this $1 "$mycall"											|| res=4
		else
			failed "chroot_pkgs_install() - what would '$DISTRO' do?"
		fi
	elif [ "$1" = "/" ] ; then				# Install specific (Internet-based) packages locally
		if [ "$DISTRO" = "ArchLinux" ] ; then
			yes "" | pacman -S --needed $2										|| res=5
		elif [ "$DISTRO" = "Debian" ] ; then
			apt-get install $2													|| res=6
		else
			failed "chroot_pkgs_install() - what shoud '$DISTRO' do?"
		fi
	else									# Install specific (Internet-based) packages in a chroot
		if [ "$DISTRO" = "ArchLinux" ] ; then
			chroot_this $1 "yes \"\" | pacman -S --needed $2"					|| res=7
		elif [ "$DISTRO" = "Debian" ] ; then
			chroot_this $1 "yes \"\" | apt-get install $2"						|| res=8
		else
			failed "chroot_pkgs_install() - what shoud '$DISTRO' do?"
		fi
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
	if [ "$DISTRO" = "ArchLinux" ] ; then
		chroot_this $1 "cd $2; makepkg --skipchecksums --asroot --noextract -f" 2>&1 | pv $pvparam > $tmpfile|| failed "`cat $tmpfile` --- failed to chroot make $2 within $1"
	elif [ "$DISTRO" = "Debian" ] ; then
		failed "How does pkgs_make() handle Debian?"
	else
		failed "pkgs_make() doesn't know what distro '$DISTRO' is."
	fi
#	cat $tmpfile | grep ERROR &> /tmp/null || echo "`cat $tmpfile` --- Errors occurred during chroot_pkgs_make($2)"
	rm -f $tmpfile
}



chroot_pkgs_refresh() {
	local mycall
	if [ "$DISTRO" = "ArchLinux" ] ; then
		mycall="pacman -Sy"
	elif [ "$DISTRO" = "Debian" ] ; then
		mycall="apt-get update"
	else
		failed "chroot_pkgs_refresh() - what shoud '$DISTRO' do?"
	fi
	chroot_this $1 "yes \"\" | $mycall" || echo "chroot_pkgs_refresh() -- WARNING --- '$mycall' (chrooted) returned an error"
}





chroot_pkgs_upgradeall() {
	local mycall
	if [ "$DISTRO" = "ArchLinux" ] ; then
		mycall="pacman -Syu"
	elif [ "$DISTRO" = "Debian" ] ; then
		mycall="apt-get update; apt-get upgrade"
	else
		failed "chroot_pkgs_upgradeall() - what shoud '$DISTRO' do?"
	fi
	chroot_this $1 "yes \"\" | $mycall" || echo "chroot_pkgs_upgradeall() -- WARNING --- '$mycall' (chrooted) returned an error"
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



does_custom_kernel_cut_the_mustard() {
	local bootdev dev dev_p petname randomized_serno last4 goodA goodB
	dev=$1
	dev_p=$2
	petname=$3
	serno_in_use=""
	set_the_fstab_format_and_mount_opts # shouldn't be necessary - QQQ FIXME
	[ -e "$RANDOMIZED_SERIALNO_FILE" ] && randomized_serno=`cat $RANDOMIZED_SERIALNO_FILE` || randomized_serno="(not found)"
	echo -en "Testing kernel and mkfs..."
	set +e
	for loop in 1 2 3 4 5 ; do
		test_kernel_and_mkfs $petname $dev # &> /dev/null
		res=$?
		if [ "$res" -eq "0" ] ; then
			cp /tmp/firstblock.btrfs.dat /tmp/fbbd
			serno_in_use="`strings /tmp/fbbd | head -n1`"
			echo "btrfs is using $serno_in_use ... We want it to use $randomized_serno ..."
			if [ "$serno_in_use" = "$randomized_serno" ]; then
				goodA=good
				cp /tmp/firstblock.jfs.dat /tmp/fbjd
				serno_in_use="`strings /tmp/fbjd | head -n1`"
				last4=`echo "$randomized_serno" | awk '{print substr($0,length($0)-3);}'`
				echo "jfs is using $serno_in_use ... We want it to use $last4 ..."
				if [ "$serno_in_use" = "$last4" ]; then
					goodB=good
					break
				fi
			fi
		fi
		echo -en "."
	done
	set -e
#	echo "my serialno = $petname; serno in use = $serno_in_use; randomized serno=$randomized_serno"
	if [ "$goodA" = "good" ] && [ "$goodB" = "good" ]; then
		echo "Mkfs and kernel use the same serno: the randomized one. Therefore, there's no need to recompile/rebuild anything."
	elif [ "$NOKTHX" != "" ] ; then
		echo "You specified NOKTHX; so, we didn't bother tweaking the serial numbers. Fair enough..."
	else
		failed "No. The kernel and its mk*fs counterparts do not cut the mustard."
	fi
	return $res
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



encrypt_home_phase3_at_last() {
	local rootdev dev dev_p partno res orig_home_params homepartition temptxt keyfileA partial combined_keyfile svcfile loops bname mydevbyid

	dev=$1
	dev_p=$2
	partno=3

	[ "$dev" = "" ] && failed "encrypt_home_phase3_at_last() -- dev not specified"
	[ "$dev_p" = "" ] && failed "encrypt_home_phase3_at_last() -- dev_p not specified"

	clear
	echo -en "Encrypting /home"
	umount /home &> /dev/null && echo -en "..." || echo -en ",,,"
	sync;sync;sync

	homepartition="$dev_p"3
	temptxt=/tmp/$RANDOM$RANDOM$RANDOM
	keyfileA=/tmp/"$RANDOM$RANDOM$RANDOM"1
	keyfileB=/tmp/"$RANDOM$RANDOM$RANDOM"2
	combined_keyfile=/tmp/"$RANDOM$RANDOM$RANDOM"3
	if mount | grep "mapper" | grep " / " | grep `basename $CRYPTOROOTDEV` &> /dev/null ; then
		echo -en "..."
	else
		failed "Sorry. / is not encrypted. Therefore, I can't/shan't encrypt /home."
	fi
	head -c 256 /dev/random > $keyfileA
	head -c 256 /dev/random > $keyfileB

	get_dev_serialno $dev			> $combined_keyfile
	cat $keyfileA					>>$combined_keyfile
	get_internal_serial_number		>>$combined_keyfile
	cat $keyfileB					>>$combined_keyfile

	hexdump $combined_keyfile > /root/keyfile.txt.original

# Encrypt /home partition.
	mount | grep " /home " &> /dev/null && umount /home || echo -en "..." # I am assuming the /home lives at $homepartition
	umount "$dev_p"3 &> /dev/null && echo -en "..." || echo -en ",,,"
	echo -en "\nAnswer the first question with YES. Then,\nat each prompt for a password, press Enter.\n(Don't specify a password, please.)\n"

	res=999
	while [ "$res" -ne "0" ]; do
		cryptsetup	-v luksFormat $homepartition -c aes-xts-plain -y -s 512 -c aes -s 256 -h sha256
		cryptsetup luksAddKey $homepartition $combined_keyfile
		cryptsetup luksOpen $homepartition `basename $CRYPTOHOMEDEV` --key-file $combined_keyfile && res=0 || res=1
	done
	echo -en "Done. Formatting..."
	set_the_fstab_format_and_mount_opts # shouldn't be necessary - QQQ
	yes | mkfs.$fstype $format_opts $CRYPTOHOMEDEV &> $temptxt || failed "`cat $temptxt` - Failed to format `basename $CRYPTOHOMEDEV`"
	rm $temptxt
	sync;sync;sync;sleep 1;sync;sync;sync;sleep 1
	cryptsetup luksClose `basename $CRYPTOHOMEDEV`
# Setup keys. Upload half the key to Dropbox folder.
	echo -en "Modifying fstab..."
	orig_home_params=`cat /etc/fstab | grep " /home " | cut -d' ' -f3-9`
	mv /etc/fstab /etc/fstab.orig
	cat /etc/fstab.orig | grep -v " /home " | grep -v " /boot " | grep -v " / " > /etc/fstab
	res=999
	loops=0
	while [ "$res" -ne "0" ] ; do
		/usr/local/bin/dropbox_uploader.sh upload $keyfileB `basename $keyfileB` && res=0 || res=$?
		[ "$res" -ne "0" ] && echo "Retrying..."
		loops=$(($loops+1))
		[ "$loops" -gt "20" ] && failed "We failed $loops times. We tried to work with Dropbox, but we failed, precious."
	done
	cp -f $keyfileA /etc/.clarion.k.1
	write_mounthome_script > /usr/local/bin/mount_home
	chmod +x /usr/local/bin/mount_home
	write_mounthome_service> /usr/lib/systemd/system/sysinit.target.wants/mount_home.service
	res=999
	while [ "$res" -ne "0" ] ; do
		echo -en "\nChoose a one-word name for the default user: "
		read userid
		useradd $userid || continue
		mkdir -p /home/$userid
		chown $userid.$userid /home/$userid
		chmod 700 /home/$userid
		passwd $userid || continue
		res=0
		usermod -a -G tor $userid
	done

	echo -en "Mounting /home"
	cryptsetup luksOpen $homepartition `basename $CRYPTOHOMEDEV` --key-file $combined_keyfile
	mount $mount_opts $CRYPTOHOMEDEV /home
	mkdir -p /home/$userid
	chown -R $userid.$userid /home/$userid
	chmod 700 /home/$userid

	echo "The world is built on kindness." > /home/secret.txt
	shred $combined_keyfile
	shred $keyfileA
	shred $keyfileB

	mpg123 /etc/.happy.mp3 &> /dev/null &
	logger "QQQ success w/ encrypting /home - yay"
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



format_phase1_partitions() {
	local dev dev_p temptxt
	dev=$1
	dev_p=$2
	temptxt=/tmp/$RANDOM$RANDOM$RANDOM
	echo -en "Formatting partitions..."
	echo -en "..."
	mkfs.ext2 "$dev_p"2 &> $temptxt || failed "Failed to format p2 - `cat $temptxt`"
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
    echo \"\n\nAvailable networks: \$all\" | wrap -w 100
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



insert_phase1_latest_kernel() {
	local fname tmpfile root src b res loops
	root=$1
	src=$2
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	echo "Locating latest kernel"
	wget www.kernel.org --quiet -O - > $tmpfile || failed "Failed to download kernel.org webpage"
	linepos=`grep -n "Latest Stable Kernel" $tmpfile | cut -d':' -f1`
	relfname=`cat $tmpfile | head -n$(($linepos+10)) | tr '"' '\n' | fgrep tar.xz | head -n1`
	fname=https://www.kernel.org/pub/linux/kernel/v3.x/`basename $relfname`
	echo "Downloading the latest kernel `basename $relfname`"
	rm $tmpfile
	res=999
	loops=0
	while [ "$res" -ne "0" ] && [ "$loops" -le "20" ] ; do
		wget $fname -O - | tar -Jx -C $root/$src/src/ && res=0 || res=1
		loops=$(($loops+1))
	done
	[ "$res" -eq "0" ] || failed "Failed to download vanilla kernel $fname"
	echo "Adjusting the build directories accordingly"
	cd $root/$src/src/				|| failed "Failed to cd to $root/KERNEL_SRC_BASEDIR/src/"
	mv chromeos-3.4 chromeos-3.4.real				|| failed "Failed to chromeos-3.4 chromeos-3.4.real"
	b=`basename $relfname | sed s/.tar.xz//`
	ln -sf chromeos-3.4 `basename $relfname`		|| failed "Failed to ln -sf chromeos-3.4 `basename $relfname`"
	cp chromeos-3.4.real/.config $b/.config||failed "Failed to cp chromeos-3.4.real/.config `basename $relfname`/.config"
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




install_phase1_acpi_and_powerboom() {
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
	chroot_this $root "systemctl start acpid" || echo "WARNING - unable to start acpid"
}




install_phase1_kernel() {
	local root boot kern dev dev_p specialbootblock fstype kernel_twelve_dev kernel_version_str recently_compiled_kernel signed_kernel tmpfile
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	cd /
	echo "Installing kernel"
	if [ "$DISTRO" = "ArchLinux" ] ; then
		mkdir -p $boot/u-boot
		cp $root/boot/boot.scr.uimg $boot/u-boot
#cp $root/boot/{b,v}* $kern --- necessary?
		touch $root/boot/.mojo-jojo-was-here
		specialbootblock=nv_uboot-snow.kpart.bz2
		wget --quiet -O - http://commondatastorage.googleapis.com/chromeos-localmirror/distfiles/$specialbootblock > $TEMPDIR/$specialbootblock
		cat $TEMPDIR/$specialbootblock | bunzip2 > "$dev_p"1
#		if [ "$WGET_PROXY" = "" ] ; then
			mv $root/etc/pacman.d/mirrorlist $root/etc/pacman.d/mirrorlist.orig
			cat $root/etc/pacman.d/mirrorlist.orig | sed s/#.*Server\ =/Server\ =/ > $root/etc/pacman.d/mirrorlist
#		fi
		chroot_pkgs_refresh $root
		chroot_pkgs_install $root "linux-chromebook linux-headers-chromebook" &> $tmpfile || failed "`cat $tmpfile`" # necessary (dunno why)
	elif [ "$DISTRO" = "Debian" ] ; then
		rm -f $root/vm* # Is this necessary?
		wget bit.ly/1gB0Hth -q -O - | tar -zx -C $root		# install vanilla kernel (Cuckoo!)
		recently_compiled_kernel=$root/vmlinuz
		signed_kernel=$root/vmlinuz.signed
		ln -sf /proc/mounts $root/etc/mtab
		echo "console=tty1 printk.time=1 nosplash rootwait root="$dev_p"3 rw rootfstype=ext4 lsm.module_locking=0" > $root/kernel.flags
		echo "Signing the kernel"
		vbutil_kernel --pack $root/vmlinuz.signed --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config $root/kernel.flags --vmlinuz $root/boot/vmlinuz --arch arm
		dd if=$root/vmlinuz.signed of="$dev_p"1 bs=4M
	else
		failed "install_phase1_kernel() - what should '$DISTRO' do?"
	fi
}



install_phase1_gui_n_its_tools() {
	local res r pkgs do_it_again first_these root fstype loops then_these
	root=$1
	fs=ext4 # During phase 1, everyhting is ext4. That way, when we've tweaked the kernel and rebooted, we can still read the fs. ;)
# FIXME Do we want xf86-video-fbdev, or do we want xf86-video-armsoc? Do we need xf86-input-mouse and/or xf86-input-keyboard?
	if [ "$DISTRO" = "ArchLinux" ] ; then
		then_these="xorg-server xorg-xinit xorg-server-utils xorg-xmessage mesa xf86-video-fbdev xf86-video-armsoc xf86-input-synaptics mousepad icedtea-web-java7 rng-tools ttf-dejavu ntfs-3g gptfdisk xlockmore python bluez-libs alsa-plugins acpi sdl libcanberra libcanberra-gstreamer libcanberra-pulse pkg-config mplayer"
	elif [ "$DISTRO" = "Debian" ] ; then
		then_these=" xorg mousepad rng-tools ttf-dejavu mplayer2 default-jre python bluez-utils alsa-oss oss-compat gnu-standards wireless-tools  wpasupplicant firmware-libertas vboot-utils vboot-kernel-utils u-boot-tools"
	else
		failed "install_phase1_gui_n_its_tools() --- what should I do with '$DISTRO'?"
	fi
first_these="libnotify network-manager-applet wmii jwm dillo mpg123 talkfilters ffmpeg chromium  xterm rxvt rxvt-unicode exo acpid bluez pulseaudio alsa-utils pm-utils notification-daemon syslog-ng nano cgpt parted bison flex expect autogen wmctrl expect java-runtime libxmu libxfixes libxpm pkg-config tor vidalia privoxy apache-ant junit xscreensaver"
# We must have either urxvt or rxvt-unicode (they're the same thing, really)
	pkgs="$first_these $then_these `cat $root/.clarion_gui_pkgs.txt`" # distro-specific, non-specific, GUI-specific
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
	wget --quiet -O - bit.ly/1iH8lCr > x_alarm_chrubuntu.zip  # Original came from http://craigerrington.com/blog/installing-arch-linux-with-xfce-on-the-samsung-arm-chromebook/ ---- thanks, Craig
	chroot_this $root "cd /etc/X11/xorg.conf.d/; unzip x_alarm_chrubuntu.zip" || failed "Failed to install Chromebook-friendly X11 config files"
	rm x_alarm_chrubuntu.zip # FIXME Use wget | tar -zx -C $root   :)
	f=10-keyboard.conf # Turn GB keyboard layout into US keyboard layout (config files were b0rked"
	mv $f $f.orig
	cat $f.orig | sed s/gb/us/ > $f
	mkdir -p $root/etc/tmpfiles.d
	echo "f /sys/devices/s3c2440-i2c.1/i2c-1/1-0067/power/wakeup - - - - disabled" >> $root/etc/tmpfiles.d/touchpad.conf
	chroot_pkgs_install $root festival-us
	echo "
(Parameter.set 'Audio_Method 'Audio_Command)
(Parameter.set 'Audio_Command \"aplay -q -c 1 -t raw -f s16 -r \$SR \$FILE\")
" >> $root/usr/share/festival/festival.scm

	download_build_n_install_packages	 $root "trousers opencryptoki tpm-tools freenet wmsystemtray" # i2p (one day)

	echo "install_phase1_gui_n_its_tools - SUCCESS"
}



install_phase1_imptt_pkgs() {
	local root boot kern res loops
	root=$1
	boot=$2
	kern=$3
	res=999
	loops=0

	loops=0
	while [ ! -e "$root/usr/local/bin/dropbox_uploader.sh" ] ; do
		chroot_this $root "wget https://raw.github.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh -O - > /usr/local/bin/dropbox_uploader.sh" || echo "WARNING - unable to download dropbox uploader. Retrying..."
		loops=$(($loops+1))
		[ "$loops" -ge "5" ] && failed "Failed to download dropbox uploader."
	done
	chmod +x $root/usr/local/bin/dropbox_uploader.sh
	chroot_pkgs_upgradeall $root
	[ "$DISTRO" = "ArchLinux" ] && chroot_pkgs_install $root "mkinitcpio"
	chroot_this $root "which mkinitcpio &> /dev/null" || failed "Please tell me how to install mkinitcpio on $DISTRO distro"

# NB: We do not install jfsutils, xfsprogs, or btrfs-[progs|tools]. We build them from source; then we install our custom packages.
	while [ "$res" -ne "0" ] ; do
		chroot_pkgs_install $root "busybox curl systemd make gcc ccache patch git wget lzop pv ed sudo bzr xz automake autoconf bc cpio unzip libtool  dtc xmlto docbook-xsl uboot-mkimage git wget cryptsetup dosfstools" && res=0 || res=1
		loops=$(($loops+1))
		[ "$loops" -gt "20" ] && failed "We failed $loops times. We tried to install the Phase One imptt pkgs, but we failed, precious."
	done

	mkdir -p $root/usr/local/bin/
	wget --quiet -O - bit.ly/1pCmy3H 2> /dev/null | gunzip -dc > $root/usr/local/bin/clarion.sh && chmod +x $root/usr/local/bin/clarion.sh || failed "Failed to download and install a copy of myself"
	wget --quiet -O - bit.ly/1mj99jZ | tar -zx -C $root || echo "WARNING --- unable to install vbutil.tgz (vbutil_kernel etc.)"
	wget --quiet -O - bit.ly/1lTgpQn | gunzip -dc > $root/etc/.happy.mp3 || echo "WARNING -- unable to install happy sound"
	wget --quiet -O - bit.ly/1gGttUd | gunzip -dc > $root/etc/.sad.mp3	 || echo "WARNING -- unable to install sad sound"
	wget --quiet -O - bit.ly/1hQLk1g | gunzip -dc > $root/etc/.tro.mp3   || echo "WARNING -- unable to install tro sound"
	wget --quiet -O - bit.ly/Qi271C  | gunzip -dc > $root/etc/.error1.mp3|| echo "WARNING -- unable to install error1 sound"
	wget --quiet -O - bit.ly/1l9QoQI | gunzip -dc > $root/etc/.error2.mp3|| echo "WARNING -- unable to install error2 sound"
	wget --quiet -O - bit.ly/1jOASG9 | gunzip -dc > $root/etc/.online.mp3|| echo "WARNING -- unable to install online sound"
	wget --quiet -O - bit.ly/1neuRG4 | gunzip -dc > $root/etc/.welcome.mp3||echo "WARNING -- unable to install welcome sound"
	wget --quiet -O - bit.ly/1hQZKhY | gunzip -dc > $root/etc/.wrongCB.mp3||echo "WARNING -- unable to install wrongCB sound"
	wget --quiet -O - bit.ly/1j9leBO | gunzip -dc > $root/etc/.wrongSD.mp3||echo "WARNING -- unable to install wrongSD sound"
}



install_phase1_OS() {
	local root boot kern dev dev_p
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5

	[ -e "$root$RANDOMIZED_SERIALNO_FILE" ] && failed "Why are you re-rolling a custom kernel when I've already built a custom one?"
	randomized_serno=`generate_random_serial_number`

	echo "Downloading and installing OS. This will take several minutes."
	if [ "$DISTRO" = "ArchLinux" ] ; then
		wget -O - bit.ly/QztPaD | tar -zx -C $root || failed "Failed to dl/untar AL tarball"
		wget --quiet -O - http://commondatastorage.googleapis.com/chromeos-localmirror/distfiles/$SNOWBALL > $TEMPDIR/$SNOWBALL || failed "Failed to download snowball"
	elif [ "$DISTRO" = "Debian" ] ; then
		pivot_phase1_debian_bootstrap_via_archlinux $root $boot $kern $dev $dev_p
	else
		failed "download_distro_goodies() - how should we handle '$DISTRO'?"
	fi
	mv $root/etc/resolv.conf $root/etc/resolv.conf.pristine || failed "Failed to save original resolv.conf"
	cp /etc/resolv.conf $root/etc/						    || failed "Failed to copy the ChromeOS resolv.conf into chroot"

	cp /tmp/.clarion_gui_pkgs.txt $root/
	cp /tmp/.mydistrochoice $root/etc/
	cp /tmp/.myguichoice $root/etc/
	cp /tmp/.clarion_gui_name.txt $root/etc/
	echo "$randomized_serno" > $root$RANDOMIZED_SERIALNO_FILE
	return 0
}



install_phase2_timezone() {
	local r res root
	root=$1
	r="blah"
	while ! ls $root/usr/share/zoneinfo/posix/Etc/$r &> /dev/null ; do
		echo -en "Please specify timezone (GMT-[1-13], GMT+[1-12], or GMT0): "
		read r
	done
	ln -sf /usr/share/zoneinfo/posix/Etc/$r $root/etc/localtime
}



install_phase3_boom_code() { # FYI, the 'power button' script is part of the ACPI mod
	local dev dev_p
	dev=$1
	dev_p=$2
	[ "$keyfileB" != "" ] || failed "Please run encrypt_home_phase3_at_last() before you run install_phase3_boom_code(). Thanks."
	echo "#!/bin/sh

set +e
logger \"QQQ BOOM --> \`cat $BOOMFNAME\`\"
mpg123 /etc/.tro.mp3 &> /dev/null &
# DISABLED... FOR NOW.
/usr/local/bin/dropbox_uploader.sh delete `basename $keyfileB` & # Yes, we want the backquotes WITHOUT backslashes. Trust me on this.
shred /etc/.clarion.k.1
umount /home &> /dev/null
crypsetup close `basename $CRYPTOHOMEDEV` &> /dev/null
echo $dev_p"3 /home ext4 defaults 0 0" >> /etc/fstab
mkfs.ext4 -f "$dev_p"3 &> /dev/null || yes TROLOLOLOLOLOLOL | dd bs=1k of="$dev_p"3 2> /dev/null
systemctl disable mount_home
rm -f /usr/local/bin/mount_home /usr/local/bin/dropbox_uploader.sh /usr/local/bin/power_button_pushed.sh /etc/systemd/system/sysinit.target.wants/mount_home.service /root/.postinstall.sh /root/.profile /etc/lxdm/P*Log*
dd if=/dev/urandom of=/.zeroes bs=1024k 2> /dev/null
rm /.zeroes
(sleep 1; rm -f /usr/local/bin/boom.sh) &
" > /usr/local/bin/boom.sh
	chmod +x /usr/local/bin/boom.sh
}



# FIXME FIXME FIXME this doesn't work if root isn't / !!! You need to add '$root/' in front of nearly all the '$' paths
make_initramfs_homemade() {
	local f myhooks rootdev login_shell_code booming smileyface
	root=$1
	[ "$root" = "/" ] || failed "make_initramfs_homemade() shouldn't be called unless root=/; root was specified as $root; that's bad"
	rootdev=$2
	thumbsup="H4sIAEN+NFMAA5VUWxLEIAj79xRMhvtx/78VAcVWtm1mZ6uUhFeVqIJ0cILuW+XKBY6M2t1Jy5P7H3N/qo5QX8l69wLh3TXGrwuJyjCBrzLml7AZllIXUR24nQ8ym9DVIHnb5vKBdTdktPLN/6rcAsBESJ+w7TeM7EKFzPBqRIXM+HK6AOqiH3VsWm3m800IFCOOo6BS4gaP8jaZeyvSyOBOr5TMDY6ms8OqlqN/JbC+++1wjqbb6jR+TKYFuhxszsdWtUIjpXcM62kLPUCJuN0mSFxvsWDTEz5EDCZLVDw2HEyxzM/XHYKqZEyeF1tckZM2Yq62lu6Ltk3j0V/BXwmJURdwyWuUS9R+VV7y0EIGAAA="
	barnie="H4sIAC9aQFMAA41Xz2vjOBS+96/QKEIqHlliYWmxiPNuiwk1hNanoE0e3lyGOXh6yUnjv32lOE4kO8n0QamR9H16v/VCyJdk35VL7mVVHrv9/ulLGNCspIISQindBfg76+1XoIqDFukSUsqY/DNY6itU53RnVeDLy942f0THWKKtewF0hLjl8jMnEuAxXOlEZ7QAh19+ARmA1E7+sOohgcwA0hWk5w9KBcFWWMsY549pZHMQD7Y9KTdYCUL5qyRqHki1V5fvyrlk6wZZZisZOBn7MK9uQuYAribVTl6VzHPu7C3doCXBXKO1GMiU7PL82Fm5WYvqQlG5tysIBa1OuFRkjhDukJwPXHIDecjD0pSCODci8K2QMQ4r5HLC5cB8886QG35iwhYi7Qs9GglQJUivZdYqKWh02jDDvQH/nu3Dltnu4tlMWzVSeWREVaiQUtY8u7NbNHsJkXa2Gb2OaLd2vAnt64CXTQc8prLP1uQq/zB5X+ZUCLk5LddrEYXPZ282OghCzhFysG659xvdfjzDeW0N5N8XZmWVk1wMNjdJGnimUSkM3wen8e/32pnesPI4mIvs57J+5/U/jAFfD/lbJfqMTOry3Wrmq+H4LQe+BGM2wyVId/kuh7b8OJfB4J9915c942xVhisBrIxYD/6PMVFshMlhZWhpu67TpefvgQ2qy3f9pDSDfidoEKTWcr4ks7Sj2LON+c8QffRXyYUxsFxyI5oQtgPzWW3SMqK07DSfldYQlI5vBQq1WDji6sqGDPSKPpWGVby0MQhpC23KooZ4FC+Zyo/KgEZblowD49ngWdwxSEkyntkoVc+Z4TOgz/tzV3G+0leXyIQsi7VutB2SJchh0s7OBE0UV6uvcHWKPNrVAL7TxZImzvHSBnTcqyDpW7FADHeuOH+tbRMdqu6hJ/hLg3ROR6vu7u1eioTAufr0f7MWyeoDAqySsmgbeULE+j8m8LsJQ6ODEye9Huf9NJY6LU0elKgnlxbTJprupgynJjxlwHldRDJ9bRAyWUwtf2jHYfr4+Q7z7KrJpY8ooJ29xf5JnCuO9p4l68zNOQKg01PMPXf4Mi302+2hoDAzVYobDy8J7zRWxb3RIoMZau6Wc8NxehqZK8bNHHGt4IFjHKHQVfdYDlZ/btsuIaojClleikm6ZsKidO+HFSghDGtIy4pFGTMWvupKERXk2k4skpkWp1516XB4Oe7HwM73fpq1aQFItklI/KB2xz5y6vIDI7g6WdcJx/puoUsG15ZUR8dgQhHvudU5Omov+4LFLmiuxw6iTtOkwCsFVj/MOzecv3A/+UeH/Ou5Ho/hjvpJJSVxsaFYbq2hlEylck2yiLziq+Nkhh06IlHBlKOEW3NmYvVZP7N1s9HauSrMDluAY7/CQ1HdcLdvO5MbgBFciGn6+hJ17q/vhFaeUzFNbgi2Wz6Syc5y9/vFEa6ngxCxwPyDHqaUjNJ7434Yatowqzlb+JoEo+ZE4VdVIMDHvxkI9sA/OwNGyF+LGzRfF7rrl2al6dP/22OCtXcOAAA="
	garfield="H4sIAJ5cQFMAA5WWW47DIAxF/7OKIP8hDdlQpOx/F1O/bR4pdTWdEu4xBhvCeb4boB2L5wDSqBVKmQq5Czu5oc1ByX2AvSCtV6l0g7a+aFGA3it+SFtANX9/I8ZC+hAoFrjrGakgZC0bGHVdT4dBFJb4W7iPXdd1njdyt1FljXmb1uO5hVgiPrePVV7E+x6ZAq4GWSdmKlHP89w3uCQa5UCjb60RRNiFoyHVNCOsBf19BqxpNg9JLz6zTLLYmgFTkrlPNPQIgjQGSOslmEQqYNGnkIKl0mWTbgJtOZ0jlIXEtWyAJC8pgqBxdqIGA4d/HqosTNaBfXkoMseawTimz8nD0B+lHzFNUCThUeCsaqiIWm9acv3DlH/oFWVtXd2wveiLdEdMuS+DoCBSp5T/FPETSsroCDW4pgAMSKde2MkziI6m/uBaAjKpHwGK6viRiMu1j3TMl4l0ydxDiu7FXwi0lMlNBhfbsX3KN9Mm6GVSU7q+kVJ3DGsF7sFIagaKb5WRnr2mwHdjCXDYmSOTad5HYTetcKeMtnGTLXDl9N8w8PvoGYfFwOkwS50DXufwNr7i9/B18HKEv/IDbR5Ad0q4CcV7jEUQfMdbHNagBIEecs6mk7BbTHVfcjYQL7fD6CDef0o46ocJmY8iV66+Bs1leFf0XeKjgLsxFyE2WHqQONQJ5HTE6aWXVnQgdwG1cCV+cZFjGF83ekBM75STIFYOBocdbo43+T6i4x9WhIAHTg0AAA=="

#	smileydecoder=""
	smileydecoder="echo \"$thumbsup\" | base64 -d | gunzip"           # yes, \"$garfield\"; no, the $ shouldn't be backslashed
	booming=""
	[ "$rootdev" != "" ] || failed "Please specify rootdev when calling make_initramfs_homemade(). Thanks."
	rm -Rf $INITRAMFS_DIRECTORY
	mkdir -p $INITRAMFS_DIRECTORY
	cd $INITRAMFS_DIRECTORY

	mkdir -p dev etc etc/init.d bin proc mnt tmp var var/shm bin sbin sys run
	chmod 755 . dev etc etc/init.d bin proc mnt tmp var var/shm

	cp $BOOM_PW_FILE $INITRAMFS_DIRECTORY/.sha512boom
	cd $INITRAMFS_DIRECTORY/dev
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
sha512boom=\"\`cat /.sha512boom\`\"
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
" > $INITRAMFS_DIRECTORY/etc/fstab
	chmod 644 $INITRAMFS_DIRECTORY/etc/fstab

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
" > $INITRAMFS_DIRECTORY/init
# FYI, base64 uses -d in busybox but -D in the 'grown-up' version of base64; weird...!
	chmod 755 $INITRAMFS_DIRECTORY/init
	echo "$login_shell_code" > $INITRAMFS_DIRECTORY/log_me_in.sh
	chmod +x $INITRAMFS_DIRECTORY/log_me_in.sh
	cd $INITRAMFS_DIRECTORY/bin
	if [ -e "/usr/bin/busybox" ] ; then
		cp /usr/bin/busybox busybox
	elif [ -e "$tmproot/usr/bin/busybox" ] ; then
		cp $tmproot/usr/bin/busybox busybox
	else
		failed "Unable to find busybox on your disk"
	fi
	for f in [ ar awk basename cat chgrp chmod chown chroot chvt clear cp cut date dc dd deallocvtdf dirname dmesg du dumpkmap dutmp echo false fbset fdflush find free freeramdisk fsck.minix grep gunzip gzip halt head hostid hostname id init insmod kill killall length linuxrc ln loadacm loadfont loadkmap logger logname lsmod makedevs mkdir mdev mkfifo mkfs.minix mknod mkswap mktemp more mount mt mv nc nslookup ping pivot_root poweroff printf ps pwd reboot rm rmdir rmmod sed setkeycodes sh sleep sort swapoff swapon switch_root syn c syslogd tail tar tee telnet test touch tr tri true tty umount uname uniq update uptime usleep uudecode uuencode wc which whoami yes zcat ; do
		ln -sf busybox $f
	done
	chmod 4555 busybox
	cd $INITRAMFS_DIRECTORY/sbin
	ln -sf ../init .
	cd $INITRAMFS_DIRECTORY/bin
	ln -sf ../init .
	cd $pwd
}


make_initramfs_hybrid() {
	local pwd tmpfile mytemptarball
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	mytemptarball=/tmp/$RANDOM$RANDOM$RANDOM.tgz
	pwd=`pwd`
make_initramfs_homemade $1 $2 &> $tmpfile || failed "Failed to make custom initramfs -- `cat $tmpfile`"
	cd $INITRAMFS_DIRECTORY
	mkdir -p uberroot
#	wget http://bit.ly/1idXPUN -O - | tar -Jx -C uberroot|| failed "Failed to insert uberroot"
	tar -cz . > $mytemptarball
	cd $pwd
	echo -en "..."
make_initramfs_saralee $1 $2 &> $tmpfile || failed "Failed to make prefab initramfs  -- `cat $tmpfile`"
	echo -en "..."
	cd $INITRAMFS_DIRECTORY
	tar -zxf $mytemptarball || failed "Failed to merge the two"
	cd $pwd
}



make_initramfs_saralee() {
	local f myhooks root
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



migrate_phase_1() {
	local mydevbyid dev dev_p orig_dev petname root boot kern cores
	root=/tmp/_root # /tmp/$RANDOM$RANDOM$RANDOM
	boot=/tmp/_boot # /tmp/$RANDOM$RANDOM$RANDOM
	kern=/tmp/_kern # /tmp/$RANDOM$RANDOM$RANDOM
	mydevbyid=$1
	cores=1									# 1 # `get_number_of_cores`
	[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
	[ -e "$mydevbyid" ] || failed "Please insert a thumb drive or SD card and try again. Please DO NOT INSERT your keychain thumb drive."
	dev=`deduce_dev_name $mydevbyid`
	dev_p=`deduce_dev_stamen $dev`
	petname=`find_boot_drive | cut -d'-' -f3 | tr '_' '\n' | tail -n1 | awk '{print substr($0,length($0)-7);}' | tr '[:upper:]' '[:lower:]'`
	orig_dev=$mydevbyid
	umount $root/{dev/pts,dev,proc,sys,tmp} &> /dev/null || echo -en "..."
	umount $root/{dev/pts,dev,proc,sys,tmp} &> /dev/null || echo -en "..."
	umount "$dev_p"* &> /dev/null || echo -en "..."
	umount "$dev_p"* &> /dev/null || echo -en "..."
	umount "$dev"* &> /dev/null || echo -en "..."
	umount "$dev"* &> /dev/null || echo -en "..."

	echo -en "Installing $DISTRO on $dev; the GUI will be `cat /tmp/.clarion_gui_name.txt`\n\n"
	set_the_fstab_format_and_mount_opts
	partition_device $dev $dev_p $petname
	format_phase1_partitions $dev $dev_p
	sync; mount_phase1_everything        $root $boot $kern $dev $dev_p
	sync; install_phase1_OS              $root $boot $kern $dev $dev_p
	sync; tweak_phase1_package_manager	 $root
	sync; install_phase1_kernel          $root $boot $kern $dev $dev_p
	sync; install_phase1_imptt_pkgs      $root $boot $kern
	sync; tweak_phase1_fstab_n_locale    $root                     $dev_p $petname
	sync; download_phase1_mkfs_n_kernel  $root $boot $kern $dev $dev_p $petname
	sync;setup_phase1_gui_kernel_n_tools $root $boot $kern $dev $dev_p $petname $cores # install GUI; build kernel; install tor etc.
	sync; setup_phase1_postinstall       $root
	sync; sign_and_write_custom_kernel   $root "$dev_p"1 "$dev_p"3 "" ""
	sync; install_phase1_acpi_and_powerboom $root
#echo "OK. Now, I shall save the entire filesystem to a tarball. I rock."
#umount /dev/sda* &> /dev/null || echo -en ""
#umount /dev/sdb* &> /dev/null || echo -en ""
#umount /dev/sdc* &> /dev/null || echo -en ""
#mkdir -p /tmp/dest
#mount /dev/sda3 /tmp/dest || mount /dev/sdb3 /tmp/dest || mount /dev/sdc3 /tmp/dest || failed "Well, crap..."
#echo "Mounted. Good. Unmounting src stuff..."
#rm -Rf /tmp/dest/*
#for r in 1 2 3 4 ; do
#	for s in dev/pts dev proc tmp sys ; do
#		sync; umount $root/$s &> /dev/null || echo -en ".."
#	done
#done
#
#rm -Rf $root/var/cache/pacman/pkg	#unneeded cache of packages
#rm -Rf $root/usr/share/doc
#rm -Rf $root/usr/share/gtk-doc
#rm -Rf $root/usr/share/man
#rm -Rf $root$KERNEL_SRC_BASEDIR/src/chromeos-3.4/Documentation
#rm -Rf $root/usr/src/linux-3.4.0-ARCH
#ln -sf $KERNEL_SRC_BASEDIR/src/chromeos-3.4 $root/usr/src/linux-3.4.0-ARCH || echo "That new ln of yours failed. Bummer."
#rm -Rf $root$RYO_TEMPDIR/ArchLinuxARM*.tar.gz $root/root/ArchLinuxARM*.tar.gz $root/ArchLinuxARM*.tar.gz
#rm -Rf $root$KERNEL_SRC_BASEDIR/*.tar.gz
#rm -Rf $root$KERNEL_SRC_BASEDIR/src/*.tar.gz
#
#cd $root
#tar -cJ * > /tmp/dest/alarm-rootfs.tar.xz
#echo "Done. Proceed... :-) "
	sync; unmount_phase1_everything      $root $boot $kern
}



migrate_phase_2_or_3() {
	local rootdev dev dev_p partno sA sB petname mydevbyid
	mydevbyid=$1
	cd /						# Is this necessary?
	petname=`deduce_homedrive | cut -d'-' -f3 | tr '_' '\n' | tail -n1 | awk '{print substr($0,length($0)-7);}' | tr '[:upper:]' '[:lower:]'`
	# Where am I running? If I'm on p2, we're ready to start futzing with p3.
	rootdev=`mount | grep " / " | cut -d' ' -f1` || failed "Failed to deduce rootedv"
	dev=`find_boot_drive`
	dev_p=`deduce_dev_stamen $dev` || failed "Failed to deduce dev stamen"
	sB=`basename $dev_p`
	sA=`basename $rootdev`
	partno=`echo "$sA" | sed s/$sB//` || failed "Failed to deduce partno"

# OK. If root is encrypted, most of the above values will suck. So, let's redo it if we have to.
	if cat /proc/cmdline | grep cryptdevice=/dev &> /dev/null ; then
		echo "Phase 3 (with encrypted root)... clearly... "
		rootdev=`cat /proc/cmdline | tr -s ' ' '\n' | grep cryptdevice | cut -d'=' -f2 | cut -d':' -f1`
		partial=`echo "$rootdev" | sed s/p[0-9][0-9]// | sed s/p[0-9]//`
		echo "$partial" | grep mmcblk &> /dev/null && dev=$partial || dev=`echo $partial | tr '[0-9]' '\n' | head -n1`
		dev_p=`deduce_dev_stamen $dev`
#echo "encrypt_home_phase3_at_last() --- dev=\"$dev\""
#echo "a = `deduce_my_dev`"
#echo "b = `deduce_homedrive`"

#dev="`deduce_my_dev`"
#dev_p="`deduce_dev_stamen $dev`"

		echo "OK. Now.... dev=$dev dev_p=$dev_p ... Better?"
	fi

	if mount | grep dev/mapper | grep " / " | grep -v /vroot &> /dev/null ; then
		migrate_phase_3 "$dev" "$dev_p" $petname
	elif [ "$partno" = "3" ] ; then
		migrate_phase_2 "$dev" "$dev_p" $petname
	else
		failed "Unknown partno - $partno"
	fi
	sync;sync;sync
}



migrate_phase_2() {
	local dev_p dev fstype petname src_dev dest_dev dest_mount
	dev=$1
	dev_p=$2
	petname=$3
	does_custom_kernel_cut_the_mustard $dev $dev_p $petname || failed "Kernel does not cut the mustard"
	echo "Kernel is good. Preparing to encrypt root partition..."
	[ "$CRYPTOROOTDEV" != "" ] && dest_dev=$CRYPTOROOTDEV || failed "Why are you encrypting /root if CRYPTOROOTDEV is blank?"
	src_dev="$dev_p"3
	dest_mount=/tmp/dest_mount
	fstype=""
	while [ "$fstype" != "btrfs" ] && [ "$fstype" != "ext4" ] && [ "$fstype" != "jfs" ] && [ "$fstype" != "xfs" ] ; do
		echo -en "Which filesystem format shall I use (btrfs or xfs)? "
		[ -e "/tmp/.myfstype" ] && fstype="`cat /tmp/.myfstype`" || read fstype
		[ "$fstype" != "btrfs" ] && [ "$fstype" != "ext4" ] && [ "$fstype" != "jfs" ] && [ "$fstype" != "xfs" ] && fstype=""
		if [ "$fstype" = "jfs" ] ; then
			echo "No! I can't make jfs run reliably on a root partition. Perhaps I need to add"
			echo "fsck.jfs to the initial root filesystem. I don't know. Anyway, please don't."
		fi
	done
	echo $fstype > /etc/.fstype
	set_the_fstab_format_and_mount_opts

	mkdir -p /usr/share/dbus-1/services
	echo -en "[D-BUS Service]\nName=org.freedesktop.Notifications\nExec=/usr/lib/notification-daemon-1.0/notification-daemon\n" > /usr/share/dbus-1/services/org.gnome.Notifications.service # See https://wiki.archlinux.org/index.php/Desktop_notifications

	umount "$dev_p"2 &> /dev/null || echo -en "..."
	rm -Rf /var/cache/pacman $RYO_TEMPDIR/ArchLinuxARM*.tar.gz /root/ArchLinuxARM*.tar.gz /ArchLinuxARM*.tar.gz &    # Save disk space
	mv -f /etc/fstab /etc/fstab.orig
	cat /etc/fstab.orig | grep -v " / " | grep -v " /home " > /etc/fstab
	systemctl enable syslog-ng
	localectl set-keymap us			&& echo "Set keymap OK"		|| echo "Warning - unable to set_keymap"
	localectl set-x11-keymap us		&& echo "Set X11 keymap OK" || echo "Warning - unable to set_x11_keymap"
	tweak_phase2_chrome
	tweak_phase2_autologin
	add_phase2_guest_user
	add_phase2_reboot_user
	add_phase2_shutdown_user
	add_phase2_guest_browser_script
	do_phase2_audio_stuff
	activate_phase2_gui_and_wifi

	clear
	setup_phase2_rootpassword "/"	# FIXME one day, we can do away with the '/' :)
	install_phase2_timezone "/"		# FIXME one day, we can do away with the '/' :)
	echo "
%wheel ALL=(ALL) ALL
ALL ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff,/usr/bin/systemctl halt,/usr/bin/systemctl reboot,/usr/local/bin/tweak_lxdm_and_reboot,/usr/local/bin/tweak_lxdm_and_shutdown,/usr/local/bin/run_as_guest.sh
" >> /etc/sudoers
	echo -en "search localhost\nnameserver 8.8.8.8\n" >> /etc/resolv.conf

	echo "installing & activating privacy tools"
	setup_phase2_privacy_tools

	move_phase2_all_data_from_p3_to_p2 $dev $dev_p $petname $src_dev $dest_dev $dest_mount # ... and leave dest mounted
	echo -en "Adding new initramfs to kernel..."
	redo_mbr $dev_p
	chmod +x /root/.*sh					# FIXME is this necessary?
	sync;sync;sync; sleep 1
	echo -en "Unmounting $dest_dev"...
	umount "$dest_dev" &> /dev/null && echo "Done." || echo "Non-fatal error --- failed to unmount $dest_dev after migration"
	sync;sync;sync; sleep 1
#	cryptsetup close `basename $CRYPTOROOTDEV` &> /dev/null || echo "Non-fatal error --- failed to close encrypted partition."
	sync;sync;sync
}


function ctrl_c() {
	echo "** Trapped CTRL-C"
}



migrate_phase_3() {
	local res dev dev_p petname 
	dev=$1
	dev_p=$2
	petname=$3
	fstype=`cat /etc/.fstype`
	[ "$dev" = "" ] && failed "migrate_phase_3() -- dev not specified"
	[ "$dev_p" = "" ] && failed "migrate_phase_3() -- dev_p not specified"
	logger "QQQ - migrate_phase_3() - connecting to wifi"
#	trap ctrl_c INT				# trap ctrl-c and call ctrl_c()
#	/usr/local/bin/wifi_manual.sh

	logger "QQQ - migrate_phase_3() - tweaking display-manager.service"
	cd /etc/systemd/system
	cat display-manager.service | grep lxdm &> /dev/null && echo -en ""|| failed "For some reason, display-manager.service does not mention lxdm. That sucks. KDM? Say it ain't so..."
	cat display-manager.service | sed s/ExecStart=.*/ExecStart=\\\/usr\\\/local\\\/bin\\\/ersatz_lxdm.sh/ > dm.s
	rm display-manager.service
	mv dm.s display-manager.service

	logger "QQQ - migrate_phase_3() - setting up dropbox"
	setup_phase3_dropbox
	encrypt_home_phase3_at_last "$dev" "$dev_p" "$fstype" || failed "encrypt_home_phase3_at_last() --- failed"
	install_phase3_boom_code

	redo_mbr $dev_p					# TODO	consider running this in the background, while installing GUI and tools
	sync;sync;sync; sleep 1
	sync;sync;sync; sleep 1

	logger "QQQ - migrate_phase_3() - creating checksums"
#	[ -e "/etc/resolv.conf.orig" ] && mv /etc/resolv.conf.orig /etc/resolv.conf
	sha512sum "$dev_p"1 | cut -d' ' -f1 > /etc/$KERNEL_CKSUM_FNAME && echo "Written checksum to /etc" || failed "Failed to gen cksum for kernel"
	mount | grep " /home " &> /dev/null && cp -f /etc/$KERNEL_CKSUM_FNAME /home/ || echo "WARNING - /home not mounted; can't store checksum there."

	logger "QQQ - migrate_phase_3() - end"
}



modify_all() {
# Modify all source files - kernel, mkbtrfs, mkxfs, etc. - in preparation for their recompiling
	local serialno haystack NOPHEASANTS NOKTHX randomized_serno root
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
	modify_kernel_init_source $root/$KERNEL_SRC_BASEDIR/src/chromeos-3.4
	[ "$NOKTHX" = "" ] && modify_magics_and_superblocks $randomized_serno "$haystack" || echo "OK. No kthx this time..." > /dev/stderr
	if [ "$NOPHEASANTS" = "" ] ; then
		modify_kernel_usb_source $root/$KERNEL_SRC_BASEDIR/src/chromeos-3.4 $serialno "$haystack"
		modify_kernel_mmc_source $root/$KERNEL_SRC_BASEDIR/src/chromeos-3.4 $serialno "$haystack"
	else
		echo "OK. No pheasants, this time..." > /dev/stderr
	fi
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
	[ ! -e "$data_file.orig" ] && mv $data_file $data_file.orig
	echo "// modified automatically by $0 on `date`
extern int getPheasant(void);
extern void setPheasant(int);

" > $data_file
	grep "$key_str" $data_file.orig > /dev/null || failed "Unable to find \"$key_str\" in $data_file.orig"
	cat $data_file.orig | sed s/"$key_str"/"$replacement"/ >> $data_file # | sed -e ':loop' -e 's/\;\ /\;\n/' -e 't loop' >> $data_file
	rm $data_file.orig
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



mount_phase1_everything() {
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
	mkdir -p $root/{dev,sys,proc,tmp}
	mount devtmpfs $root/dev -t devtmpfs|| failed "Failed to mount /dev"
	mount sysfs $root/sys -t sysfs		|| failed "Failed to mount /sys"
	mount proc $root/proc -t proc		|| failed "Failed to mount /proc"
	mount tmpfs $root/tmp -t tmpfs		|| failed "Failed to mount /tmp"
	echo	 "OK."
}



move_phase2_all_data_from_p3_to_p2() {
	local dev dev_p petname res f src_dev dest_dev dest_mount tmpfile
	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
	dev=$1
	dev_p=$2
	petname=$3
	src_dev=$4
	dest_dev=$5
	dest_mount=$6

	[ "$dev" = "" ] && failed "move_phase2_all_data_from_p3_to_p2() --- dev was blank"
	[ "$dev_p" = "" ] && failed "move_phase2_all_data_from_p3_to_p2() --- dev_p was blank"
	[ "$petname" = "" ] && failed "move_phase2_all_data_from_p3_to_p2() --- petname was blank"
	[ "$src_dev" = "" ] && failed "move_phase2_all_data_from_p3_to_p2() --- src_dev was blank"
	[ "$dest_dev" = "" ] && failed "move_phase2_all_data_from_p3_to_p2() --- dest_dev was blank"
	[ "$dest_mount" = "" ] && failed "move_phase2_all_data_from_p3_to_p2() --- det_mount was blank"

# Migrate from p3 to p2
	f="/usr/lib/systemd/system-generators/systemd-gpt-auto-generator"
	[ -e "$f" ] && mv $f /etc/.ssgsgag.disabled # to stop silly error messages
	if [ "$CRYPTOROOTDEV" != "" ] ; then
		res=999
		while [ "$res" -ne "0" ] ; do
			res=0
			echo -en "\n\n"
			echo "Type YES (not yes or Yes but YES). Then, please choose a strong"
			echo "password with which to encrypt root ('/'). Enter it three times."
			cryptsetup -v luksFormat "$dev_p"2 -c aes-xts-plain -y -s 512 -c aes -s 256 -h sha256 || res=1
			[ "$res" -ne "0" ] && echo "Cryptsetup returned an error"
		done
		res=999
		while [ "$res" -ne "0" ]; do
			cryptsetup open "$dev_p"2 `basename $CRYPTOROOTDEV` && res=0 || res=1
		done
		echo -en "\n\nRules for the 'boom' password:-\n1. Don't leave it blank.\n2. Don't reuse another password."
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

	echo "$boompw" | sha512sum | cut -d' ' -f1 > $BOOM_PW_FILE
	boompw=""
	boompwB=""

	echo -en "\nFormatting..."
	yes | mkfs.$fstype $format_opts $dest_dev &> $tmpfile ||failed "Failed to format for phase 2 - `cat $tmpfile`"	# Format p2 (or cryptroot) with kthx'd format

	echo -en "Cleaning up fstab..."
	mv /etc/fstab /etc/fstab.tmp
	cat /etc/fstab.tmp | grep -v " /boot " | grep -v " / " > /etc/fstab # fix p3's format str in fstab
	[ "$format_opts" = "" ] && [ "$fstype" != "ext4" ] && failed "For some reason, format_opts is blank again. Grr."

	echo -en "Migrating files (this will take a while)..."
	mount | grep " /home " &> /dev/null && umount /home || echo -en ""
	mount | grep "$src_dev " &> /dev/null || failed "copy_all_from_one_device_to_another() - $src_dev (source) is not mounted - weird"
	src_mount=`mount | grep "$src_dev " | cut -d' ' -f3`
	mount | grep "$dest_dev " &> /dev/null&& failed "copy_all_from_one_device_to_another() - $dest_dev (dest) is already mounted - weird" || mkdir -p   $dest_mount
	mount $dest_dev $mount_opts $dest_mount || failed "Failed to mount $dest_dev (dest)"
	mkdir -p $dest_mount/{dev,proc,sys,tmp}
	for r in bin boot etc home lib mnt opt root run sbin srv usr var ; do
		echo -en "$r..."
		cp -af $src_mount/$r $dest_mount
	done
	echo "Done."
}



partition_device() {
	local dev dev_p
	dev=$1
	dev_p=$2
	ser=$3
	echo -en "Partitioning "$dev"...\r"
	parted $dev mklabel gpt
	cgpt create -z $dev
	cgpt create $dev
	cgpt add -i  1 -t kernel -b  8192 -s 32768 -l U-Boot -S 1 -T 5 -P 10 $dev
	cgpt add -i 12 -t data   -b 40960 -s 32768 -l Script $dev
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	cgpt add -i  2 -t data   -b 73728 -s `expr $SPLITPOINT - 73728` -l Kernel $dev
	cgpt add -i  3 -t data   -b $SPLITPOINT -s `expr $lastblock - $SPLITPOINT - $EOD_PADDING` -l Root $dev
	partprobe $dev
}



pivot_phase1_debian_bootstrap_via_archlinux() {
	local root boot archlinuxhome dev dev_p f
	root=$1
	boot=$2
	archlinuxhome=$3		# a.k.a. $kern
	dev=$4
	dev_p=$5
# Install archlinux into $archlinuxhome
	wget -O - http://archlinuxarm.org/os/ArchLinuxARM-chromebook-latest.tar.gz | tar -zx -C $archlinuxhome || failed "Failed to bootstrap/untar"
	wget --quiet -O - http://commondatastorage.googleapis.com/chromeos-localmirror/distfiles/$SNOWBALL > $TEMPDIR/$SNOWBALL
	mkdir -p $archlinuxhome/root

	echo "Preparing ArchLinux inner..."
	mkdir -p $archlinuxhome/{proc,dev,sys,tmp}
	mount proc   $archlinuxhome/proc	-t proc
	mount dev    $archlinuxhome/dev		-t devtmpfs
	mkdir -p     $archlinuxhome/dev/pts
	mount devpts $archlinuxhome/dev/pts -t devpts
	mount sys    $archlinuxhome/sys		-t sysfs
	mount tmpfs	 $archlinuxhome/tmp		-t tmpfs
	mkdir -p	 $archlinuxhome/debian

	wget bit.ly/OB3yY2 -q -O - | tar -zx -C $archlinuxhome # unzip debootstrap
	ln -sf /proc/mounts $archlinuxhome/etc/mtab
	mv $archlinuxhome/etc/resolv.conf $archlinuxhome/etc/resolv.conf.old
	echo "search gateway.pace.com
nameserver 192.168.1.254
nameserver 8.8.8.8
" > $archlinuxhome/etc/resolv.conf

	chroot_this $archlinuxhome "mkdir -p /tmp/bd"
	chroot_this $archlinuxhome "yes | pacman -Syu"
	chroot_this $archlinuxhome "yes | pacman -S --needed wget binutils make patch git dosfstools ed" # debian-archive-keyring gnupg1"

	echo "Building debootstrap package within ArchLinux"
	rm -f $archlinuxhome/usr/bin/debootstrap
	rm -Rf $archlinuxhome/usr/share/debootstrap
	wget https://aur.archlinux.org/packages/de/debootstrap/debootstrap.tar.gz -O - | tar -zx -C $archlinuxhome/root
	chroot_this $archlinuxhome "cd /root/debootstrap; makepkg --asroot -f; yes \"\" | pacman -U debootstrap*pkg.tar.xz" || failed "Failed to install debootstrap in ArchLinux"

	echo "Mounting Debian stuff within ArchLinux"
	mount "$dev_p"3 $archlinuxhome/debian
	mkdir -p $archlinuxhome/debian/{proc,dev,sys,tmp}
	mount proc   $archlinuxhome/debian/proc -t proc
	mount dev    $archlinuxhome/debian/dev  -t devtmpfs
	mkdir -p     $archlinuxhome/debian/dev/pts
	mount devpts $archlinuxhome/debian/dev/pts -t devpts
	mount sys	 $archlinuxhome/debian/sys     -t sysfs
	mount tmpfs  $archlinuxhome/debian/tmp   -t tmpfs

	echo "Running debootstrap in ArchLinux, to generate Debian"
	chroot_this $archlinuxhome "debootstrap --no-check-gpg --verbose --arch=$DEBIAN_ARCHITECTURE --variant=buildd --include=aptitude,netbase,ifupdown,net-tools,linux-base $DEBIAN_BRANCH /debian http://ftp.uk.debian.org/debian/" || echo "Warning - debootstrap returned an error" # --foreign?

	echo "Tweaking sources.list"
	cat $archlinuxhome/debian/etc/apt/sources.list | sed s/main/main\ contrib\ non-free/ > /tmp/adeaslm
	cp  /tmp/adeaslm						   $archlinuxhome/debian/etc/apt/sources.list
	cat /tmp/adeaslm | sed s/deb\ /deb-src/ >> $archlinuxhome/debian/etc/apt/sources.listt # add deb-src to sources.list
	chroot_pkgs_upgradeall $archlinuxhome/debian

	echo "Copying mkinitcpio and lz4 across from ArchLinux to Debian"
	chroot_this $archlinuxhome "yes | pacman -S --needed mkinitcpio" # o not use chroot_pkgs_install; it will assume you're Debian, not ArchLinux
	cd $archlinuxhome
	f="`find {usr,etc} | grep mkinit` `find {usr,etc} | grep initcpio` `find {usr,bin} -name lz4`"
	tar -cz $f | tar -zx -C $archlinuxhome/debian
	cd /

	echo -en "Unmounting things"
	for f in $archlinuxhome/debian/sys $archlinuxhome/debian/dev/pts $archlinuxhome/debian/dev $archlinuxhome/debian/proc $archlinuxhome/debian/tmp $archlinuxhome/debian $archlinuxhome/sys $archlinuxhome/tmp $archlinuxhome/sys $archlinuxhome/dev/pts $archlinuxhome/dev ; do
		sync;sync;sync;sleep 1
		umount $f &> /dev/null && echo -en "..." || echo -en ",,,"
	done

	echo "Copying firmware files from ArchLinux to Debian"
	sync;sync;sync;sleep 1
	cp -af $archlinuxhome/usr/lib/firmware $root/usr/lib/firmware
	umount $archlinuxhome/dev/pts $archlinuxhome/dev $archlinuxhome/proc &> /dev/null && echo -en "..." || echo -en ",,,"

	sync;sync;sync;sleep 1
	echo -en "Still unmounting"
	mkdir -p $archlinuxhome/.old && echo -en "."
	mv $archlinuxhome/[a-z]* $archlinuxhome/.old/ && echo -en "."

	sync;sync;sync;sleep 1 && echo -en "."
	umount $archlinuxhome/dev/pts $archlinuxhome/dev $archlinuxhome/proc &> /dev/null && echo -en "..." || echo -en ",,,"
	mount | grep "$archlinuxhome/" && failed "1780 --- some still mounted in chroot; darn..." || echo "Pivot chroot thing done. Good."

	echo "Done."
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
	if [ "$DISTRO" = "ArchLinux" ] ; then
		yes | pacman -R "$1" # FIXME do this quietly (...but -q doesn't work)
	else
		failed "I do not know how to uninstall packages for distro '$DISTRO'"
	fi
	return $?
}

pkgs_upgradeall() {
	chroot_pkgs_upgradeall "/"
}



redo_mbr() {
	local dev_p
	dev_p=$1
	[ -e "$BOOM_PW_FILE" ] || failed "No boom pw cksum file"
	rm -f $KERNEL_SRC_BASEDIR/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg
	rm -f /root/.vmlinuz.signed
	rm -f `find $KERNEL_SRC_BASEDIR | grep initramfs | grep lzma | grep -vx ".*\.h"`
	make_initramfs_hybrid "/" $CRYPTOROOTDEV
	pkgs_make $KERNEL_SRC_BASEDIR 39600
	sign_and_write_custom_kernel "/" "$dev_p"1 $CRYPTOROOTDEV "cryptdevice="$dev_p"2:`basename $CRYPTOROOTDEV`" "" # TODO try "$dev_p"3
}



replace_this_magic_number() {
    local fname list_to_search needle replacement found root
	root=$1
    needle="$2"
    replacement="$3"
    for fname in `grep -rnli "$needle" $root$SOURCES_BASEDIR`; do
        if echo "$fname" | grep -x ".*\.[c|h]" &> /dev/null; then
	    [ ! -e "$fname.orig" ] && mv $fname $fname.orig
            cat $fname.orig | sed s/"$needle"/"$replacement"/ > $fname
            if cat $fname | fgrep "$needle" &> /dev/null ; then
                echo "$needle is still present in $fname; is this an uppercase/lowercase problem-type-thingy?"
            else
		echo -en "."
	    fi
	    rm $fname.orig
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
	[ -e "/etc/.fstype" ] && fstype=`cat /etc/.fstype` || fstype=ext4
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



setup_phase1_gui_kernel_n_tools() {
	local root boot kern dev dev_p petname cores
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	petname=$6
	cores=$7
	if [ "$cores" -eq "0" ] ; then
		sync; install_phase1_gui_n_its_tools $root
		sync; modify_phase1_mkfs_n_kernel  $root $boot $kern $dev $dev_p $petname 1
		sync; make_phase1_mkfs_n_kernel    $root $boot $kern $dev $dev_p $petname 1
	else
		echo "INSTALLING GUI IN THE BACKGROUND WHILE I COMPILE MK*FS AND KERNEL IN FOREGROUND"
		sync; install_phase1_gui_n_its_tools $root &> /tmp/install_phase1_gui_n_its_tools.txt & background_process_number=$!
		sync; modify_phase1_mkfs_n_kernel  $root $boot $kern $dev $dev_p $petname $cores
		sync; make_phase1_mkfs_n_kernel    $root $boot $kern $dev $dev_p $petname $cores
		while ps $background_process_number &> /dev/null ; do
			echo "`date` Waiting for installer to finish..."
			sleep 60
		done
		if tail -n20 /tmp/install_phase1_gui_n_its_tools.txt | grep "install_phase1_gui_n_its_tools - SUCCESS" ; then
			echo "Built kernel *and* installed GUI... OK."
		else
			cat /tmp/install_phase1_gui_n_its_tools.txt
			failed "Failed to install GUI"
		fi
	fi
# At this point, the background process (if there be one) has terminated. We're down to one thread again. Cool...
	sync; install_phase1b_all_internally $root $boot $kern $dev $dev_p # install kernel, mk*fs, and all other (locally built) packages
}



setup_phase1_postinstall() {
	local root svcfile
	root=$1
	echo "Setting up post-install script"
	touch $root/root/.profile
	echo "#!/bin/bash
failed() {
echo \"\$1\"
exit 1
}

[ -e \"/tmp/.running\" ] && exit 1 || touch /tmp/.running
cd /lib/firmware
ln -sf s5p-mfc/s5p-mfc-v6.fw mfc_fw.bin
[ ! -e "mfc_fw.bin" ] && failed \"Failed to fix firmware.\"

res=999
echo 0 > /proc/sys/kernel/hung_task_timeout_secs
bash /usr/local/bin/clarion.sh
" > $root/root/.postinstall.sh

	chmod +x $root/root/.postinstall.sh
	echo "bash ~/.postinstall.sh" > $root/root/.profile
	svcfile=$root/usr/lib/systemd/system/getty@.service
	if [ -e "$svcfile" ] ; then
		mv $svcfile $svcfile.orig
		cat $svcfile.orig | sed s/'--noclear'/'--autologin\ root\ --noclear'/ > $svcfile
		cat $svcfile | grep autologin &> /dev/null || failed "WHAARGBARBARL"
	fi

# To fix JFS hangs (perhaps)
	echo "
vm.vfs_cache_pressure=90
vm.dirty_ratio = 1
" >> $root/etc/sysctl.conf
}



setup_phase2_display_manager() {                   # This paves the way for phase 3. WE MUST start as root when doing phase 3.
	local f unf
	f=/etc/lxdm/lxdm.conf
	liu=/tmp/.logged_in_user

# Fix conf file; autologin on (root) (for initial /home encryption setup), skip_[blank]_password=on, session default = lxde
	mv $f $f.orig
	cat $f.orig | \
sed s/.*autologin=.*/autologin=root/ | \
sed s/.*skip_password=.*/skip_password=1/ | \
sed s/.*session=.*/session=\\\/usr\\\/bin\\\/wmaker/ > $f
	cp $f $f.orig												# to make sure the 'session' info is propagated permanently

	write_lxdm_post_login_script	>> /etc/lxdm/PostLogin
	generate_startx_addendum		>> /etc/lxdm/PreLogin
	write_lxdm_pre_login_script		>> /etc/lxdm/PreLogin
	echo ". /etc/X11/xinitrc/xinitrc" >> /etc/lxdm/Xsession
	write_lxdm_post_logout_script	>> /etc/lxdm/PostLogout
	write_lxdm_xresources_addendum	>> /root/.Xresources

# Setup ersatz lxdm
	echo "#!/bin/sh

if [ -e \"/tmp/.okConnery.thisle.44\" ] ; then
  cat /etc/lxdm/lxdm.conf.orig | sed s/.*autologin=.*/###autologin=/ | sed s/.*session=.*/session=\\\\/usr\\\\/bin\\\\/startlxde/ > /etc/lxdm/lxdm.conf
elif [ ! -e \"/usr/local/bin/mount_home\" ] ; then
  cat /etc/lxdm/lxdm.conf.orig | sed s/.*autologin=.*/autologin=root/ | sed s/.*session=.*/session=\\\\/usr\\\\/bin\\\\/wmaker/> /etc/lxdm/lxdm.conf
else
  mpg123 /etc/.welcome.mp3 &
  cat /etc/lxdm/lxdm.conf.orig | sed s/.*autologin=.*/autologin=guest/ | sed s/.*session=.*/session=\\\\/usr\\\\/bin\\\\/wmaker/ > /etc/lxdm/lxdm.conf
fi
touch /tmp/.okConnery.thisle.44
lxdm
exit \$?
" > /usr/local/bin/ersatz_lxdm.sh
	chmod +x /usr/local/bin/ersatz_lxdm.sh

}



setup_phase2_rootpassword() {
	local res root
	root=$1
	res=999
	while [ "$res" -ne "0" ] ; do
		echo -en "\nNow, please choose a root password.\n"
		chroot_this $root "passwd" && res=0 || res=1
	done
}



setup_phase2_privacy_tools() {
	local f proxy_str

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
" >> /etc/privoxy/config

# Enable them, but don't bother starting any of them. We're about to reboot, after all.

# FIXME Is this necessary?
	for f in privoxy tor freenet; do # i2p
		systemctl disable $f || failed "Unable to disable $f"
	done
}


wait_and_then_open_browser() {
	while ! ping -W5 -c1 8.8.8.8 &> /dev/null ; do
		sleep 1
	done
	/usr/local/bin/run_browser_as_guest.sh https://www.dropbox.com/developers/apps/
}

setup_phase3_dropbox() {
	local res loops
	logger "QQQ - setup_phase3_dropbox() - opening dropbox.com website"
	wait_and_then_open_browser &
	echo "When asked, 'Can your app be limited to its own, private folder?', click YES. For permission type, enter 'a'."
	res=999
	loops=0
	while [ "$res" -ne "0" ] ; do
		/usr/local/bin/dropbox_uploader.sh upload /etc/.happy.mp3 happy.mp3 && res=0 || res=1
		if [ "$res" -eq "0" ] ; then
			/usr/local/bin/dropbox_uploader.sh upload /etc/.happy.mp3 happy.mp3 || res=1
			/usr/local/bin/dropbox_uploader.sh delete happy.mp3					|| res=1
		fi
		loops=$(($loops+1))
		[ "$loops" -gt "20" ] && failed "We failed $loops times. We tried to interface with Dropbx, but we failed, precious."
	done
	echo "setup_phase3_dropbox() - complete"
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



test_kernel_and_mkfs() {
# Can we format, mount, read/write, and unmount a filesystem of type ___?
	local res1 res2 res3 res4
	[ "$1" = "" ] && failed "test_kernel_and_mkfs() was called without a serial#"
	[ "$2" = "" ] && failed "test_kernel_and_mkfs() was called without a mydev"
	test_kernel_and_mkfs_SUB $1 $2 ext2  ""				 ""					&& res4=0 || res4=1
	test_kernel_and_mkfs_SUB $1 $2 xfs   "-f"			 ""					&& res3=0 || res3=1
	test_kernel_and_mkfs_SUB $1 $2 jfs   "-f"			 ""					&& res2=0 || res2=1
	test_kernel_and_mkfs_SUB $1 $2 btrfs "-f -O ^extref" "-o compress=lzo"	&& res1=0 || res1=1
	return $(($res1+$res2+$res3+$res4))
}



test_kernel_and_mkfs_SUB() {
	local tmpfile fstype mountpt res format_opts mount_opts mydev fstype
	mount_opts="$5"
	format_opts="$4"
	fstype=$3
	tmpfile=/tmp/tkam.dat
	mountpt=/tmp/tkam.mnt
	rm -Rf $mountpt
	mkdir -p $mountpt
	echo -en "Testing this OS's ability to use $fstype properly"
	dd if=/dev/zero of=$tmpfile bs=1024k count=32 &> /dev/null
	sync
	res=0
	losetup /dev/loop0 $tmpfile
	mkfs.$fstype $format_opts /dev/loop0 &> /dev/null || res=$((res+1))
	if [ "$res" -ne "0" ] ; then
		echo "...can't even format."
		losetup -d /dev/loop0
		rm $tmpfile
		return 1
	fi
	dd if=$tmpfile of=/tmp/firstblock.$fstype.dat bs=128k count=1 &> /dev/null
	mount /dev/loop0 $mountpt &> /dev/null # -t $fstype $mount_opts $mountpt || res=$(($res+1))
	if [ "$res" -ne "0" ] ; then
		echo "...format but can't mount."
		losetup -d /dev/loop0
		rm $tmpfile
		return 2
	fi
	echo "Hello world" > $mountpt/bingo.txt
	umount /dev/loop0
	sync;sync;sync
	mount /dev/loop0  $mountpt  || res=$(($res+1))
	if [ "$res" -ne "0" ] ; then
		echo -en "...format, mt, dmt, but can't re-mount."
		losetup -d /dev/loop0
		rm $tmpfile
		return 3
	fi
	cat $mountpt/bingo.txt | grep "Hello world" &> /dev/null || res=$(($res+1))
	umount $mountpt
	losetup -d /dev/loop0 &> /dev/null
	rm -Rf $tmpfile $mountpt
	if [ "$res" -ne "0" ] ; then
		echo -en "...format, mount, dmt, rmt, but can't save/load."
		return 4
	fi
	echo "...format, mt, dmt, rmt, l/s, dmt OK"
}



tweak_phase1_fstab_n_locale() {
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
	echo $t >> $root/etc/fstab
	echo $u >> $root/etc/fstab
	echo -en "Adjusting hostname"
	echo "$petname" | grep devroot &> /dev/null && petname=alarm || echo -en "..."
	if [ "$DISTRO" = "Debian" ] ; then
		petname="debarm"
	elif [ "$DISTRO" = "ArchLinux" ] ; then
		petname="alarm"
	else
		petname="$DISTRO" # QQQ
	fi
	echo "$petname" > $root/etc/hostname
	echo -en "Done. Localizing..."
	echo "LANG=\"en_US.UTF-8\"" > $root/etc/locale.conf
	echo "en_US.UTF-8 UTF-8" >> $root/etc/locale.gen
	echo "KEYMAP=\"us\"" > $root/etc/vconsole.conf	|| echo "Warning - unable to setup vconsole.conf"
	if [ "$DISTRO" = "ArchLinux" ] ; then
		chroot_this $root "locale-gen"
	elif [ "$DISTRO" = "Debian" ] ; then
		chroot_pkgs_install $root "locales"
		chroot_this $root "dpkg-reconfigure locales"
	else
		failed "Unknown distro - '$DISTRO' - line 2040(ish)"
	fi

	echo "Done."
}



tweak_phase1_package_manager() {
	echo $root
	root=$1
	echo "Tweaking package manager"
	if [ "$DISTRO" = "ArchLinux" ];  then
		mv  $root/etc/pacman.d/mirrorlist $root/etc/pacman.d/mirrorlist.good
		cat $root/etc/pacman.d/mirrorlist.good | sed s/#IgnorePkg.*/IgnorePkg\ =\ linux-chromebook\ linux-headers-chromebook\ btrfs-progs\ xfsprogs\ jfsutils/ > $root/etc/pacman.d/mirrorlist
	elif [ "$DISTRO" = "Debian" ] ; then
		failed "migrate_phase1_package_manager() - Debian-specific stuff for phase 2? Shouldn't I exclude btrfs-tools, xfsprogs, jfsutils, and the Linux kernel from upgrades...?"
	else
		failed "migrate_phase1_package_manager() --- how should we handle '$DISTRO'?"
	fi
}



tweak_phase2_autologin() {
	echo -en "Disabling autologin..."
	rm -f /root/.profile
	svcfile=/usr/lib/systemd/system/getty\@.service
	if [ -e "$svcfile" ] ; then
		mv  $svcfile /etc/q.q
		cat /etc/q.q | sed s/--autologin\ root// > $svcfile
	fi
}



tweak_phase2_chrome() {
	local chromefile
	chromefile=`which chromium` || failed "Fannot find chromium"
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



unmount_phase1_everything() {
	echo -en "Unmounting everything..."
	sync;sync;sync; sleep 1
	umount $1/tmp $1/proc $1/sys $1/dev &> /dev/null && echo ":-)" || echo ":-/"
	umount $1/tmp $1/proc $1/sys $1/dev &> /dev/null || echo -en ""
	umount $1 $2 $3 &> /dev/null && echo "..." || echo ",,,"
	sync;sync;sync
}




ask_a_bunch_of_questions_prior_to_phase_1() {
	local do_it_again r
#	echo -en "Would you like to install (A)rchLinux or (D)ebian? "
# 	read r
#	case $r in
#		"A") DISTRO="ArchLinux";;
#		"D") DISTRO="Debian";;
#		*)   failed "Unknown distro";;
#	esac
	DISTRO="ArchLinux" # FIXME let the user choose
	echo "$DISTRO" > /tmp/.mydistrochoice
	do_it_again="yes"


# guiname=All; rootsizeMB=$(($rootsizeMB+4000)); pkgs="cinnamon enlightenment terminology xfce4-goodies xfce4 xfce4-session xfce4-notifyd"; ;;      # kde-meta
# guiname=Cinnamon; pkgs="cinnamon";;
# guiname=Enlightenment; pkgs="enlightenment terminology";;
# guiname=KDE; rootsizeMB=$(($rootsizeMB+1200)); pkgs="kdebase kdeutils kdeartwork kdeadmin kdebindings kdegraphics kdelibs kdemultimedia kdenetwork kdepim kdeplasma kdetoys";;
r=L; guiname=LXDE; pkgs=""; # lxde is ALWAYS installed :) (vvv see 6-7 lines down from here vvv)
# guiname=XFCE; pkgs="xfce4-goodies xfce4 xfce4-session xfce4-notifyd";; #  xfce4-notifyd-config
	echo "$r" > /tmp/.myguichoice
	echo "$pkgs lxdm lxde windowmaker" > /tmp/.clarion_gui_pkgs.txt # ALWAYS install lxde & wmaker :) as backups, at least
	echo "$guiname" > /tmp/.clarion_gui_name.txt
}



write_lxdm_post_login_script() {
	local f unf
	f=/etc/lxdm/lxdm.conf
	liu=/tmp/.logged_in_user

	echo "
logger \"QQQ start of postlogin script\"
export DISPLAY=:0.0
echo \"\$USER\" > $liu

if ps -o pid -C wmaker &>/dev/null; then
#if ps wax | grep wmaker | grep -v grep &> /dev/null ; then
  logger \"QQQ - starting wmsystemtray & nm-applet for WiFi\"
  if ps -o pid -C wmsystemtray &>/dev/null; then
#  if ps wax | grep wmsystemtray | grep -v grep ; then
	echo \"Running wmsystemtray already\"
  else
    wmsystemtray &
  fi
  sleep 1
  if ps -o pid -C nm-applet &>/dev/null; then
#  if ps wax | grep nm-applet | grep -v grep &> /dev/null ; then
    echo \"Running nm-applet\"
  else
    nm-applet &
  fi
fi

if [ \"\$USER\" = \"root\" ] && [ ! -e \"/usr/local/bin/mount_home\" ] ; then
  urxvt -geometry 120x30+0+320 -name \"Clarion\" -e sh -c \"/usr/local/bin/clarion.sh\" &
  # see http://www.reddit.com/r/linux/comments/1k57a5/xterm_replacement_so_many_alternatives_but_which/
fi

. /etc/bash.bashrc
. /etc/profile
xscreensaver -no-splash &
logger \"QQQ end of postlogin script\"
"


}



write_lxdm_post_logout_script() {
	local f unf
	f=/etc/lxdm/lxdm.conf
	liu=/tmp/.logged_in_user

	echo "
rm -f $liu

logger \"QQQ - terminating current user session and restarting lxdm\"
# Terminate current user session
/usr/bin/loginctl terminate-session \$XDG_SESSION_ID
# Restart lxdm
/usr/bin/systemctl restart lxdm.service
"
}



write_lxdm_pre_login_script() {
	local f unf
	f=/etc/lxdm/lxdm.conf
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



write_mounthome_script() {
	local rootdev dev partial dev_p
	rootdev=`cat /proc/cmdline | tr -s ' ' '\n' | grep cryptdevice | cut -d'=' -f2 | cut -d':' -f1`
	partial=`echo "$rootdev" | sed s/p[0-9][0-9]// | sed s/p[0-9]//`
# This next line sets $dev :)
	echo "$partial" | grep mmcblk &> /dev/null && dev=$partial || dev=`echo $partial | tr '[0-9]' '\n' | head -n1`
# OK, now we have $dev; good! Let's get $dev_p
	dev_p=`deduce_dev_stamen $dev`
#echo "dev=$dev    dev_p=$dev_p" >>/dev/stderr




	echo "#!/bin/sh
failed() {
  echo \"\$1\"
  exit 1
}
get_dev_serno() {
  dev=$dev   # yes, literally
  dev_p=$dev_p   # yes, literally
  bname=\"\`basename \$dev\`\"
  mydevbyid=\"/dev/disk/by-id/\`ls -l /dev/disk/by-id/ | grep -x \".*\$bname\" | tr ' ' '\n' | grep \"_\"\`\"
  petname=\"\`echo \"\$mydevbyid\" | tr '-' '\n' | fgrep -v \":\" | tail -n1 | awk '{print substr(\$0, length(\$0)-7, 8)};'\`\"
  echo \$petname | tr '[:upper:]' '[:lower:]'
}
mount_me_now() {
  randf=/tmp/\$RANDOM\$RANDOM\$RANDOM
  wholekey=/tmp/\$RANDOM\$RANDOM\$RANDOM
  res=999
  actual_cksum=\"\`sha512sum "$dev_p"1 | cut -d' ' -f1\`\"
  orig_cksum_1=\"\`cat /etc/$KERNEL_CKSUM_FNAME\`\"
  if [ \"\`get_dev_serno\`\" != \"`get_dev_serialno $dev`\" ] ; then	# first expr has backticks; second expr does not
    mpg123 /etc/.wrongSD.mp3 &> /dev/null &
    logger \"QQQ boot/root device has wrong ser# --- danger, Will Robinson\"
    touch $BOOMFNAME
  elif [ \"\`ls /dev/disk/by-id/ | grep mmc-SEM | head -n1\`\" != \"`get_internal_serial_number`\" ]; then
    mpg123 /etc/.wrongCB.mp3 &> /dev/null &
    logger \"QQQ Internal drive has wrong ser# --- danger, Will Robinson\"
  elif [ \"\$orig_cksum_1\" != \"\$actual_cksum\" ] ; then
	mpg123 /etc/.error1.mp3 &> /dev/null &
    logger \"QQQ Kernel checksum mismatch #1 --- danger, Will Robinson\"
    touch $BOOMFNAME
  else
    logger \"QQQ cksum good #1\"
  fi

  [ -e \"$BOOMFNAME\" ] && exec /usr/local/bin/boom.sh
  /usr/local/bin/dropbox_uploader.sh download `basename $keyfileB` \$randf || failed \"Unable to download remote key half\"
  echo \"serno = \`get_dev_serno\`\"

  get_dev_serno > \$wholekey
  cat /etc/.clarion.k.1 >> \$wholekey
  ls /dev/disk/by-id/ | grep mmc-SEM | head -n1 >>\$wholekey
  cat \$randf >> \$wholekey

  hexdump \$wholekey > /root/keyfile.txt.reconstituted

  cryptsetup luksOpen $homepartition `basename $CRYPTOHOMEDEV` --key-file \$wholekey
  mount $mount_opts $CRYPTOHOMEDEV /home
  shred -u \$randf
  shred -u \$wholekey
  if mount | grep \" /home \" &> /dev/null ; then
    orig_cksum_2=\"\`cat /home/$KERNEL_CKSUM_FNAME\`\"
    if [ \"\$orig_cksum_2\" != \"\$actual_cksum\" ] ; then
	  mpg123 /etc/.error2.mp3 &> /dev/null &
      logger \"QQQ Kernel checksum mismatch #2 --- danger, Will Robinson\"
      exec /usr/local/bin/boom.sh
    else
      logger \"QQQ cksum good #2\"
      mpg123 /etc/.happy.mp3 &> /dev/null &
	  export DISPLAY=:0.0
	  xmessage -buttons Yes:0,No:1,Cancel:2 -default Yes -nearmouse \"Log out of guest mode?\" -timeout 30
	  res=\$?
      logger \"res=\$res\"
	  if [ \"\$res\" -eq \"0\" ] ; then
        pkill -kill -u "\`cat /tmp/.logged_in_user\`"
	  fi
    fi
  else
	mpg123 /etc/.sad.mp3 &> /dev/null &
  fi
  return \$res
}

logger \"QQQ mount_home() --- waiting for Internet\"
while ! ping -W5 -c1 8.8.8.8 ; do
    sleep 1
done
mpg123 /etc/.online.mp3 &
logger \"QQQ mount_home() --- mounting\"
mount_me_now
res=\$?

for f in privoxy tor freenet; do # i2p
  systemctl start \$f || echo \"Unable to start \$f\"
done

/usr/local/bin/run_browser_as_guest.sh &

exit \$res
" 
}



write_mounthome_service() {
	echo "
[Unit]
Description=Congress
DefaultDependencies=no
After=
Before=basic.target
Conflicts=shutdown.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mount_home
ExecStop=
"
}


# ------------------------------------------------------------------



export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin # Just in case phase 3 forgets to pass $PATH to the xterm call to me
set -e
clear
echo "$0 -------------------------------------- starting --------------------------------------"
#echo "FYI, this version includes a 200MB+ initrd, for test porpoises; it resides at /uberroot"
if mount | grep /dev/mapper/encstateful &> /dev/null ; then # running under ChromeOS
	mydevbyid=`deduce_my_dev`
	[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
	ask_a_bunch_of_questions_prior_to_phase_1
	migrate_phase_1 $mydevbyid
else
	DISTRO="`cat /etc/.mydistrochoice`"
	migrate_phase_2_or_3 $mydevbyid
fi

echo -en "\n\n\n\n\n\n\nPress ENTER to reboot, or wait 60 seconds.\n"
read -t 60 line || echo -en ""
reboot
exit 0
