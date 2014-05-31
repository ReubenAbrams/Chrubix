#!/bin/sh
#
# debian.sh
# - partition, format, and prep a thumb drive to run Debian Linux
#
# TODO
# - install & configure X Window and a window manager (e? xfce?)
#
# CHANGES
# 201403131642  imported into Xcode
# 201402241640	script works --- leave it alone :)
# 201402241520	option to encrypt / partition of Debian installation
#		...It doesn't work, *but* it's avaiable (set cryptrootdev to /dev/mapper/cryptroot to enable)
# 201402221940	it works; LEAVE IT ALONE :)
# 201402221200	added ruby and rubygems to apt-get install
# 201402210815	BYO (ArchLinux) kernel (in Debian)
# 201402201445	moved the calls to apt-get around a bit
# 201402201415	works 100%... wait, no, it doesn't
# 201402201400	new kilkenny boots OK w/ ChromeOS kernel... but weird error w/ tty
# 201402181430	using ChromeOS kernel, not ArchLinux kernel
# 201402172130	it works.. hahaha...	
# 201402152300	format /home in $exotic_fs; add it to fstab, too
# 201402151600	created
##########################################################################



balldir=/tmp
fstype=ext4
orig_pwd=`pwd`
splitpoint=7999999
rootsubdir=/tmp/root
cryptrootdev=""                                  # /dev/mapper/cryptroot
archlinuxhome=/tmp/archlinuxhome
tarball=ArchLinuxARM-chromebook-latest.tar.gz
debootstrap_exe=/tmp/debootstrap_exe
debian_branch_on_which_i_am_based=squeeze
debian_architecture=armel  # armhf is an option for wheezy only; armel is for squeeze


am_i_a_drone() {
#    if [ -e "/home/chronos/user" ] ; then
    if mount | grep /dev/mapper/encstateful &> /dev/null ; then
        return 1    
    else
        return 0
    fi
}


call_debootstrap() {
	local dev dev_p fnam dev dev_p res archlinuxhome
	archlinuxhome=$1
	dev=$2
	dev_p=$3

	echo "Calling debootstrap. This will take several minutes."
# variants available: builddb, minbase
#	if am_i_a_drone ; then
#		DEBOOTSTRAP_PARAMS IS NO MORE    $debootstrap_exe $debootstrap_params
#		res=$?
#	else
		build_debian_within_archlinux $dev $dev_p $archlinuxhome
		res=$?
#	fi

#echo "
#deb http://ftp.uk.debian.org/debian/ $debian_branch_on_which_i_am_based main contrib non-free
#deb-src http://ftp.uk.debian.org/debian/ $debian_branch_on_which_i_am_based main contrib non-free
#" > $root/etc/apt/sources.list
	return $res
}


chroot_this() {
	local res
	echo "#!/bin/sh

$2
exit \$?
" > $1/do-me.sh
	chmod +x $1/do-me.sh
	res=0
	chroot $1 /do-me.sh || res=$?
	rm $1/do-me.sh
	return $res
}


