#!/usr/local/bin/python3
#
# lxdm_post_login.py
# /etc/lxdm/PostLogin calls me :)

import sys
import os
import hashlib
from chrubix.utils import logme
from chrubix import generate_distro_record_from_name, save_distro_record, load_distro_record



if __name__ == "__main__":
    main_list = ( 
                'pulseaudio -k',  # 'start-pulseaudio-x11',
                'ps -o pid -C wmaker && wmsystemtray',
                'keepassx -min',
                'start-freenet.sh start',
                'touch /tmp/.okConnery.thisle.44',
                'xset s off',
                'xset -dpms',
                'florence & sleep 3; florence hide',
                'if ps wax | fgrep mate-session | fgrep -v grep ; then pulseaudio -k; mpg123 /etc/.mp3/winxp.mp3; fi',
                'dconf write /apps/florence/controller/floaticon false'
               )
    go_online_list = ( 
                      'ps wax | fgrep nm-applet | fgrep -v grep || nm-applet',
                      '''[ "`ps wax | grep nm-applet | grep -v grep | cut -d' ' -f1,2 | tr ' ' '\n' | grep "[0-9][0-9]" | wc -l`" -ge "2" ] \
&& kill `ps wax | grep nm-applet | grep -v grep | cut -d' ' -f1,2 | tr ' ' '\n' | grep "[0-9][0-9]" | tail -n1`''',
                      '''urxvt -geometry 120x20+0+320 -name "WiFi Setup" -e sh -c "/usr/local/bin/wifi_manual.sh" & \
the_pid=$!; while ! ping -c1 -W5 8.8.8.8; do sleep 1 ; done; kill $the_pid; systemctl start privoxy; sleep .5; /usr/bin/vidalia'''
                      )
    for cmd in ( main_list if os.path.exists( '/tmp/.do-not-automatically-connect' ) else main_list + go_online_list ):
        res = os.system( '( %s ) &' % ( cmd ) )
        os.system( 'sleep 0.1' )
        logme( 'Called >>> %s <<<; res=%d' % ( cmd, res ) )
    sys.exit( 0 )

