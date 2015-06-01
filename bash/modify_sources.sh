#!/bin/bash
#
# modify_sources.sh
# - if called with CLI params, it re-works the kernel & mk*fs
#
#
#################################################################################


NOPHEASANTS=""			# If var is blank, the new kernel will use a whitelist 
NOKTHX=""				# if var is blank, the new kernel use a randomize margic number (for btrfs, jfs, xfs)
LOGLEVEL="2"		# .... or "6 debug verbose" .... or "2 debug verbose" or "2 quiet"
BOOMFNAME=/etc/.boom
BOOT_PROMPT_STRING="boot: "
TEMPDIR=/tmp
ARCHLINUX_ARCHITECTURE=armv7h
RYO_TEMPDIR=/root/.rmo
BOOM_PW_FILE=/etc/.sha512bm
KERNEL_CKSUM_FNAME=.k.bl.ck
CRYPTOROOTDEV=/dev/mapper/cryptroot			# do not tamper with this, please
CRYPTOHOMEDEV=/dev/mapper/crypthome
SOURCES_BASEDIR=$RYO_TEMPDIR/PKGBUILDs/core
INITRAMFS_DIRECTORY=$RYO_TEMPDIR/initramfs_dir
INITRAMFS_CPIO=$RYO_TEMPDIR/uInit.cpio.gz
RANDOMIZED_SERIALNO_FILE=/etc/.randomized_serno
RAMFS_BOOMFILE=.sha512boom
GUEST_HOMEDIR=/tmp/.guest
DISTRO=ArchLinux
STOP_JFS_HANGUPS="echo 0 > /proc/sys/kernel/hung_task_timeout_secs"
MAX_LENGTH_OF_STRING_OF_BAD_PHEASANTS_CAUGHT=512







