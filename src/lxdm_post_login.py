#!/usr/local/bin/python3
#
# lxdm_post_login.py
# /etc/lxdm/PostLogin calls me :)

import sys
import os
import hashlib
from chrubix.utils import logme, write_oneliner_file, system_or_die
from chrubix import generate_distro_record_from_name, save_distro_record, load_distro_record, read_oneliner_file
import datetime


def pause_for_one_second():
    current_second = datetime.datetime.now().second
    while datetime.datetime.now().second == current_second:
        os.system( 'sleep 0.2' )


def execute_this_list( my_list ):
    for cmd in my_list:
        res = os.system( '( %s ) &' % ( cmd ) )
        os.system( 'sleep 0.1' )
        logme( 'Called >>> %s <<<; res=%d' % ( cmd, res ) )


def configure_X_and_start_some_apps():
    logme( 'lxdm_post_login.py --- configuring X and starting some apps' )
    main_list = ( 
                'adjust_volume.sh',
                'adjust_brightness.sh',
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
                'check_ya_battery.sh',
                'keepassx -min',
                'dconf write /apps/florence/controller/floaticon false',
                'xbindkeys',
                'xinput set-prop "Cypress APA Trackpad (cyapa)" "Synaptics Finger" 15 20 256; xinput set-prop "Cypress APA Trackpad (cyapa)" "Synaptics Two-Finger Scrolling" 1 1',
#                'ip2router start',
#                'su freenet -c "/opt/freenet/run.sh start"',  # /opt/freenet start',
               )
    logme( 'lxdm_post_login.py --- fixing various permissions' )
    execute_this_list( main_list )
    logme( 'lxdm_post_login.py --- proceeding' )


def am_i_online():
    if 0 == os.system( 'ping -c1 -W5 8.8.8.8 2> /dev/null' ):
        return True
    else:
        return False


def wait_until_online( max_delay = 999999 ):
    logme( 'lxdm_post_login.py --- waiting until %d seconds pass OR we end up online' % ( max_delay ) )
    loops = max_delay
    while not am_i_online() and loops > 0:
        pause_for_one_second()
        loops -= 1
        logme( 'still not online...' )
    logme( 'lxdm_post_login.py --- continuing' )


def initiate_nm_applet():
        system_or_die( '''
sleep 5
echo QQQAAA >> /tmp/chrubix.log
if ! ping -c1 -W5 8.8.8.8 &> /dev/null; then
  echo QQQBBB >> /tmp/chrubix.log
  if cat /etc/os-release | grep -i wheezy ; then
    echo QQQCCC >> /tmp/chrubix.log
    nm-applet --nocheck &
  else
    echo QQQDDD >> /tmp/chrubix.log
    killall nm-applet &> /dev/null || echo -en ""
    killall nm-applet &> /dev/null || echo -en ""
    killall nm-applet &> /dev/null || echo -en ""
    sleep 1
    echo QQQEEE >> /tmp/chrubix.log
    sudo nm-applet --nocheck &
  fi
fi
echo QQQZZZ >> /tmp/chrubix.log
        ''' )

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
    initiate_nm_applet()
    configure_X_and_start_some_apps()
    wait_until_online()
    start_privoxy_freenet_i2p_and_tor()
    start_a_browser()
    logme( 'lxdm_post_login.py --- ending' )
    sys.exit( 0 )
