#!/usr/local/bin/python3
#
# lxdm_post_login.py
# /etc/lxdm/PostLogin calls me :)

import sys
import os
import hashlib
from chrubix.utils import logme
from chrubix import generate_distro_record_from_name, save_distro_record, load_distro_record


def execute_this_list( my_list ):
    for cmd in my_list:
        res = os.system( '( %s ) &' % ( cmd ) )
        os.system( 'sleep 0.1' )
        logme( 'Called >>> %s <<<; res=%d' % ( cmd, res ) )




# ---------------------------------------------------------------------------------------------------------------------


if __name__ == "__main__":
    logme( 'lxdm_post_login.py --- starting' )
    logme( 'lxdm_post_login.py --- fixing /tmp/.guest and /home/* permissions' )
    os.system( 'chmod 777 /tmp/.guest /home/*' )  # FIXME: We shouldn't have to use chmod to work around lxdm's Debian-specific eccentricities


    main_list = ( 
                'pulseaudio -k',  # 'start-pulseaudio-x11',
                'ps -o pid -C wmaker && wmsystemtray',
                'keepassx -min',
                'start-freenet.sh start',
                'touch /tmp/.okConnery.thisle.44',
                'xset s off',
                'xset -dpms',
                'dconf write /apps/florence/controller/floaticon false'
                'florence &',  # & sleep 3; florence hide
                'gpgApplet &',
                'if ps wax | fgrep mate-session | fgrep -v grep ; then pulseaudio -k; mpg123 /etc/.mp3/winxp.mp3; fi',
               )
    go_online_list = ( 
                      'sudo /usr/bin/nm-applet & sleep 1',
                      'ps wax | fgrep nm-applet | fgrep -v grep || nm-applet',
                      '''[ "`ps wax | grep nm-applet | grep -v grep | cut -d' ' -f1,2 | tr ' ' '\n' | grep "[0-9][0-9]" | wc -l`" -ge "2" ] \
&& kill `ps wax | grep nm-applet | grep -v grep | cut -d' ' -f1,2 | tr ' ' '\n' | grep "[0-9][0-9]" | tail -n1`''',
                      '''urxvt -geometry 120x20+0+320 -name "WiFi Setup" -e sh -c "/usr/local/bin/wifi_manual.sh" & \
the_pid=$!; while ! ping -c1 -W5 8.8.8.8; do sleep 1 ; done; kill $the_pid'''
                      )
    start_privoxy_and_vidalia_list = ( 
                                      '''systemctl start privoxy''',
                                      '''vidalia'''
                                      )
    execute_this_list( main_list )
    logme( 'lxdm_post_login.py --- midpoint' )
    if not os.path.exists( '/tmp/.do-not-automatically-connect' ):
        loops = 8
        while 0 != os.system( 'ping -c1 -W5 8.8.8.8 &> /dev/null' ) and loops > 0:
            os.system( 'sleep 1' )
            loops -= 1
        if loops <= 0:
            execute_this_list( go_online_list )
            while 0 != os.system( 'ping -c1 -W5 8.8.8.8 &> /dev/null' ):
                os.system( 'sleep 1' )
        logme( 'lxdm_post_login.py --- calling privoxy and vidalia' )
        execute_this_list( start_privoxy_and_vidalia_list )
    logme( 'lxdm_post_login.py --- ending' )
    sys.exit( 0 )

