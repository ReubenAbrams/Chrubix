#!/bin/bash
#
# create_alarpy_tarball.sh
# - generates an ArchLinux tarball (alarm+Python) from within ChromeOS
# - asks user to upload it to Dropbox etc.
# - terminates
#
# FYI, this tarball is to be used by chrubix_stage1.sh
#
# To run, type:-
# cd && wget bit.ly/1o7erNo -O xx && sudo bash xx
#################################################################################



# TODO
# Try removing Perl etc. during junk removal phase


TEMPDIR=/tmp
ARCHLINUX_ARCHITECTURE=armv7h
RYO_TEMPDIR=/root/.rmo
SPLITPOINT=NONONONONONONONO
RANDOMIZED_SERIALNO_FILE=/etc/.randomized_serno
if ping -W2 -c1 192.168.1.73 ; then
	WGET_PROXY="192.168.1.73:8080"
elif ping -W2 -c1 192.168.1.66 ; then
	WGET_PROXY="192.168.1.66:8080"
else
	WGET_PROXY=""
fi
[ "$WGET_PROXY" != "" ] && export http_proxy=$WGET_PROXY




failed() {
	echo "$1" >> /dev/stderr
	logger "QQQ - failed - $1"
	if mount | grep "cryptroot" &> /dev/null ; then
		echo -en "Press ENTER to continue."; read line
	fi
	exit 1
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
chroot_pkgs_install $root "curl lzop pv ed sudo bzr xz bc cpio unzip libtool dtc xmlto docbook-xsl uboot-mkimage wget dosfstools python3 pkg-config cgpt syslog-ng parted python-setuptools" && res=0 || res=1	 # busybox tzdata make ccache patch git automake autoconf autogen expect cryptsetup
		loops=$(($loops+1))
		[ "$loops" -gt "5" ] && failed "We failed $loops times. We tried to install the Phase One imptt pkgs, but we failed, precious."
	done
	chroot_this $root "easy_install urwid"

	mkdir -p $root/usr/local/bin/
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
	mv $root/etc/resolv.conf $root/etc/resolv.conf.pristine || failed "Failed to save original resolv.conf"
	cp /etc/resolv.conf $root/etc/						    || failed "Failed to copy the ChromeOS resolv.conf into chroot"
	echo "$randomized_serno" > $root$RANDOMIZED_SERIALNO_FILE
	return 0
}



partition_device() {
	local dev dev_p
	dev=$1
	dev_p=$2

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
	rm -Rf $root/usr/share/doc
	rm -Rf $root/usr/share/man
	rm -Rf $root/usr/bin/include
	rm -Rf $root/usr/lib/firmware
#	mv $root/usr/share/locale/locale.alias /root/
#	rm -Rf $root/usr/share/locale/{a-d}*
#	rm -Rf $root/usr/share/locale/{f-z}*
#	mv $root/locale.alias $root/usr/share/locale/
	rm -Rf $root$KERNEL_SRC_BASEDIR/src/chromeos-3.4/Documentation
	rm -Rf $root/usr/src/linux-3.4.0-ARCH
	ln -sf $KERNEL_SRC_BASEDIR/src/chromeos-3.4 $root/usr/src/linux-3.4.0-ARCH || echo "That new ln of yours failed. Bummer."
	rm -Rf $root$RYO_TEMPDIR/ArchLinuxARM*.tar.gz $root/root/ArchLinuxARM*.tar.gz $root/ArchLinuxARM*.tar.gz
	rm -Rf $root$KERNEL_SRC_BASEDIR/*.tar.gz
	rm -Rf $root$KERNEL_SRC_BASEDIR/src/*.tar.gz
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
	petname="alarpy"
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
	orig_dev=$mydevbyid
	set_the_fstab_format_and_mount_opts

# TEST PORPOISES
# Eventually, this whole procedure will run from start to finish... and then save the filesystem to a tarball on $kern ("$dev_p"2).
# That tarball will be uploaded to Dropbox, whence it will be downloaded & used by stage1.sh :)

	partition_device $dev $dev_p
	format_partitions $dev $dev_p
	sync; mount_everything         $root $boot $kern $dev $dev_p
	sync; install_OS               $root $boot $kern $dev $dev_p || failed "Failed to install OS..."
	mkdir -p $root/{dev,sys,proc,tmp}
	mount devtmpfs $root/dev -t devtmpfs|| failed "Failed to mount /dev"
	mount sysfs $root/sys -t sysfs		|| failed "Failed to mount /sys"
	mount proc $root/proc -t proc		|| failed "Failed to mount /proc"
	mount tmpfs $root/tmp -t tmpfs		|| failed "Failed to mount /tmp"
	sync; tweak_package_manager	   $root
	sync; install_imptt_pkgs       $root $boot $kern
	wget bit.ly/1mj99jZ -O - | tar -zx -C $root		# install vbutils_*
	tweak_fstab_n_locale     $root                     $dev_p $petname
	remove_junk_from_distro		   $root
	umount $root/{dev,proc,sys,tmp}
	echo -en "Generating tarball..."
	cd $root
	tar -cJ * > /home/chronos/user/Downloads/alarpy.tar.xz || failed "Failed to create tarball in Downloads folder"
	echo "YAY... Success. Upload /home/chronos/user/Downloads/alarpy.tar.xz to Dropbox, please."
exit 0
}


sizeof() {
	echo $(du -sb "$1" | awk '{ print $1 }')
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

function ctrl_c() {
	echo "** Trapped CTRL-C"
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



setup_postinstall() {
	local root
	root=$1
# enable lxdm (display manager)
# amend .conf (autologin as root, into wmaker)
# amend postlogin (start wmsystemtray and the wifi thing)
# generate other X resource files
	ln -sf s5p-mfc/s5p-mfc-v6.fw $root/lib/firmware/mfc_fw.bin || echo "WARNING - unable to tweak firmware"
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



# ------------------------------------------------------------------


export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin # Just in case phase 3 forgets to pass $PATH
set -e
clear
echo "---------------------------------- ALARPY FILESYSTEM TARBALL GENERATOR ----------------------------------"
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