download_and_build_debootstrap_etc() {
	    local dbdir r
	    r=/home/chronos/user
	    [ ! -e "$r" ] && r=/root
	    dbdir=$r/.rmo/PKGBUILDs/core/debootstrap
	    if which debootstrap &> /dev/null ; then
		bootstrap_exe=`which debootstrap`
	    else
		if am_i_a_drone ; then
		        echo "Downloading debootstrap"
		        mkdir -p $dbdir
		        cd $dbdir
		        wget https://aur.archlinux.org/packages/de/debootstrap/debootstrap.tar.gz
		        tar -zxvf debootstrap.tar.gz
		        cd debootstrap
		        makepkg --asroot -f
		        yes | pacman -U debootstrap*pkg.tar.xz
			debootstrap_exe=`which debootstrap`
		else
		    echo "Downloading tarballs"
		    [ ! -e "$balldir/$tarball" ] && wget http://archlinuxarm.org/os/ArchLinuxARM-chromebook-latest.tar.gz -O - > $balldir/$tarball
		fi
  	    fi
	echo "Downloaded OK"
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


failed() {
	echo "$1" >> /dev/stderr
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
	local dev dev_p
	dev=$1
	dev_p=$2
	echo "Formatting partitions..."
	echo "    1/4..."
	mkfs.ext2 "$dev_p"2                       &> /tmp/ttt.ttt || cat /tmp/ttt.ttt
	echo "    2/4..."
	yes | mkfs.$fstype $format_opts "$dev_p"3 &> /tmp/ttt.ttt || cat /tmp/ttt.ttt
	echo "    3/4..."
	yes | mkfs.$fstype $format_opts "$dev_p"4 &> /tmp/ttt.ttt || cat /tmp/ttt.ttt   # ext4 "$dev_p"4 
	echo "    4/4..."
	yes | mkfs.vfat -F 16 "$dev_p"12
}


install_additional_tools() {
	local root bork dev_p mytemp pwd dev r archlinuxhome
	archlinuxhome=$1
	dev=$2
	dev_p=$3
	pwd=`pwd`
	root=$archlinuxhome$rootsubdir
	bork=$root/boot
	echo "Cleaning up Debian"

# Install cgpt, vboot, etc.
	[ ! -e "$root/etc/apt/sources.list.orig" ] && mv $root/etc/apt/sources.list $root/etc/apt/sources.list.orig
	echo "
deb http://ftp.uk.debian.org/debian/ $debian_branch_on_which_i_am_based main contrib non-free
deb-src http://ftp.uk.debian.org/debian/ $debian_branch_on_which_i_am_based main contrib non-free
deb http://ftp.uk.debian.org/debian/ sid main contrib non-free
deb-src http://ftp.uk.debian.org/debian/ sid main contrib non-free
" > $root/etc/apt/sources.list
	chroot_this $root "apt-get update"
	chroot_this $root "apt-get install -y --force-yes cgpt vboot-utils vboot-kernel-utils firmware-libertas"
	cp -f $root/etc/apt/sources.list.orig $root/etc/apt/sources.list
	chroot_this $root "apt-get update"

	echo "Installing console setup, module tools, etc."
	#  libyaml-syck-perl live-build syslinux-common ikiwiki libyaml-perl rubygems rake
	chroot_this $root "apt-get install -y --force-yes module-init-tools wicd-daemon wicd-cli time whois wicd-curses console-setup udev nano ed binutils u-boot"	
	echo "Installing goodies..."
#  make patch intltool git
	chroot_this $root "yes | apt-get install -f --force-yes wget parted pv cryptsetup dosfstools wireless-tools" || echo "WARNING - failed to install all the goodies"
	echo "Good. Continuing..."
	chroot_this $root "ln -sf /proc/mounts /etc/mtab"
}




build_kernel_and_modules() {
	local root bork dev_p mytemp pwd dev fstype my_root_device kernel_twelve_dev ikal kernel_version_str archlinuxhome
	archlinuxhome=$1
	root=$archlinuxhome$rootsubdir
	bork=$root/boot
	dev=$2
	dev_p=$3
	fstype=$4
	pwd=`pwd`
	my_root_device="$dev_p"3
	kern_twelve_dev="$dev_p"12
	ikal=/tmp/$RANDOM$RANDOM$RANDOM

	am_i_a_drone && failed "build_kernel_and_modules() --- I've no idea how to do this."
	echo "Building kernel"
	rm -f $bork/vm*
	chroot_this $root "cd /home/root/PKGBUILDs/core/linux-chromebook/src/chromeos-*/; make"
# make oldconfig; make config; make install"
}


install_kernel() {
	local root bork dev_p mytemp pwd dev fstype my_root_device kernel_twelve_dev ikal kernel_version_str recently_compiled_kernel signed_kernel archlinuxhome
	archlinuxhome=$1
	root=$archlinuxhome$rootsubdir
	bork=$root/boot
	dev=$2
	dev_p=$3
	fstype=$4
	pwd=`pwd`

	my_root_device="$dev_p"3
	kern_twelve_dev="$dev_p"12
	ikal=/tmp/$RANDOM$RANDOM$RANDOM
	am_i_a_drone && failed "install_kernel() --- I've no idea how to do this."
	echo "Installing vanilla ChromeOS binary glob (kernel & modules)"
	cd $root
	rm -f $bork/vm*
	wget https://dl.dropboxusercontent.com/u/59916027/klaxon/cuckoo.tgz -q -O - | tar -zx

	recently_compiled_kernel=$bork/vmlinuz
	signed_kernel=$bork/vmlinuz.signed
	ln -sf /proc/mounts $root/etc/mtab
#	chroot_this $root "ln -sf /proc/mounts /etc/mtab"

	if [ "$cryptrootdev" != "" ] ; then
		if ! cat $bork/kernel.flags | grep crypt ; then
			[ ! -e "$bork/kernel.flags.orig" ]
		fi
		echo "console=tty1 printk.time=1 nosplash rootwait cryptdevice=$my_root_device:`basename $cryptrootdev` root=$cryptrootdev rw rootfstype=ext4 lsm.module_locking=0" > $bork/kernel.flags
	fi

# cryptdevice=/dev/sda3:cryptroot root=/dev/mapper/cryptroot 

	echo "Signing the kernel"
	vbutil_kernel --pack $bork/vmlinuz.signed --keyblock \
/usr/share/vboot/devkeys/kernel.keyblock --version 1 \
--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
--config $bork/kernel.flags --vmlinuz $bork/vmlinuz \
--arch arm

	dd if=$bork/vmlinuz.signed of="$dev_p"1 bs=4M
	cd $pwd
}


partition_device() {
	local dev dev_p
	dev=$1
	dev_p=$2
	ser=$3
	echo "Installing on $dev (ser#$ser)"
	parted $dev mklabel gpt
	cgpt create -z $dev
	cgpt create $dev
	cgpt add -i 1 -t kernel -b 34 -s 40926 -l uboot/kernel -S 1 -T 5 -P 15 $dev
	cgpt add -i 2 -t data -b 40960 -s 32768 -l Kernel $dev
	cgpt add -i 12 -t data -b 73728 -s 32768 -l Script $dev
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	cgpt add -i 3 -t data -b 106496 -s `expr $splitpoint - 106496` -l Root $dev
	cgpt add -i 4 -t data -b $splitpoint -s `expr $lastblock - $splitpoint` -l Home $dev
	partprobe $dev
}


tweak_fstab_and_resolv() {
	local archlinuxhome root dev_p petname s t u v my_fstype
	archlinuxhome=$1
	dev_p=$2
	petname=$3
	root=$archlinuxhome$rootsubdir
	my_fstype=`echo "$fstype" | cut -d' ' -f1`

	echo "Tweaking fstab etc."
	echo "
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /tmp         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0
" > $root/etc/fstab
	s="$dev_p"
	if [ "$cryptrootdev" != "" ] ; then
		t="$cryptrootdev /     $my_fstype $fstab_opts 0 0"
	else
		t=$s"3 / $my_fstype $fstab_opts 0 0"
	fi
        u=$s"2 /boot ext4       defaults    0 0"
	v=$s"4 /home $my_fstype $fstab_opts 0 0"
	echo $t >> $root/etc/fstab
	echo $u >> $root/etc/fstab
	echo $v >> $root/etc/fstab

	echo "Adjusting hostname"
	echo "$petname" > $root/etc/hostname

	echo "Setting root password to be empty"
	chroot_this $root "passwd -d root"

# fix resolv.conf
	echo "search gateway.pace.com
nameserver 192.168.1.254
" > $root/etc/resolv.conf
}


set_the_fstab_format_and_mount_opts() {
	fstab_opts="defaults,noatime,nodiratime"
	mount_opts="-o $fstab_opts"
	format_opts=""
	if [ "$fstype" = "btrfs" ] ; then
		fstab_opts=$fstab_opts",compress=lzo"
		mount_opts="-o $fstab_opts"
		format_opts="-f -O ^extref"
	elif [ "$fstype" = "jfs" ] ; then
		format_opts="-f"
    elif [ "$fstype" = "xfs" ] ; then
        format_opts="-f"
	elif [ "$fstype" = "ext4" ] ; then
		format_opts=""
	elif [ "$fstype" = "jffs2" ] ; then
		format_opts="-f"
	else
		echo "Unknown format - '$fstype'"
		exit 1
	fi
}


test_kernel_and_mkfs() {
	local res1 res2 res3
    [ "$1" = "" ] && failed "test_kernel_and_mkfs() was called without a serial#"
    [ "$2" = "" ] && failed "test_kernel_and_mkfs() was called without a mydev"
	test_kernel_and_mkfs_SUB $1 $2 btrfs "-f -O ^extref"
	res1=$?
	test_kernel_and_mkfs_SUB $1 $2 xfs   "-f"
	res2=$?
	test_kernel_and_mkfs_SUB $1 $2 jfs   "-f"
	res3=$?
	sync;sync;sync
	return $(($res1+$res2+$res3))
}


test_kernel_and_mkfs_SUB() {
    local tmpfile fstype mountpt res format_opts mount_ops mydev fstype
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
    mkfs.$fstype $format_opts /dev/loop0 &> /tmp/txt.txt || res=$((res+1))
    res=$(($res+$?))
    if [ "$res" -ne "0" ] ; then
		cat /tmp/txt.txt
		echo "...can't even format."
		losetup -d /dev/loop0
		rm $tmpfile
		return 1
	fi

    dd if=$tmpfile of=/tmp/firstblock.$fstype.dat bs=128k count=1 &> /dev/null
    mount /dev/loop0 $mountpt &> /dev/null # -t $fstype $mount_opts $mountpt
    res=$(($res+$?))
    if [ "$res" -ne "0" ] ; then
		echo "...format but can't mount."
		losetup -d /dev/loop0
		rm $tmpfile
		return 2
	fi

	echo "Hello world" > $mountpt/bingo.txt
	umount /dev/loop0
	sync
	mount /dev/loop0 -t $fstype $mount_opts $mountpt
	res=$(($res+$?))
	if [ "$res" -ne "0" ] ; then
		echo -en "...format, mt, dmt, but can't re-mount."
		losetup -d /dev/loop0
		rm $tmpfile
		return 3
	fi

	cat $mountpt/bingo.txt | grep "Hello world" &> /dev/null
	res=$(($res+$?))
	umount $mountpt
    losetup -d /dev/loop0 &> /dev/null
    rm -Rf $tmpfile $mountpt
	if [ "$res" -ne "0" ] ; then
		echo -en "...format, mount, dmt, rmt, but can't save/load."
		return 4
	fi
	echo "...format, mt, dmt, rmt, l/s, dmt OK"
}


unmount_everything() {
	local path root bork archlinuxhome dev dev_p
	archlinuxhome=$1
	dev=$2
	dev_p=$3
	root=$archlinuxhome$rootsubdir
	bork=$root/$boot
	echo "Unmounting everything"
	cd /

	sync;sync;sync; sleep 1
	for r in sys dev/pts dev proc ; do
		umount $archlinuxhome$rootsubdir/$r &> /dev/null || echo ":-/"
	done
	umount $bork &> /dev/null || echo ":-|"
	umount $root &> /dev/null || echo ":-("

	sync;sync;sync; sleep 1
	for r in sys dev/pts dev proc ; do
		umount $archlinuxhome/$r &> /dev/null || echo ":-\\"
	done
	if [ "$cryptrootdev" != "" ] ; then
		chroot_this $archlinuxhome "cryptsetup plainClose `basename $cryptrootdev`"
	fi
	umount $archlinuxhome &> /dev/null || echo ":-/"
	sync;sync;sync; sleep 1
	mkdir -p $archlinuxhome/.junk
	mv $archlinuxhome/[a-z]* $archlinuxhome/.junk/ &> /dev/null
	echo "Proceeding"
	return 1
}


validate_device() {
	local dev
	dev=$1
	if [ ! -e "$dev" ] ; then
		echo "Please insert a thumb drive and try again."
		echo "Please DO NOT INSERT your keychain thumb drive."
		exit 1
	fi
}


build_debian_within_archlinux() {
	local root dev dev_p fnam bork dev dev_p home pwd archlinuxhome
	dev=$1
	dev_p=$2
	archlinuxhome=$3
	root=$archlinuxhome$rootsubdir
	bork=$root/boot
	pwd=`pwd`
	echo "Little boxes..."
# mount home; install archlinux (sort of) in home; mount Debian boot and root inside Archlinux home
	mkdir -p $archlinuxhome
	mount "$dev_p"4 $archlinuxhome
	tar -zxf $balldir/$tarball -C $archlinuxhome

	echo "All the same..."
	mkdir -p $archlinuxhome/{proc,dev,sys,tmp}
	mkdir -p $root
	mount proc   $archlinuxhome/proc -t proc
	mount dev    $archlinuxhome/dev -t devtmpfs
	mkdir -p $archlinuxhome/dev/pts
	mount devpts $archlinuxhome/dev/pts -t devpts
	mount sys    $archlinuxhome/sys -t sysfs

	wget bit.ly/OB3yY2 -q -O - | tar -zx -C $archlinuxhome # unzip debootstrap
	ln -sf /proc/mounts $archlinuxhome/etc/mtab
	mv $archlinuxhome/etc/resolv.conf $archlinuxhome/etc/resolv.conf.old
	echo "search gateway.pace.com
nameserver 192.168.1.254
" > $archlinuxhome/etc/resolv.conf

	echo "Downloading tools"
	chroot_this $archlinuxhome "mkdir -p /tmp/bd"
	chroot_this $archlinuxhome "yes | pacman -Syy"
# parted uboot-mkimage gcc
	chroot_this $archlinuxhome "yes | pacman -S wget binutils make patch git dosfstools cryptsetup ed" # debian-archive-keyring gnupg1"

	if [ "$cryptrootdev" != "" ] ; then
		echo "Setting up encrypted root partition"
		chroot_this $archlinuxhome "cryptsetup -y plainOpen "$dev_p"3 `basename $cryptrootdev`"
		yes | mkfs.$fstype $format_opts $cryptrootdev &> /tmp/ttt.ttt || cat /tmp/ttt.ttt
	else
		echo "Formatting root partition"
		yes | mkfs.$fstype "$dev_p"3 &> /tmp/ttt.ttt || cat /tmp/ttt.ttt
	fi

	echo "Mounting bits and bobs"
	mkdir -p $root
	[ "$cryptrootdev" != "" ] && mount $cryptrootdev $root || mount "$dev_p"3 $root
	mkdir -p $bork
	mount "$dev_p"2 $bork # $root/boot
	mkdir -p $root/{proc,dev,sys,tmp}
	mount proc   		$root/proc -t proc
	mount 		 dev    $root/dev -t devtmpfs
	mkdir -p $root/dev/pts
	mount  		 devpts $root/dev/pts -t devpts
	mount 		 sys    $root/sys -t sysfs

	echo "Building debootstrap package within ArchLinux"
	rm -f $archlinuxhome/usr/bin/debootstrap
	rm -Rf $archlinuxhome/usr/share/debootstrap
	echo "Installing kernel from Debian image"
	chroot_this $archlinuxhome "cd /tmp/bd; wget https://aur.archlinux.org/packages/de/debootstrap/debootstrap.tar.gz; tar -zxvf debootstrap.tar.gz; cd debootstrap; makepkg --asroot -f; yes | pacman -U /tmp/bd/debootstrap/debootstrap*pkg.tar.xz"

	echo "Running debootstrap in ArchLinux, to generate Debian"
	chroot_this $archlinuxhome "debootstrap --no-check-gpg --verbose --arch=$debian_architecture --variant=buildd --include=aptitude,netbase,ifupdown,net-tools,linux-base $debian_branch_on_which_i_am_based $rootsubdir http://ftp.uk.debian.org/debian/" || echo "Warning - debootstrap returned an error"
							   # arch=armhf ? --foreign ?
	cd /
#	echo "Unmounting bits and bobs"
#	sync;sync;sync
#	umount $root/{sys,dev/pts,dev,proc} || echo "... :-/"
#	umount $bork || echo "... :-\\"
#	umount $root || echo "... :-|"
#	cryptsetup close `basename $cryptrootdev`
#	umount $archlinuxhome/{sys,dev/pts,dev,proc} || echo "Warning - unable to unmount even more stuff. This is slightly more worrying."
#	umount $archlinuxhome
	cd $pwd
}


build_backport_package() {
	echo "UNTESTED!"
	local pkgname tmpdir dlpath pwd f r
	pwd=`pwd`
	pkgname=$1
	tmpdir=/tmp/bpptmp   # /tmp/$RANDOM$RANDOM$RANDOM
	mkdir -p $tmpdir
	dlpath=`wget http://packages.debian.org/sid/$pkgname -O - | tr '"' '\n' | grep dsc | grep http | head -n1`
	cd $tmpdir
	dget -x -u $dlpath
	for f in `find . -type d -maxdepth 1` ; do
		cd $f
#		if [ -e "debian/compat" ] && [ "`cat debian/compat`" -gt "8" ] ; then
			echo 8 > debian/compat
#		fi
		dch --local ~bpo60+ --distribution $debian_branch_on_which_i_am_based-backports "Rebuilt for $debian_branch_on_which_i_am_based-backports."
		dpkg-buildpackages -us -uc &> $tmpdir/res.txt
		for r in `cat $tmpdir/res.txt | grep -i unmet | grep dependencies`; do
			yes | apt-get install $r &> /dev/null
		done
		dpkg-buildpackages -us -uc
		cd ..
	done
#	rm -Rf $tmpdir
}



# -------------------------------------------------------------------------------------------


am_i_a_drone && failed "Sorry. Run me from ChromeOS or not at all." || echo "$0 ----- starting"
export PATH=/bin:/sbin:$PATH
mkdir -p $balldir $archlinuxhome
ifconfig | grep mlan0 &> /dev/null || failed "Connect to the Internet first."
cd /tmp
noreboot=""
mydevbyid=""
for parm in $* ; do
	if echo "$parm" | grep /dev/ &> /dev/null ; then
		mydevbyid=`deduce_my_dev $parm`
	elif [ "$parm" = "noreboot" ] ; then
		noreboot=$parm
	else
		failed "What param is this? - '$parm'"
	fi
done
[ "$mydevbyid" = "" ] && mydevbyid=`deduce_my_dev`
[ "$mydevbyid" = "" ] && failed "I am unable to figure out which device you want me to prep. Sorry..."
validate_device $mydevbyid
dev=`deduce_dev_name $mydevbyid`
dev_p=`deduce_dev_stamen $dev`
orig_dev=$mydevbyid
petname=`echo "$orig_dev" | cut -d'-' -f3 | tr '_' '\n' | tail -n1 | awk '{print substr($0,length($0)-7);}' | tr '[:upper:]' '[:lower:]'`
set_the_fstab_format_and_mount_opts

umount "$dev_p"* &> /dev/null
mount | grep "$dev" &> /dev/null && ! mount | grep "$root/dev" &> /dev/null && failed "$dev is already mounted. That's bad!"
set -e
partition_device 		      $dev $dev_p $petname
format_partitions 		      $dev $dev_p
download_and_build_debootstrap_etc
call_debootstrap          $archlinuxhome $dev $dev_p 
tweak_fstab_and_resolv    $archlinuxhome $dev_p $petname
install_additional_tools  $archlinuxhome $dev $dev_p
install_kernel            $archlinuxhome $dev $dev_p $fstype
cd /
unmount_everything        $archlinuxhome $dev $dev_p || echo "Non-fatal errors occurred while unmounting"
#yes | mkfs.$fstype $format_opts "$dev_p"4 &> /dev/null
sync;sync;sync 
echo "Press ENTER to reboot."
read
reboot
exit 0
