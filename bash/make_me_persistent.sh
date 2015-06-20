#!/bin/bash


DEV=/dev/mmcblk1
DEV_STUB=`basename $DEV`
PARTN_LOOP=/dev/loop6
SAUSAGE=/dev/mapper/hSg
SPLITPOINT=`cat /usr/local/bin/redo_mbr.sh | fgrep "SPLITPOINT=" | head -n1 | tr -s '=' ' ' | tr -s '\t' ' ' | cut -d' ' -f2`
echo "SPLITPOINT=$SPLITPOINT"

# vvv If you change these, change the redo_mbr.sh stuff too! vvv
START_OF_HIDDEN_DATA=$(($(($SPLITPOINT+128))*512))			# Try reducing 64 a little (32? 16?)
if which cgpt &> /dev/null ; then
	lastblock=`cgpt show $dev | tail -n3 | grep "Sec GPT table" | tr -s ' ' '\t' | cut -f2`
	eohd=$(($lastblock/2))
else
	eod_in_mb=`cat /proc/partitions | grep -x ".*$DEV_STUB" | tr -s ' ' '\t' | cut -f4`	# make_me_permanent.sh uses this
	eohd=$(($eod_in_mb*1024))
fi
END_OF_HIDDEN_DATA=$(($(($eohd/262144))*262144))
LENGTH_OF_HIDDEN_DATA=$(($END_OF_HIDDEN_DATA-$START_OF_HIDDEN_DATA))
GROOVY_CRYPT_PARAMS="-c aes-xts-plain -s 512 -c aes -s 256 -h sha256" 		# --hash ripemd160
# ^^^ If you change these, change the redo_mbr.sh stuff too! ^^^


echo "START_OF_HIDDEN_DATA=$START_OF_HIDDEN_DATA"
echo "LENGTH_OF_HIDDEN_DATA=$LENGTH_OF_HIDDEN_DATA"


failed() {
	echo "$1" >> /dev/stderr
	exit 1
}



setup_loop() {
	echo "Looping it"
	for a in 1 2 ; do
		cryptsetup close `basename $SAUSAGE` &> /dev/null || echo -en ""
		umount $PARTN_LOOP 2> /dev/null || echo -en ""
		losetup -d $PARTN_LOOP 2> /dev/null || echo -en ""
	done
	
	losetup $PARTN_LOOP $DEV -o $START_OF_HIDDEN_DATA --sizelimit $LENGTH_OF_HIDDEN_DATA
	losetup -a | grep $PARTN_LOOP
}




create_encrypted_partition() {
	res=999
	while [ "$res" -ne "0" ] ; do
		cryptsetup -v create `basename $SAUSAGE` $PARTN_LOOP -y $GROOVY_CRYPT_PARAMS 
		res=$?
	done
}


format_encrypted_partition() {
	echo -en "Formatting (this will take a while)..."
#	mkfs.xfs -f $SAUSAGE			&>/dev/null	|| failed "Err W -- failed to prep your hidden partition"
	mkfs.jfs -f $SAUSAGE			&>/dev/null || failed "Err W -- failed to prep your hidden partition"
#	yes Y | mkfs.ext4 $SAUSAGE		&>/dev/null	|| failed "Err W -- failed to prep your hidden partition"
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
			echo "I experienced a non-fatal error."
		fi
	fi
	echo -en "\nPress ENTER to reboot."
	read line
	sync;sync;sync
	sudo reboot
	exit 0
}


reopen_encrypted_partition() {
res=999
while [ "$res" -ne "0" ] ; do
	echo -en "Re-enter your password (3rd time), please:"
	read -s pw
	echo ""
	echo "$pw" | cryptsetup plainOpen $PARTN_LOOP `basename $SAUSAGE` $GROOVY_CRYPT_PARAMS 
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
