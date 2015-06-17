#!/bin/bash


failed() {
	echo "$1" >> /dev/stderr
	exit 1
}



########################################################################################



DEV=/dev/mmcblk1
PARTN_DEV="$DEV"p3
PARTN_LOOP=/dev/loop6
SAUSAGE=/dev/mapper/hiddensausage

losetup -d $PARTN_LOOP 2> /dev/null || echo -en ""
losetup $PARTN_LOOP -o 16384 $PARTN_DEV

res=999
while [ "$res" -ne "0" ] ; do
	cryptsetup -v luksFormat $PARTN_LOOP -c aes-xts-plain -y -s 512 -c aes -s 256 -h sha256
	res=$?
done

res=999
while [ "$res" -ne "0" ] ; do
	echo -en "Re-enter your password (3rd time), please:"
	read -s pw
	echo ""
	echo "$pw" | cryptsetup luksOpen $PARTN_LOOP `basename $SAUSAGE`
	res=$?
done

yes Y | mkfs.ext4 $SAUSAGE			|| failed "Err W -- failed to prep your hidden partition"
#mkfs.btrfs -f -O ^extref $SAUSAGE
mkdir -p /tmp/.hs.
mount $SAUSAGE /tmp/.hs. 			|| failed "Err X -- failed to prep your hidden partition"
echo "`date` --- hi there. Your sausage has been hidden." > /tmp/.hs./.hi.txt
umount /tmp/.hs. &> /dev/null

echo -en "Done! Now, press ENTER to reboot."
read -s line
echo ""
sync;sync;sync
sudo reboot
sleep 5
exit 0


