#!/usr/local/bin/python3
#
# lxdm_post_login.py
# /etc/lxdm/PostLogin calls me :)

import sys
import os
from chrubix.utils import logme
from chrubix import load_distro_record
import datetime


def pause_for_one_second():
    current_second = datetime.datetime.now().second
    while datetime.datetime.now().second == current_second:
        os.system( 'sleep 0.1' )


def execute_this_list( my_list ):
    for cmd in my_list:
        os.system( '( %s ) &' % ( cmd ) )
        os.system( 'sleep 0.25' )
#        os.system( 'adjust_brightness.sh up 10' )
#        logme( 'Called >>> %s <<<; res=%d' % ( cmd, res ) )


def initiate_nm_applet():
    if not am_i_online():  # and 0 != os.system( 'ps wax | fgrep nm-applet | grep -v grep' ):
        if 0 != os.system( 'cat /etc/os-release | grep -i wheezy' ):  # archlinux, jessie need sudo'd nm-applet
            if 0 != os.system( 'ps wax | fgrep nm-applet | grep -v grep' ):
                logme( 'lxdm_post_login.py --- killing and sudoing nm-applet' )
                os.system( 'killall nm-applet' )
                os.system( 'sleep .5' )
#                if 0 != os.system( 'ps wax | fgrep nm-applet | grep -v grep' ):
#                    logme( 'still not dead?!' )
#                    os.system( "kill -9 `ps wax | fgrep nm-applet | fgrep -v fgrep | tr -s '\t' ' ' | cut -d' ' -f2`" )
#                    os.system( 'sleep .5' )
                os.system( 'sleep 1' )
                if 0 != os.system( 'ps wax | fgrep nm-applet | grep -v grep' ):
                    logme( 'lxdm_post_login.y --- ok, restarting it now' )
                    logme( 'PSYCH!' )  #                    os.system( 'sudo nm-applet --nocheck &' )
                    logme( 'lxdm_post_login.y --- ...done' )
                else:
                    logme( 'lxdm_post_login.y --- wow, it restarted itself...' )
        else:
            if 0 != os.system( 'ps wax | fgrep nm-applet | grep -v grep' ):
                logme( 'lxdm_post_login.py --- starting nm-applet' )
                os.system( 'nm-applet --nocheck &' )


def configure_X_and_start_some_apps():
    logme( 'lxdm_post_login.py --- configuring X and starting some apps' )
    sound_vision_keyboard_list = ( # 'start-pulseaudio-x11',
                'pulseaudio -k; xset s off; xset -dpms',
                '\
xmodmap -e "keycode 72=XF86MonBrightnessDown"; \
xmodmap -e "keycode 73=XF86MonBrightnessUp"; \
xmodmap -e "keycode 74=XF86AudioMute"; \
xmodmap -e "keycode 75=XF86AudioLowerVolume"; \
xmodmap -e "keycode 76=XF86AudioRaiseVolume"; \
xmodmap -e "pointer = 1 2 3 5 4 7 6 8 9 10 11 12"',
                'check_ya_battery.sh',
                'adjust_volume.sh',
                'adjust_brightness.sh',
                     )
    applets_list = ( # & sleep 3; florence hide
                'ps -o pid -C wmaker && wmsystemtray',
                'florence',
                'gpgApplet',
                'keepassx -min',
                'xbindkeys',
                'sleep 3; if ps wax | fgrep mate-session | fgrep -v grep &>/dev/null ; then pulseaudio -k; mpg123 /etc/.mp3/winxp.mp3; fi',
                'dconf write /apps/florence/controller/floaticon false',
#                'ip2router start',
#                'su freenet -c “/opt/freenet/run.sh start"',  # /opt/freenet start',
               )
    execute_this_list( sound_vision_keyboard_list )
    execute_this_list( applets_list )
    initiate_nm_applet()



def am_i_connecting():
    if 0 == os.system( 'nmcli d | fgrep wifi | fgrep connecting' ):
        return True
    else:
        return False


def am_i_online():
    if 0 == os.system( 'nmcli d | fgrep wifi | fgrep connected | fgrep -v disconnected' ):
        return True
    else:
        return False


def wait_until_online( max_delay = 999999 ):
    logme( 'lxdm_post_login.py --- waiting until %d seconds pass OR we end up online' % ( max_delay ) )
    loops = max_delay
    while not am_i_online() and loops > 0:
        os.system( 'sleep 1' )
        loops -= 1
        logme( 'still not online...' )
    logme( 'i am online - yay' )


def wait_until_truly_online():
    while 0 != os.system( 'wget --spider https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/alarpy.tar.xz -O /dev/null 2> /dev/null ' ):
        os.system( 'sleep 3' )
        logme( 'still not truly online...' )
    logme( 'i am TRULY online - yay' )


def start_privoxy_freenet_i2p_and_tor():
    if 0 == os.system( 'sudo /usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh' ):
        logme( 'ran /usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh OK' )
    else:
        logme( '/usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh returned error(s)' )


def start_a_browser( force_real = False ):
    website = 'www.duckduckgo.com'
    binary = None
    my_distro = load_distro_record( '/' )
    if force_real or my_distro.lxdm_settings['internet directly']:
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
#    os.system( 'echo 0 > /sys/devices/*/*/*/*/brightness' )
    distro = load_distro_record( '/' )
    logme( 'lxdm_post_login.py --- calling configure_X_and_start_some_apps()' )
    configure_X_and_start_some_apps()
    logme( 'lxdm_post_login.py --- returning from configure_X_and_start_some_apps()' )
    if distro.lxdm_settings['internet directly']:
        wait_until_online()
        start_privoxy_freenet_i2p_and_tor()
        start_a_browser()
    else:
        wait_until_online()
        start_a_browser()
        wait_until_truly_online()
        start_a_browser( force_real = True )
        start_privoxy_freenet_i2p_and_tor()
    logme( 'lxdm_post_login.py --- ending' )
    sys.exit( 0 )
