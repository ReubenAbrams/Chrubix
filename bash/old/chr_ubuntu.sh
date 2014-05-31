# chr_ubuntu.sh
# - untar ubuntu.tar.xz ... and that's it
# - install the filesystem (everything is already mounted)
#
# To run (from within chrubix_stage1.sh), type:-
# # wget bit.do/ubu -O - | sudo bash
#
##########################################################################





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
	chroot $1 $tmpfile && res=0 || res=1
	rm -f $1/$tmpfile
	return $res
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
chmod +x main.py
[ ! -e \"/usr/local/bin/python3\" ] && ln -sf \`which python3\` /usr/local/bin/python3
./main.py \$@
exit \$?
" > $root/usr/local/bin/chrubix.sh
}



# ------------------------------------------------------------------------------------------------------------------------

# This is the UBUNTU-SPECIFIC installer.
set -e
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin # Just in case phase 3 forgets to pass $PATH to the xterm call to me
root=`cat /tmp/.chrubix.root`
boot=`cat /tmp/.chrubix.boot`
kern=`cat /tmp/.chrubix.kern`
dev=`cat /tmp/.chrubix.dev`
dev_p=`cat /tmp/.chrubix.dev_p`

if ! mount | fgrep "$kern/dev" >/dev/null ; then
	# Yes, I'm installing ArchLinux on $kern, even though my goal is to install Ubuntu. You'll see...
	fsurl=`find /home/chronos -name alarm-root.tar.xz 2> /dev/null | head -n1`
	[ "$fsurl" != "" ] && fscommand="cat $fsurl" || fscommand="wget bit.ly/1idXPUN -O -"		# alarm-rootfs.tar.xz
	echo -en "Writing rootfs from `basename $fsurl` to "$dev"..."
	$fscommand | tar -Jx -C $kern || failed "Unable to extract/install roots from $fsurl to $dev; you might need to rerun create_ubuntu_tarball.sh, a.k.a. bit.ly/1lBwN9E"
	# Yes, I'm mounting an ArchLinux distro in $kern.
	mount devtmpfs	$kern/dev	-t devtmpfs	|| failed "Failed to mount /dev"
	mount sysfs		$kern/sys	-t sysfs	|| failed "Failed to mount /sys"
	mount proc		$kern/proc	-t proc		|| failed "Failed to mount /proc"
	mount tmpfs		$kern/tmp	-t tmpfs	|| failed "Failed to mount /tmp"
else
	echo "Bypassing the downloading and mounting of alarm-root, for it has happened already."
	echo "My guess is, chrubix.sh failed and you're debugging it. Cool. Running it again..."
fi

install_chrubix $kern			# Installing CHRUBIX into $kern.
chroot_this $kern "/usr/local/bin/chrubix.sh -Koff -Poff -Dubuntu" || failed "Failed to run chrubix.sh inside the chroot in $kern"
# Ah ha! I'm using CHRUBIX to install Ubuntu Linux.

sync; umount $kern/{tmp,proc,sys,dev} || echo -en ""
sync; umount $kern/{tmp,proc,sys,dev} || echo -en ""

mount devtmpfs $root/dev -t devtmpfs|| failed "Failed to mount /dev"
mount sysfs $root/sys -t sysfs		|| failed "Failed to mount /sys"
mount proc $root/proc -t proc		|| failed "Failed to mount /proc"
mount tmpfs $root/tmp -t tmpfs		|| failed "Failed to mount /tmp"

exit 0


