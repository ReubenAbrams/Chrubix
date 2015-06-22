#!/bin/bash


DEV=/dev/mmcblk1
DEV_P="$DEV"p
DEV_STUB=`basename $DEV`
DEV_P3="$DEV_P"3
SAUSAGE=/dev/mapper/hSg

# vvv If you change these, change the redo_mbr.sh stuff too! vvv
GROOVY_CRYPT_PARAMS="-c aes-xts-plain -s 512 -c aes -s 256 -h sha256" 		# --hash ripemd160
# ^^^ If you change these, change the redo_mbr.sh stuff too! ^^^





failed() {
	echo "$1" >> /dev/stderr
	exit 1
}



setup_loop() {
	for a in 1 2 ; do
		cryptsetup close `basename $SAUSAGE` &> /dev/null || echo -en ""
		umount $DEV_P3 2> /dev/null || echo -en ""
		sync;sync;sync
	done
}




create_encrypted_partition() {
	res=999
	while [ "$res" -ne "0" ] ; do
		cryptsetup -v create `basename $SAUSAGE` $DEV_P3 -y $GROOVY_CRYPT_PARAMS 
		res=$?
	done
}


format_encrypted_partition() {
	echo -en "Formatting (this will take a while)..."
#	mkfs.xfs -f $SAUSAGE			&>/dev/null	|| failed "Err W -- failed to prep your hidden partition"
#	mkfs.jfs -f $SAUSAGE			&>/dev/null || failed "Err W -- failed to prep your hidden partition"
	yes Y | mkfs.ext4 $SAUSAGE					|| failed "Err W -- failed to prep your hidden partition"
#	mkfs.btrfs -f -O ^extref $SAUSAGE	&>/dev/null	|| failed "Err W -- failed to prep your hidden partition"
	mkdir -p /tmp/.hs.
	mount $SAUSAGE /tmp/.hs. 				|| failed "Err X -- failed to prep your hidden partition"
	echo "`date` --- hi there. Crocket was tubby." > /tmp/.hs./.hi.txt
	echo -en "Unmounting..."
	sync;sync;sync
	umount /tmp/.hs. &> /dev/null
	while [ "$?" -ne "0" ] ; do
		sleep 1
		echo -en "."
		sync;sync;sync
		umount /tmp/.hs. &> /dev/null
	done
	echo "Done."
}


close_encrypted_partition() {
	echo -en "Closing encrypted partition"
	sync;sync;sync
	if ! cryptsetup close $SAUSAGE 2> /dev/null ; then
		sync;sync;sync
		echo -en "...Retrying..."
		if ! cryptsetup close $SAUSAGE 2> /dev/null ; then
			echo "I experienced a non-fatal error, but it's OK."
			echo -en "\nPress ENTER to reboot."
			read line
			sync;sync;sync
			sudo reboot
			exit 0
		fi
	fi
}


reopen_encrypted_partition() {
res=999
while [ "$res" -ne "0" ] ; do
	echo -en "Re-enter your password (3rd time), please:"
	read -s pw
	echo ""
	echo "$pw" | cryptsetup plainOpen $DEV_P3 `basename $SAUSAGE` $GROOVY_CRYPT_PARAMS 
	res=$?
done
}


verify_encrypted_partition() {
	mkdir -p /tmp/.hs.
	mount $SAUSAGE /tmp/.hs. 			|| failed "Err Y -- failed to prep your hidden partition"
	original_message=`cat /tmp/.hs./.hi.txt` || failed "Err Z -- failed to prep your hidden partition"
	echo "Hurray! Original message = $original_message"
	umount /tmp/.hs. &> /dev/null
}



########################################################################################


echo "Thinking..."

setup_loop
create_encrypted_partition
format_encrypted_partition
close_encrypted_partition
reopen_encrypted_partition
verify_encrypted_partition
close_encrypted_partition

echo -en "Done! Now, press ENTER to reboot."
read -s line
echo ""
sync;sync;sync
sudo reboot
exit 0
