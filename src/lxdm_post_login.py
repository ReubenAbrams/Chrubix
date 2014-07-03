#!/usr/local/bin/python3
#
# lxdm_post_login.py
# /etc/lxdm/PostLogin calls me :)

import sys
import os
import hashlib
from chrubix.utils import logme
from chrubix import generate_distro_record_from_name, save_distro_record, load_distro_record
import datetime


def pause_for_one_second():
    current_second = datetime.datetime.now().second
    while datetime.datetime.now().second == current_second:
        os.system( 'sleep 0.2' )


def execute_this_list( my_list ):
    for cmd in my_list:
        res = os.system( '( %s ) &' % ( cmd ) )
        os.system( 'sleep 0.25' )
        logme( 'Called >>> %s <<<; res=%d' % ( cmd, res ) )



def configure_X_and_start_some_apps():
    logme( 'lxdm_post_login.py --- configuring X and starting some apps' )
    main_list = ( 
                'pulseaudio -k',  # 'start-pulseaudio-x11',
                'ps -o pid -C wmaker && wmsystemtray',
                'keepassx -min',
                'touch /tmp/.okConnery.thisle.44',
                'xset s off',
                'xset -dpms',
                'florence',  # & sleep 3; florence hide
                'gpgApplet',
                'dconf write /apps/florence/controller/floaticon false',
                'if ps wax | fgrep mate-session | fgrep -v grep ; then pulseaudio -k; mpg123 /etc/.mp3/winxp.mp3; fi',
               )
    logme( 'lxdm_post_login.py --- fixing /tmp/.guest and /home/* permissions' )
    execute_this_list( main_list )
    logme( 'lxdm_post_login.py --- proceeding' )


def am_i_online():
    if 0 == os.system( 'ping -c1 -W5 8.8.8.8 2> /dev/null' ):
        return True
    else:
        return False


def wait_until_online( max_delay = 999 ):
    logme( 'lxdm_post_login.py --- waiting until %d seconds pass OR we end up online' % ( max_delay ) )
    loops = max_delay
    while not am_i_online and loops > 0:
        pause_for_one_second()
        loops -= 1
    logme( 'lxdm_post_login.py --- continuing' )


# ---------------------------------------------------------------------------------------------------------------------


if __name__ == "__main__":
    logme( 'lxdm_post_login.py --- starting' )
    configure_X_and_start_some_apps()
    if os.path.exists( '/tmp/.do-not-automatically-connect' ):
        logme( 'lxdm_post_login.py --- ending' )
        sys.exit( 0 )
    wait_until_online( max_delay = 8 )  # Return to me if either 8 seconds pass or we go online.
    if not am_i_online():
        logme( 'lxdm_post_login.py --- running nm-applet' )
        os.system( 'killall nm-applet' )
        os.system( 'sudo nm-applet --nocheck &' )
    logme( 'lxdm_post_login.py --- urxvt => terminal in bkgd' )
    os.system( '''(urxvt -geometry 120x20+0+320 -name "WiFi Setup" -e bash -c "/usr/local/bin/wifi_manual.sh" & the_pid=$!; while ! ping -c1 -W5 8.8.8.8; do sleep 1 ; done; kill $the_pid ) & ''' )
    wait_until_online()
    if 0 == os.system( 'sudo /usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh' ):
        logme( 'ran /usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh OK' )
    else:
        logme( '/usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh returned error(s)' )
    distro = load_distro_record()
    if distro.name == 'debian':
        logme( 'Debian does not like Vidalia. Fair enough.' )
    else:
        logme( 'starting vidalia' )
        os.system( 'vidalia &' )
    logme( 'lxdm_post_login.py --- ending' )
    sys.exit( 0 )
