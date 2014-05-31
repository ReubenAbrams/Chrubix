# chr_archlinux.sh
# - install the filesystem (everything is already mounted)
# - i.e. untar alarm-rootfs.tar.xz ... and that's it
#
# To run (from within chrubix_stage1.sh), type:-
# # wget bit.do/archlinux -O - | sudo bash
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




# ------------------------------------------------------------------------------------------------------------------------


set -e
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin # Just in case phase 3 forgets to pass $PATH to the xterm call to me
root=`cat /tmp/.chrubix.root`
boot=`cat /tmp/.chrubix.boot`
kern=`cat /tmp/.chrubix.kern`
dev=`cat /tmp/.chrubix.dev`
dev_p=`cat /tmp/.chrubix.dev_p`

fsurl=`find /home/chronos -name alarm-root.tar.xz 2> /dev/null | head -n1`
[ "$fsurl" != "" ] && fscommand="cat $fsurl" || fscommand="wget bit.ly/1idXPUN -O -"		# alarm-rootfs.tar.xz
echo -en "Writing rootfs from `basename $fsurl` to "$dev"..."
$fscommand | tar -Jx -C $root || failed "Unable to extract/install roots from $fsurl to $dev; you might need to rerun create_archlinux_tarball.sh, a.k.a. bit.ly/1iBQSx9"

mount devtmpfs $root/dev -t devtmpfs|| failed "Failed to mount /dev"
mount sysfs $root/sys -t sysfs		|| failed "Failed to mount /sys"
mount proc $root/proc -t proc		|| failed "Failed to mount /proc"
mount tmpfs $root/tmp -t tmpfs		|| failed "Failed to mount /tmp"
exit 0