make_initramfs_saralee() {
	local f myhooks root autogenerator_fname
	root=$1
	echo "make_initramfs_saralee() -- root=$root"
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






modify_mkfs_n_kernel() {
	local root boot kern dev dev_p fstype petname serialno haystack tmpfile linepos relfname fname
	root=$1
	boot=$2
	kern=$3
	dev=$4
	dev_p=$5
	petname=$6

	tmpfile=/tmp/$RANDOM$RANDOM$RANDOM

	serialno=$petname    # `get_dev_serialno $dev`
	echo "modify_mkfs_n_kernel() ---- dev=$dev --- serialno=$serialno"
	haystack="`deduce_whitelist "$dev"` (null)"          # $serialno" # Don't need to include serialno. Whitelist will add it automatically because it's plugged in already.
	[ "$serialno" = "" ] && failed "Failed to get dev serialno of $dev"

	echo "modify_mkfs_n_kernel() -- FYI, serialno=$serialno"
	echo "Modifying..."
	echo "serialno = $serialno"
	echo "haystack = $haystack"
	modify_all $root "$serialno" "$haystack"
	
	echo -en "Building a temporary prefab initramfs..."
	mkdir -p $root/lib/modules
	[ -e "$root/lib/modules/3.4.0-ARCH" ] || cp -af /lib/modules/3.4.0-ARCH $root/lib/modules/
	make_initramfs_saralee $root "" || failed "Failed to make prefab initramfs -- `cat $tmpfile`"
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
	local myvar_name serialno haystack do_if_bad_serno snprintf_or_strcpy functext tolower do_if_good_serno last_eight opening_decs my_if int_or_str parole_clause remv_dev badphez_payload varname do_if_on_shitlist
# Generate an inline C 'function' to display a given string & try to match it against the approved serial numbers
	varname=$1
	serialno="$2"
	knowngoodserials="$3"
	my_if="(needle!=NULL && strlen(needle)>0 && strstr(haystack,needle))"
	[ "$4" != "" ] && my_if="$4 || $my_if"
	int_or_str=$5
	[ "$extra_if" != "" ] && extra_if="|| $extra_if"
	echo "$varname" | grep "udev" &> /dev/null && remv_dev="usb_deauthorize_device(udev); usb_remove_device(udev); " || remv_dev="mmc_remove_card(card);"
	remv_dev="$remv_dev;
printk(KERN_INFO \"QQQ deactivated %s. Yay.\\n\", needle);
"
	badphez_payload="
printk(KERN_INFO \"QQQ G,dc bad eggs (old): %s\\n\", getShitlist());
	if (!strstr(getShitlist(), needle)) { addToShitlist(needle); }
    printk(KERN_INFO \"QQQ G,dc bad eggs (new): %s\\n\", getShitlist());
$remv_dev
"
	do_if_on_shitlist="printk(KERN_INFO \"QQQ Fsck you, buddy! We reject %s\\n\", needle);  $badphez_payload; "
	opening_decs="char ndlbuff[32]={'\\0'}; char *needle=ndlbuff; char haystack[]=\"$knowngoodserials\"; "
	tolower="char *sss; for(sss=needle; *sss; sss++) { if (*sss>='A' && *sss<='Z') *sss=*sss + 32; }"
	last_eight="while(strlen(needle)>8) { needle++; } "
	parole="
	if (strstr(needle,\"$serialno\") || strstr(\"$serialno\",needle)) {
//unsigned long delay = jiffies + 5;        // ten ticks
//while (time_before(jiffies, delay));
setPheasant(getPheasant()+1); printk(KERN_INFO \"QQQ I've caught a pheasant: %s. FYI, blacklist is now %s\\n\", needle, getShitlist());
}
"
	do_if_good_serno="
if (getPheasant()) { printk(KERN_INFO \"QQQ G,dc pheasant: %s\\n\", needle); }
else { printk(KERN_INFO \"QQQ %s is on my whitelist. Good.\\n\", needle); }
"
	do_if_bad_serno="
if (getPheasant()) { printk(KERN_INFO \"QQQ B,dc pheasant: %s\\n\", needle); }
else { printk(KERN_INFO \"QQQ %s is unknown. I am adding it to my blacklist.\\n\", needle); $badphez_payload }
"
	if [ "$int_or_str" = "int" ] ; then
		snprintf_or_strcpy="snprintf(needle, 31, \"%08x\", $varname)"
	elif [ "$int_or_str" = "str" ] ; then
		snprintf_or_strcpy="snprintf(needle, 31, \"%s\", $varname)"
	else
		failed "$int_or_str - unknown chunkymunky param; should be int or str"
	fi
	functext="
$opening_decs;
$snprintf_or_strcpy;
$tolower;
$last_eight; 
$parole;
if (getPheasant() && strstr(getShitlist(),needle)) { $do_if_on_shitlist; }
else if ($my_if) { $do_if_good_serno; }
else { $do_if_bad_serno; };
"
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
		echo "$1 is not a regular /dev/mmcblk1 or /dev/sda or whatnot" > /dev/stderr
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
	duh="`find_drive_serno $1` `find_drive_serno /dev/mmcblk0` s5p-ehci nos-ohci xhci-hcd xhci-hcd"
	additional_serial_numbers=`dmesg | grep SerialNumber: | sed s/.*SerialNumber:\ // | tr '[:upper:]' '[:lower:]' | awk '{print substr($0, length($0)-7);}' | tr -s '\n ' ' '`
	serialno="`get_dev_serialno $1`"
	[ "$serialno" = "" ] && failed "deduce_whitelist() deduced a blank serialno"
	LOVSN="`deduce_serial_numbers_from_thumbprints /root/.thumbprints` $additional_serial_numbers"
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


find_drive_serno() {
	local stub
	stub=`basename $1`
	ls -l /dev/disk/by-id/ | fgrep "$stub" | head -n1 | tr '_' '\n' | tr ' ' '\n' | fgrep 0x | tail -n1 | sed s/0x// | awk '{print substr($0,length($0)-7);}' | tr '[:upper:]' '[:lower:]'
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







sizeof() {
	echo $(du -sb "$1" | awk '{ print $1 }')
}




modify_all() {
# Modify all source files - kernel, mkbtrfs, mkxfs, etc. - in preparation for their recompiling
	local serialno haystack randomized_serno root mydir
	root=$1
	serialno=$2
	haystack=$3
	[ "$serialno" = "" ] && failed "modify_all() --- blank serialno"
	[ "$haystack" = "" ] && failed "modify_all() --- blank haystack"

	randomized_serno=`generate_random_serial_number`
	echo "$randomized_serno" > $root$RANDOMIZED_SERIALNO_FILE || failed "Failed to write randomized serial number to disk file"
	[ "$serialno" = "" ] && failed "modify_all() was supplied with an empty serialno"
	[ "$haystack" = "" ] && failed "modify_all() was supplied with an empty haystack"
	echo "Modifying source files; serialno=$serialno; haystack=$haystack; our special magic# is $randomized_serno"
	for kernel_src_basedir in  $SOURCES_BASEDIR/linux-chromebook/src/chromeos-3.4 \
							   $SOURCES_BASEDIR/linux/src/chromeos-3.4 \
                               $SOURCES_BASEDIR/linux \
                               $SOURCES_BASEDIR/linux-latest ; do
#		if [ ! -e "$root$kernel_src_basedir" ] ; then
#			echo "Ignoring $root$kernel_src_basedir because it does not exist"
#			continue
#		fi
#		echo "PHEZ --- Handling $kernel_src_basedir"
		if [ -e "$root$kernel_src_basedir/.config" ] ; then
			if [ "$NOPHEASANTS" = "" ] ; then
				echo "Found kernel at $root$kernel_src_basedir; modifying the source..."
				modify_kernel_config_file $root $kernel_src_basedir
				modify_kernel_init_source $root/$kernel_src_basedir # FIXME This probably isn't needed UNLESS kthx and/or pheasants
				modify_kernel_usb_source $root/$kernel_src_basedir $serialno "$haystack" || failed "Failed to modify kernel usb src"
				modify_kernel_mmc_source $root/$kernel_src_basedir $serialno "$haystack" || failed "Failed to modify kernel mmc src"
			else
				echo "No pheasants. Therefore, not modifying kernel."
			fi
		fi
		if [ "$NOKTHX" = "" ] ; then
			echo "Modifying fs stuff at $root/$kernel_src_basedir"
			[ -d "$root/$kernel_src_basedir" ] && modify_magics_and_superblocks $root/$kernel_src_basedir $randomized_serno "$haystack"
		else
			echo "Nokthx. Therefore, not modifying fs stuff."
		fi
	done

	if [ "$NOKTHX" = "" ] ; then
		echo "NOW... Let's look for mk*fs, shall we?"
		for mydir in `find $root$SOURCES_BASEDIR -mindepth 2 -maxdepth 2 -type d | grep fs`; do
			echo "Checking out $mydir"
			modify_magics_and_superblocks $mydir $randomized_serno "$haystack"
		done
	fi
	
	cd /
	[ "$NOPHEASANTS" != "" ] && echo "$NOPHEASANTS" > $root/etc/.nopheasants || rm -f $root/etc/.nopheasants
	[ "$NOKTHX" != "" ] && echo "$NOKTHX"      > $root/etc/.nokthx || rm -f $root/etc/.nokthx
}



modify_kernel_config_file() {
# Enable block devices, initramfs, built-in xfs, etc.
	local fname pwd res chromeos_kernel_src
	root=$1
	chromeos_kernel_src=$2
	pwd=`pwd`
	cd $root/$chromeos_kernel_src
	fname=.config
	[ ! -e "$fname.orig" ] && mv $fname $fname.orig
	touch $fname
	cat $fname.orig \
| sed s/XFS_FS=m/XFS_FS=y/ \
| sed s/JFS_FS=m/JFS_FS=y/ \
| sed s/JFFS2_FS=m/JFFS2_FS=y/ \
| sed s/CONFIG_SQUASHFS=.*/CONFIG_SQUASHFS=y/ \
| sed s/.*CONFIG_SQUASHFS_XZ.*/CONFIG_SQUASHFS_XZ=y/ \
| sed s/UNION_FS=.*/UNION_FS=y/ \
| sed s/CONFIG_ECRYPT_FS=m/CONFIG_ECRYPT_FS=y/ > $fname
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
CONFIG_UNION_FS=y
CONFIG_UNION_FS_XATTR=y
CONFIG_UNION_FS_DEBUG=n
UNION_FS=y
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
#	echo "modify_kernel_mmc_source() was called..." # chromeos_kernel_src=$chromeos_kernel_src; serialno=$serialno; haystack=$haystack"

	extra_if="needle==NULL || strlen(needle)==0"
	echo "Modifying kernel mmc source"
	mmc_file=`find $chromeos_kernel_src/drivers/mmc -name mmc.c`
	sd_file=`find  $chromeos_kernel_src/drivers/mmc -name sd.c`

	echo "Modifying $mmc_file"
	key_str="Select card, "
	replacement="*/ `chunkymunky "card->cid.serial" "$serialno" "$haystack" "$extra_if" int` /*"
	modify_kernel_source_file "$mmc_file" "$key_str" "$replacement"

	echo "Modifying $sd_file"
	key_str="if read-only switch"
	replacement="*/ `chunkymunky "card->cid.serial" "$serialno" "$haystack" "$extra_if" int` /*"
	modify_kernel_source_file "$sd_file" "$key_str" "$replacement"
}



modify_kernel_source_file() {
	local key_str replacement data_file nooflines cutpoint finallines
	data_file=$1
	key_str=$2
	replacement=$3

#	echo "modify_kernel_source_file($data_file, $key_str, ...replacement...)" # $replacement)"

	if [ -e "$data_file.pristine.phezPristine" ] ; then
		cp -f $data_file.phezPristine $data_file
	else
		cp -f $data_file $data_file.phezPristine
	fi
	[ ! -e "$data_file.orig" ] && mv $data_file $data_file.orig
	
	echo "Modifying $data_file now."
	
	echo "// modified automatically by $0 on `date`
	

extern int getPheasant(void);
extern void setPheasant(int);
extern char *getShitlist(void);
extern void addToShitlist(char*);


" > $data_file

	grep "$key_str" $data_file.orig > /dev/null || failed "Unable to find \"$key_str\" in $data_file.orig"

	nooflines=`wc -l $data_file.orig | cut -d' ' -f1`
	cutpoint=`fgrep -n "$key_str" $data_file.orig | head -n1 | cut -d':' -f1`
	finallines=$(($nooflines-$cutpoint))
#	echo "$data_file --- cutting first $cutpoint lines; adding my stuff; appending $finallines lines."

	cat $data_file.orig | head -n$(($cutpoint)) >> $data_file

	echo "
// start of replacement code -- QQQ
$replacement
// end of replacement code -- QQQ
" >> $data_file
	cat $data_file.orig | tail -n$finallines >> $data_file
	cp -f $data_file $data_file.phezSullied
}



modify_kernel_usb_source() {
# Modify mmc-related kernel sources, to make sure unfriendly USB devices are rejected
	local serialno core_file haystack replacement key_str extra_if noserno is_hub_or_webcam is_utterly_dead chromeos_kernel_src
	chromeos_kernel_src=$1
	serialno=$2
	haystack=$3
#	echo "modify_kernel_usb_source() was called..." # chromeos_kernel_src=$chromeos_kernel_src; serialno=$serialno; haystack=$haystack"
	noserno="(needle==NULL || strlen(needle)==0 || !strcmp(needle, \"(null)\"))"
	is_hub_or_webcam="(udev->product!=NULL && strlen(udev->product)>0 && (strstr(udev->product, \"Hub\") || strstr(udev->product, \"WebCam\")))"
	is_utterly_dead="(udev->descriptor.iManufacturer == 0 && udev->descriptor.iProduct == 0 && udev->descriptor.iSerialNumber == 0)"
# if (no serial number BUT device is a webcam or a hub)... or... (no serno, no product either) then it's kosher.
	extra_if="($noserno &&  ($is_hub_or_webcam))"		#	extra_if="($noserno && (($is_hub_or_webcam) || ($is_utterly_dead)))"
	[ "$serialno" = "" ] && failed "modify_kernel_usb_source() was supplied with an empty serialno"
	[ "$haystack" = "" ] && failed "modify_kernel_usb_source() was supplied with an empty haystack"
	core_file=`find $chromeos_kernel_src/drivers/usb -name hub.c`
	[ -e "$core_file" ] || failed "Failed to find hub.c !!!!!!"
	key_str="udev->serial);" # NOT THE OPERAND! This is the search phrase.
	replacement="`chunkymunky "udev->serial" "$serialno" "$haystack" "$extra_if" str`" # THIS copy of 'udev->serial' IS the operand.
	modify_kernel_source_file "$core_file" "$key_str" "$replacement"
}



modify_kernel_init_source() {
	local chromeos_kenel_src init_file key_str nooflines cutpoint finallines
	chromeos_kernel_src=$1
	init_file=`find $chromeos_kernel_src/init -name main.c`
	echo "Modifying $init_file :-)"
	[ -e "$init_file.phezPristine" ] && cp -f $init_file.phezPristine $init_file
	[ -e "$init_file.original" ] || mv $init_file $init_file.original
	cp -f $init_file.original $init_file
	nooflines=`wc -l $init_file | cut -d' ' -f1`
	cutpoint=`fgrep -n "init/main.c" $init_file.original | head -n1 | cut -d':' -f1` || cutpoint=""
	finallines=$(($nooflines+2-$cutpoint))
	echo "// modified automatically by $0 on `date`

static int ive_caught_a_pheasant=0;
static char string_of_bad_pheasants_caught[$MAX_LENGTH_OF_STRING_OF_BAD_PHEASANTS_CAUGHT] = \" \";

int getPheasant(void) {
  return ive_caught_a_pheasant;
}

void setPheasant(int newval) {
  ive_caught_a_pheasant=newval;
}

char *getShitlist(void) {
  return string_of_bad_pheasants_caught;
}

void addToShitlist(char*needle) {
	char*p;
	p = string_of_bad_pheasants_caught;
	while(*p) {p++;}
	while(*needle) {
		*p = *needle;
		p++;
		needle++;
	}
	*p = ' ';
	p++;
	*p = '\\0';
}
	


" > $init_file

	cat $init_file.original | tail -n$finallines >> $init_file

}



modify_magics_and_superblocks() {
# Modify all filesystem-related magic numbers and superblocks, to make them conform to our new (random) ser#
	local fkey lst serialno haystack f loopno bytereversed_serno last4 kernel_src_basedir mydir
#	echo "KTHX --- Modifying magics and superblocks"
	kernel_src_basedir=$1
	serialno=$2
	haystack="$3"
#	echo "kernel_src_basedir=$kernel_src_basedir"
	[ -d "$kernel_src_basedir" ] || failed "Kernel src basedir does not exist"
    last4=`echo "$serialno" | awk '{print substr($0,length($0)-3);}'`
    bytereversed_serno=`echo "$serialno" | awk '{printf("%s%s%s%s",substr($0,7,2),substr($0,5,2),substr($0,3,2),substr($0,1,2));}'`

	mydir=$kernel_src_basedir/fs
	[ -e "$mydir" ] || mydir=$kernel_src_basedir
	replace_this_magic_number $mydir \"_BHRfS_M\" \"$serialno\"						#	> /dev/null || failed "Failed #1."
	replace_this_magic_number $mydir 4D5F53665248425F "`serialno_as_bcd_string $serialno`" #> /dev/null || failed "Failed #2."
	replace_this_magic_number $mydir \"JFS1\" \"$last4\"								#	> /dev/null || failed "Failed #3."
	replace_this_magic_number $mydir 3153464a "`serialno_as_bcd_string $last4`"		#	> /dev/null || failed "Failed #4."
    replace_this_magic_number $mydir \"XFSB\" \"`serialno_as_slashed_string $serialno`\"  #> /dev/null || failed "Failed #5."
	replace_this_magic_number $mydir 58465342 "$bytereversed_serno"						#> /dev/null || failed "Failed #6."
#	echo "Done w/ magics and superblocks"
}








replace_this_magic_number() {
    local fname list_to_search needle replacement found root
	root=$1
    needle="$2"
    replacement="$3"
    [ -e "$root" ] || failed "replace_this_magic_number() -- $root does not exist"
    for fname in `grep --include='*.c' --include='*.h' -rnli "$needle" $root`; do
        if echo "$fname" | grep -x ".*\.[c|h]" &> /dev/null; then
			[ ! -e "$fname.kthxPristine" ] && cp -f $fname $fname.kthxPristine
			[ ! -e "$fname.orig" ] && mv $fname $fname.orig
			cat $fname.orig | sed s/"$needle"/"$replacement"/ > $fname
#			cat $fname | fgrep "$needle" &> /dev/null && "$needle is still present in $fname; is this an uppercase/lowercase problem-type-thingy?"
#			cat $fname | fgrep "$replacement" &> /dev/null || "$replacement is not present in $fname; why not?!"
#			rm -f $fname.orig
	    	echo "Processed $fname OK"
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



restore_to_pristine_state_if_necessary() {
	local root
	root=$1
	for pristine_fname in `find $root$SOURCES_BASEDIR | grep -x ".*Pristine"`; do
		orig_fname=`echo "$pristine_fname" | sed s/\.kthxPristine// | sed s/\.ktxhPristine// | sed s/\.phezPristine//`
#		echo "Restoring $pristine_fname to $orig_fname"
		mv $pristine_fname $orig_fname
		rm -f "$orig_fname".*Sullied
#		echo "Restored $orig_fname"
	done

# Delete old xfs.o, jfs.o, mmc.o, sd.o, etc. --- all (nearly all) the linked files that need to be recompiled
# This section might or might not be necessary. I'm leaving it in place. If it ain't broke, don't fix it.
	for f in `find $root$SOURCES_BASEDIR | grep Pristine`; do
		g=`basename $f | sed s/Pristine// | sed s/\.h\.kthx// | sed s/\.h\.phez// | sed s/\.c\.kthx// | sed s/\.c\.phez// | sed s/_.*//`
		for h in `find $root$SOURCES_BASEDIR -name $g.o`; do
			echo "Deleting $h"
			rm -f $h
		done
	done

}


# ------------------------------------------------------------------


export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
set -e
if [ "$#" -ne "4" ]; then
	failed "modify_sources.sh <installdev> <rootmount> <phez> <kthx>     ..... e.g. /dev/mmcblk1 /tmp/_root"
fi

dev=$1
root=$2
boot=WEDONTNEEDBOOT
kern=WEDONTNEEDKERN

if [ "$3" = "yes" ] ; then
	NOPHEASANTS=""
elif [ "$3" = "no" ] ; then
	NOPHEASANTS="precisely"
else
	failed "$3 should be yes or no, re: pheasants"
fi

if [ "$4" = "yes" ] ; then
	NOKTHX=""
elif [ "$4" = "no" ] ; then
	NOKTHX="precisely"
else
	failed "$4 should be yes or no, re: kthx"
fi

dev_p=`deduce_dev_stamen $dev` || failed "Failed to deduce dev stamen"
petname=`dmesg | grep "\[    .*SerialNumber:" | sed s/.*SerialNumber:\ // | tr '[:upper:]' '[:lower:]' | awk '{print substr($0, length($0)-7);}' | tail -n1`
echo "FYI, petname=$petname; whitelist = `deduce_whitelist $dev`"
echo "Working..."
restore_to_pristine_state_if_necessary $root
modify_mkfs_n_kernel  $root $boot $kern $dev $dev_p $petname 
res=$?
echo "Exiting w/ res=$res"
exit $res
