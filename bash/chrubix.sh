#!/bin/bash
#
# chrubix.sh
# - cd to python src folder
# - call main.py
#
#################################################################################

if [ "$USER" != "root" ] ; then
 	echo "Please type sudo in front of the call to run me."
 	exit 1
fi

wget https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz -O - | tar -Jx -C /usr/local/bin/Chrubix || echo "Sorry. Dropbox is down. We'll have to rely on GitHub..."
export DISPLAY=:0.0
cd /usr/local/bin/Chrubix/src

if [ "$1" = "tinker" ] ; then
	python3 tinker.py $@
elif [ "$1" = "greeter" ] ; then
	echo "exec python3 greeter.py" > /usr/local/bin/greeter.rc
	startx /usr/local/bin/greeter.rc
else
	python3 main.py -Kon -Pon -d$dev -r$rootdev -s$sparedev -k$kerndev -D$distroname
fi
exit $?