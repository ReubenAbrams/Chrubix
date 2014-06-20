

#!/bin/bash
#
# ersatz_lxdm.sh
# - calls chrubix.sh w/ ersatz_lxdm as param #1
#
#################################################################################

touch /tmp/log.txt
chmod 777 /tmp/log.txt
chrubix.sh ersatz_lxdm $@
exit $?
