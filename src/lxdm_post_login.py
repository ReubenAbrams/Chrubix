#!/usr/local/bin/python3
#
# lxdm_post_login.py
# /etc/lxdm/PostLogin calls me :)

import sys
import os
import hashlib
from chrubix.utils import logme, write_oneliner_file
from chrubix import generate_distro_record_from_name, save_distro_record, load_distro_record, read_oneliner_file
import datetime


def pause_for_one_second():
    current_second = datetime.datetime.now().second
    while datetime.datetime.now().second == current_second:
        os.system( 'sleep 0.2' )


def execute_this_list( my_list ):
    for cmd in my_list:
        res = os.system( '( %s ) &' % ( cmd ) )
        os.system( 'sleep 0.2' )
        logme( 'Called >>> %s <<<; res=%d' % ( cmd, res ) )


def configure_X_and_start_some_apps():
    logme( 'lxdm_post_login.py --- configuring X and starting some apps' )
    main_list = ( 
                'pulseaudio -k',  # 'start-pulseaudio-x11',
                'florence',  # & sleep 3; florence hide
                'xset s off',
                'xset -dpms',
                'ps -o pid -C wmaker && wmsystemtray',
                'if ps wax | fgrep mate-session | fgrep -v grep &>/dev/null ; then pulseaudio -k; mpg123 /etc/.mp3/winxp.mp3; fi',
                'xmodmap -e "keycode 72=XF86MonBrightnessDown"',
                'xmodmap -e "keycode 73=XF86MonBrightnessUp"',
                'xmodmap -e "keycode 74=XF86AudioMute"',
                'xmodmap -e "keycode 75=XF86AudioLowerVolume"',
                'xmodmap -e "keycode 76=XF86AudioRaiseVolume"',
                'xmodmap -e "pointer = 1 2 3 5 4 7 6 8 9 10 11 12"',
                'gpgApplet',
                'keepassx -min',
                'dconf write /apps/florence/controller/floaticon false',
                'xbindkeys',
#                'ip2router start',
#                'su freenet -c “/opt/freenet/run.sh start"',  # /opt/freenet start',
               )
    logme( 'lxdm_post_login.py --- fixing various permissions' )
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
    while not am_i_online() and loops > 0:
        pause_for_one_second()
        loops -= 1
        logme( 'still not online...' )
    logme( 'lxdm_post_login.py --- continuing' )


def initiate_nm_applet():
    os.system( 'sleep 2' )
    if not am_i_online():  # and 0 != os.system( 'ps wax | fgrep nm-applet | grep -v grep' ):
        if 0 != os.system( 'cat /etc/os-release | grep -i wheezy' ):  # archlinux, jessie need sudo'd nm-applet
            logme( 'lxdm_post_login.py --- killing and sudoing nm-applet' )
            os.system( 'killall nm-applet' )
            os.system( 'sudo nm-applet --nocheck &' )
        elif 0 != os.system( 'ps wax | fgrep nm-applet | grep -v grep' ):
            logme( 'lxdm_post_login.py --- running nm-applet' )
            os.system( 'nm-applet --nocheck &' )


def start_privoxy_freenet_i2p_and_tor():
    if 0 == os.system( 'sudo /usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh' ):
        logme( 'ran /usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh OK' )
    else:
        logme( '/usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh returned error(s)' )


def start_a_browser():
    website = 'www.duckduckgo.com'
    binary = None
    distro = load_distro_record( '/' )
    if distro.lxdm_settings['internet directly']:
        if 0 == os.system( 'which iceweasel &> /dev/null' ):
            binary = 'iceweasel'
        else:
            binary = 'chromium'
    else:
        logme( 'Running dillo to help user access the Net via Starbucks or whatever' )
        binary = 'dillo'
    cmd = '%s %s &' % ( binary, website )
    logme( 'start_a_browser() --- calling %s' % ( cmd ) )
    res = os.system( cmd )
    logme( '...result=%d' % ( res ) )


# ---------------------------------------------------------------------------------------------------------------------


if __name__ == "__main__":
    logme( 'lxdm_post_login.py --- starting' )
    configure_X_and_start_some_apps()
    initiate_nm_applet()
    wait_until_online()
    start_privoxy_freenet_i2p_and_tor()
    start_a_browser()
    logme( 'lxdm_post_login.py --- ending' )
    sys.exit( 0 )
