#!/bin/sh

cd ~/Documents/Software/Git/Chrubix
loop=1
while [ "black" != "white" ] ; do
	f_list=`find . -type f -maxdepth 4 -cmin -1 -cmin +0`
	if [ "$f_list" != "" ] ; then
		echo "`date` --- Copying chrubix_stage1.sh to Dropbox"
		cp bash/chrubix_stage1.sh ~/Dropbox/Public/chrubix/
		echo "`date` Updating chrubix tarball"
		tar -cJ {src,bash} >  ~/Dropbox/Public/chrubix/_chrubix.tar.xz
		# We skip blobs. If I want to update blobs, I'll have to do it via GitHub.
		sleep 10
	fi
	sleep 1
done

