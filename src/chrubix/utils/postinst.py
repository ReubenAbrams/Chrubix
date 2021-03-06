#!/usr/local/bin/python3
#
# postinst.py


'''
Created on May 9, 2014
'''


import os
from chrubix.utils import write_oneliner_file, failed, system_or_die, logme, do_a_sed, \
                          chroot_this, read_oneliner_file

GUEST_HOMEDIR = '/home/guest'
LXDM_CONF = '/etc/lxdm/lxdm.conf'

def append_startx_addendum( outfile ):
    f = open( outfile, 'a' )
    f.write( '''
export DISPLAY=:0.0
localectl set-locale en_US.utf8
localectl set-keymap us
setxkbmap us
localectl set-x11-keymap us
xset -b        # dpms, no audio bell; see https://www.notabilisfactum.com/blog/?page_id=7
xset m 30/10 3
xinput set-prop "Cypress APA Trackpad (cyapa)" "Synaptics Finger" 15 20 256; xinput set-prop "Cypress APA Trackpad (cyapa)" "Synaptics Two-Finger Scrolling" 1 1
syndaemon -t -k -i 1 -d # disable mousepad for 1s after typing finishes

# TODO Why don't we put xmodmap stuff (bightness, volume) in here instead? At present, it's in post_lxdm thingumabob
''' )
    f.close()


def write_lxdm_post_login_file( outfile ):
    f = open( outfile, 'w' )
    f.write( '''#!/bin/bash
#. /etc/bash.bashrc
#. /etc/profile
liu=/tmp/.logged_in_user
echo "$USER" > $liu

#bh=`find /sys/devices -name brightness | head -n1`
#echo 100 > $bh

export DISPLAY=:0.0
echo waitingForX >> /tmp/chrubix.log
while ! ps wax | fgrep "/X " | fgrep -v grep ; do
    sleep 0.2
done
sleep 1
echo yayXisRunning >> /tmp/chrubix.log
python3 /usr/local/bin/Chrubix/src/lxdm_post_login.py || echo 300 > /sys/devices/platform/*/*/*/*/brightness
''' )
    f.close()


def write_lxdm_post_logout_file( outfile ):
    f = open( outfile, 'w' )
    f.write( '''#!/bin/bash

#. /etc/bash.bashrc
#. /etc/profile
liu=/tmp/.logged_in_user
rm -f $liu
export DISPLAY=:0.0
if [ -e "/tmp/.yes_greeter_is_running" ] ; then
    killall lxdm-binary lxdm X
fi

#/usr/bin/loginctl terminate-session $XDG_SESSION_ID
#/usr/bin/systemctl restart lxdm.service
''' )
    f.close()


def write_lxdm_pre_login_file( mountpoint, outfile ):
    f = open( outfile, 'w' )
    f.write( '''#!/bin/bash
#. /etc/bash.bashrc
#. /etc/profile
[ -e "%s.old" ] && rm %s.old
[ -e "%s" ] && mv %s %s.old
ln -sf / %s
bh=`find /sys/devices -name brightness | head -n1`
me=`dirname $bh`
chmod -R 777 $me        # fix brightness setter
#echo 0 > $bh
''' % ( mountpoint, mountpoint, mountpoint, mountpoint, mountpoint, mountpoint ) )
    f.close()


def append_lxdm_xresources_addendum( outfile, webbrowser ):
    f = open( outfile, 'a' )
    f.write( '''
# ------- vvv XRESOURCES vvv ------- Make sure rxvf etc. will use chromium to open a web browser if user clicks on http:// link
    echo "
UXTerm*VT100*translations: #override Shift <Btn1Up>: exec-formatted("%s '%%t'", PRIMARY)
UXTerm*charClass: 33:48,36-47:48,58-59:48,61:48,63-64:48,95:48,126:48
URxvt.perl-ext-common: default,matcher
URxvt.url-launcher: /usr/local/bin/%s
URxvt.matcher.button: 1
''' % ( webbrowser, webbrowser ) )
    f.close()


def generate_wifi_manual_script( outfile ):
    write_oneliner_file( outfile, '''#/bin/bash


GetAvailableNetworks() {
    nmcli --nocheck dev wifi list | grep -v "SSID.*BSSID" | sed s/'    '/^/ | cut -d'^' -f1 | awk '{printf ", " substr($0,2,length($0)-2);}' | sed s/', '//
}


lockfile=/tmp/.go_online_manual.lck
manual_mode() {
logger "wifi-manual --- starting"
res=999
#clear
echo "This terminal window is here in case the NetworkManager applet malfunctions."
echo "Please try to use the applet to connect to the Internet. If if fails, use me."
while [ "$res" -ne "0" ] ; do
    echo -en "Searching..."
    all=""
    loops=0
    while [ "`echo "$all" | wc -c`" -lt "4" ] && [ "$loops" -le "8" ] ; do
        all=`GetAvailableNetworks 2> /dev/null`
        sleep 0.5
        echo -en "."
        loops=$(($loops+1))
    done
    if [ "`echo "$all" | wc -c`" -lt "4" ] ; then
        echo ""
        echo "-----------------------------------------------------------"
        echo "Use the NetworkManager applet to connect to the Internet."
        echo "Press ENTER to close this window."
        read line
        exit 0
    fi
    echo "\n\nAvailable networks: $all" | wrap -w 79
    echo ""
    echo -en "WiFi ID: "
    read id
    [ "$id" = "" ] && return 1
    echo -en "WiFi PW: "
    read pw
    echo -en "Working..."
    nmcli --nocheck dev wifi connect "$id" password "$pw" && res=0 || res=1
    [ "$res" -ne "0" ] && echo "Bad ID and/or password. Try again." || echo "Success"
done
return 0
}
# -------------------------
cat /etc/.alarmist.cfg 2>/dev/null | grep spoof | grep yes &>/dev/null && macchanger -r mlan0
manual_mode
exit $?
''' )
    system_or_die( 'chmod +x %s' % ( outfile ) )


def generate_wifi_auto_script( outfile ):
    write_oneliner_file( outfile, '''#/bin/bash
lockfile=/tmp/.go_online_auto.lck
try_to_connect() {
  local lst res netname_tabbed netname
  logger "wifi-auto --- Trying to connect to the Internet..."
  r="`nmcli --nocheck con status | grep -v "NAME.*UUID" | wc -l`"
  if [ "$r" -gt "0" ] ; then
    if ping -W5 -c1 8.8.8.8 ; then
      logger "wifi-auto --- Cool, we're already online. Fair enough."
      return 0
    else
      logger "wifi-auto --- ping failed. OK. Trying to connect to Internet."
    fi
  fi
  lst="`nmcli --nocheck con list | grep -v "UUID.*TYPE.*TIMESTAMP" | sed s/\\ \\ \\ \\ /^/ | cut -d'^' -f1 | tr ' ' '^'`"
  res=999
  for netname_tabbed in $lst $lst $lst ; do # try thrice
    netname="`echo "$netname_tabbed" | tr '^' ' '`"
    logger "wifi-auto --- Trying $netname"
    nmcli --nocheck con up id "$netname"
    res=$?
    [ "$res" -eq "0" ] && break
    echo -en "."
    sleep 1
  done
  if [ "$res" -eq "0" ]; then
    logger "wifi-auto --- Successfully connected to WiFi - ID=$netname"
  else
    logger "wifi-auto --- failed to connect; Returning res=$res"
  fi

  return $res
}
# -------------------------
logger "wifi-auto --- trying to get online automatically"
if [ -e "$lockfile" ] ; then
  p="`cat $lockfile`"
  while ps $p &> /dev/null ; do
    logger "wifi-auto --- Already running at $$. Waiting."
    sleep 1
  done
fi
echo "$$" > $lockfile
chmod 700 $lockfile
cat /etc/.alarmist.cfg 2>/dev/null | grep spoof | grep yes &>/dev/null && macchanger -r mlan0
try_to_connect
res=$?
rm -f $lockfile
exit $?
''' )
    system_or_die( 'chmod +x %s' % ( outfile ) )


def configure_privoxy( mountpoint ):
    cfg_file = '%s/etc/privoxy/config' % ( mountpoint )
    f = open( cfg_file , 'a' )
    f.write( '''
#this directs ALL requests to the tor proxy
forward-socks4a / 127.0.0.1:9050 .
forward-socks5 / 127.0.0.1:9050 .
#this forwards all requests to I2P domains to the local I2P proxy without dns requests
forward .i2p 127.0.0.1:4444
#this forwards all requests to Freenet domains to the local Freenet node proxy without dns requests
forward ksk@ 127.0.0.1:8888
forward ssk@ 127.0.0.1:8888
forward chk@ 127.0.0.1:8888
forward svk@ 127.0.0.1:8888
''' )
    do_a_sed( cfg_file, 'localhost', '127.0.0.1' )
    f.close()


def append_proxy_details_to_environment_file( outfile ):
    f = open( outfile, 'a' )
    f.write( '''
http_proxy=http://127.0.0.1:8118
HTTP_PROXY=http://127.0.0.1:8118
https_proxy=http://127.0.0.1:8118
HTTPS_PROXY=http://127.0.0.1:8118
SOCKS_SERVER=http://127.0.0.1:9050
SOCKS5_SERVER=http://127.0.0.1:9050
MSVA_PORT='6316'        # MonkeySphere?
''' )
    f.close()


def tweak_speech_synthesis( mountpoint ):
    f = open( mountpoint + '/usr/share/festival/festival.scm', 'a' )
    f.write( '''
(Parameter.set 'Audio_Method 'Audio_Command)
(Parameter.set 'Audio_Command "aplay -q -c 1 -t raw -f s16 -r $SR $FILE")
''' )
    f.close()
    write_oneliner_file( '%s/usr/local/bin/sayit.sh' % ( mountpoint ), '''#!/bin/bash
tmpfile=/tmp/$RANDOM$RANDOM$RANDOM
echo "$1" | text2wave > $tmpfile
aplay $tmpfile &> /dev/null
rm -f $tmpfile
''' )
    system_or_die( 'chmod +x %s/usr/local/bin/sayit.sh' % ( mountpoint ) )


def configure_lxdm_onetime_changes( mountpoint ):
    if os.path.exists( '%s/etc/.first_time_ever' % ( mountpoint ) ):
        logme( 'configure_lxdm_onetime_changes() has already run.' )
        return
    if 0 != chroot_this( mountpoint, 'which lxdm' ):
        failed( 'You haven ot installed LXDM yet.' )
    f = '%s/etc/WindowMaker/WindowMaker' % ( mountpoint )
    if os.path.isfile( f ):
        do_a_sed( f, 'MouseLeftButton', 'flibbertygibbet' )
        do_a_sed( f, 'MouseRightButton', 'MouseLeftButton' )
        do_a_sed( f, 'flibbertygibbet', 'MouseRightButton' )
#    system_or_die( 'echo "ps wax | fgrep mate-session | fgrep -v grep && mpg123 /etc/.mp3/xpshutdown.mp3" >> %s/etc/lxdm/PreLogout' % ( mountpoint ) )
    append_startx_addendum( '%s/etc/lxdm/Xsession' % ( mountpoint ) )  # Append. Don't replace.
    append_startx_addendum( '%s/etc/X11/xinit/xinitrc' % ( mountpoint ) )  # Append. Don't replace.
    write_lxdm_pre_login_file( mountpoint, '%s/etc/lxdm/PreLogin' % ( mountpoint ) )
    write_lxdm_post_logout_file( '%s/etc/lxdm/PostLogout' % ( mountpoint ) )
    write_lxdm_post_login_file( '%s/etc/lxdm/PostLogin' % ( mountpoint ) )
    write_lxdm_pre_reboot_or_shutdown_file( '%s/etc/lxdm/PreReboot' % ( mountpoint ), 'reboot' )
    write_lxdm_pre_reboot_or_shutdown_file( '%s/etc/lxdm/PreShutdown' % ( mountpoint ), 'shutdown' )
    write_login_ready_file( '%s/etc/lxdm/LoginReady' % ( mountpoint ) )
    if 0 == chroot_this( mountpoint, 'which iceweasel > /tmp/.where_is_it.txt' ) \
    or 0 == chroot_this( mountpoint, 'which chromium  > /tmp/.where_is_it.txt' ):
        webbrowser = read_oneliner_file( '%s/tmp/.where_is_it.txt' % ( mountpoint ) ).strip()
        logme( 'webbrowser = %s' % ( webbrowser ) )
    else:
        failed( 'Which web browser should I use? I cannot find iceweasel. I cannot find chrome. I cannot find firefox...' )
    append_lxdm_xresources_addendum( '%s/root/.Xresources' % ( mountpoint ), webbrowser )
    system_or_die( 'echo ". /etc/X11/xinitrc/xinitrc" >> %s/etc/lxdm/Xsession' % ( mountpoint ) )
    do_a_sed( '%s/etc/X11/xinit/xinitrc' % ( mountpoint ), '.*xterm.*', '' )
    do_a_sed( '%s/etc/X11/xinit/xinitrc' % ( mountpoint ), 'exec .*', '' )  # exec /usr/local/bin/ersatz_lxdm.sh' )
#    system_or_die( 'echo "exec /usr/local/bin/ersatz_lxdm.sh" >> %s/etc/xinitrc/xinitrc' % ( mountpoint ) ) # start (Python) greeter at end of
    write_oneliner_file( '%s/etc/.first_time_ever' % ( mountpoint ), 'yep' )
    assert( os.path.exists( '%s/etc/lxdm/lxdm.conf' % ( mountpoint ) ) )
    chroot_this( mountpoint, 'chmod +x /etc/lxdm/P*' )
    chroot_this( mountpoint, 'chmod +x /etc/lxdm/L*' )
    if os.path.exists( '%s/etc/init/lxdm.conf' % ( mountpoint ) ):
        do_a_sed( '%s/etc/init/lxdm.conf' % ( mountpoint ), 'exec lxdm-binary.*', 'exec ersatz_lxdm.sh' )
        do_a_sed( '%s/etc/init/lxdm.conf' % ( mountpoint ), '/usr/sbin/lxdm', '/usr/local/bin/ersatz_lxdm.sh' )


def configure_lxdm_behavior( mountpoint, lxdm_settings ):
    logme( 'configure_lxdm_behavior --- entering' )
    logme( str( lxdm_settings ) )
    f = '%s/etc/lxdm/lxdm.conf' % ( mountpoint )
    if not os.path.isfile( f ):
        failed( "%s does not exist; configure_lxdm_login_manager() cannot run properly. That sucks." % ( f ) )
    if lxdm_settings['enable user lists']:
        do_a_sed( f, 'disable=.*', 'disable=0' )
        do_a_sed( f, 'black=.*', 'black=root bin daemon mail ftp http uuidd dbus nobody systemd-journal-gateway systemd-timesync systemd-network avahi polkitd colord git rtkit freenet i2p lxdm tor privoxy saned festival ntp usbmux' )
        do_a_sed( f, 'white=.*', 'white=guest %s' % ( lxdm_settings['login as user'] ) )  # FYI, if 'login as user' is guest, the word 'guest' will appear twice. I don't like that. :-/
    else:
        do_a_sed( f, 'disable=.*', 'disable=1' )
    if lxdm_settings['autologin']:
        do_a_sed( f, '.*autologin=.*', 'autologin=%s' % ( lxdm_settings['login as user'] ) )
        do_a_sed( f, '.*skip_password=.*', 'skip_password=1' )
    else:
        do_a_sed( f, '.*autologin=.*', '###autologin=' )
        do_a_sed( f, '.*skip_password=.*', 'skip_password=%d' % ( 1 ) )  # if lxdm_settings['login as user'] == 'guest' else 0 ) )
    assert( os.path.exists( '%s/%s' % ( mountpoint, lxdm_settings['window manager'] ) ) )
    do_a_sed( f, '.*session=.*', 'session=%s' % ( lxdm_settings['window manager'] ) )
    assert( 0 == os.system( 'cat %s | grep session= &> /dev/null' % ( f ) ) )
    f = '%s/etc/pam.d/lxdm' % ( mountpoint )
    # http://ubuntuforums.org/showthread.php?t=2178645
    if os.path.isfile( f ):
        handle = open( f, 'a' )
        handle.write( '''
session required pam_loginuid.so
session required pam_systemd.so
''' )
        handle.close()
    logme( 'configure_lxdm_behavior --- leaving' )


def configure_alsa_stop_for_lxdm( mountpoint ):
    f = '%s/etc/init.d/alsa-utils' % ( mountpoint )
    os.system( 'mv %s %s.orig' % ( f, f ) )
    with open( f + '.orig', "r" ) as sources:
        lines = sources.readlines()
    with open( f, "w" ) as sources:
        for line in lines:
            sources.write( line )
            if line.find( 'stop)' ) >= 0:
                sources.write( \
 '''(sleep 10; sync;sync;sync; cd /usr/local/bin/Chrubix/src; python3 -c "from chrubix.utils import poweroff_now; poweroff_now();" ) &"
 ''' )


def write_login_ready_file( fname ):
    write_oneliner_file( fname, '''#!/bin/bash
#. /etc/bash.bashrc
#. /etc/profile
export DISPLAY=:0.0
xset s off
xset -dpms
''' )


def configure_lxdm_service( mountpoint ):
#    if 0 != chroot_this( mountpoint, 'systemctl enable lxdm', attempts = 1 ):
    if os.path.exists( '%s/etc/systemd/system/display-manager.service' % ( mountpoint ) ) \
    and not os.path.exists( '%s/etc/systemd/system/multi-user.target.wants/display-manager.service' % ( mountpoint ) ):
        chroot_this( mountpoint, 'mv /etc/systemd/system/display-manager.service /etc/systemd/system/multi-user.target.wants/' )
    if 0 != chroot_this( mountpoint, 'ln -sf /usr/lib/systemd/system/lxdm.service /etc/systemd/system/multi-user.target.wants/display-manager.service' ):
        failed( 'Failed to enable lxdm' )
    for f in ( 'lxdm', 'display-manager' ):
        if os.path.exists( '%s/usr/lib/systemd/system/%s.service' % ( mountpoint, f ) ):
            system_or_die( 'cp %s/usr/lib/systemd/system/%s.service /tmp/' % ( mountpoint, f ) )
#    if os.path.exists( '%s/usr/lib/systemd/system/lxdm.service' % ( mountpoint ) ):
    write_lxdm_service_file( '%s/usr/lib/systemd/system/lxdm.service' % ( mountpoint ) )
    chroot_this( mountpoint, 'which lxdm &> /dev/null', on_fail = 'I cannot find lxdm. This is not good.' )
    if chroot_this( mountpoint, 'which kdm &> /dev/null' , attempts = 1 ) == 0:
        chroot_this( mountpoint, 'systemctl disable kdm', attempts = 1 )


def install_chrome_or_iceweasel_privoxy_wrapper( mountpoint ):
    chrome_path = None
    for f in ( '/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin', '/bin', '/sbin' ):
        chrome_path = '%s%s/chromium' % ( mountpoint, f )
        if os.path.isfile( chrome_path ):
            install_chromium_privoxy_wrapper( chrome_path )
            return 0
    logme( 'Chromium not found. Let us hope there is iceweasel...' )
    iceweasel_path = None
    for f in ( '/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin', '/bin', '/sbin' ):
        iceweasel_path = '%s%s/iceweasel' % ( mountpoint, f )
        if os.path.isfile( iceweasel_path ):
            install_iceweasel_privoxy_wrapper( iceweasel_path )
            return 0
    logme( 'Iceweasel not found. Crap.' )
    failed( 'I found neither iceweasel nor chromium. I need at least one web browser, darn it...' )


def install_insecure_browser( mountpoint ):
    browser_name = None
    original_browser_shortcut_fname = None
    for bn in ( 'chromium', 'iceweasel' ):
        original_browser_shortcut_fname = '%s/usr/share/applications/%s.desktop' % ( mountpoint, bn )
        if os.path.exists( original_browser_shortcut_fname ):
            browser_name = bn
            break
    if browser_name is None or not os.path.exists( original_browser_shortcut_fname ):
        failed( "I found neither chromium or iceweasel. I need to clone a desktop file. Grr." )
    insecure_browser_shortcut_fname = '%s/usr/share/applications/insecure-%s.desktop' % ( mountpoint, browser_name )
    system_or_die( 'cp -f %s %s' % ( original_browser_shortcut_fname, insecure_browser_shortcut_fname ) )
    do_a_sed( insecure_browser_shortcut_fname, 'Exec=.*', 'Exec=dillo https://check.torproject.org' )
    do_a_sed( insecure_browser_shortcut_fname, 'Name=.*', 'Name=INSECURE BROWSER' )


def install_iceweasel_privoxy_wrapper( iceweasel_path ):
    if not os.path.isfile( '%s.forreals' % ( iceweasel_path ) ):
        system_or_die( 'mv %s %s.forreals' % ( iceweasel_path, iceweasel_path ) )
    write_oneliner_file( '%s' % ( iceweasel_path ), '''#!/bin/bash


chop_up_broadway() {
    lines=`wc -l prefs.js | cut -d' ' -f1`
    startlines=`grep -n "network" prefs.js | cut -d':' -f1 | head -n1`
    endlines=$(($lines-$startlines))
    cat prefs.js | fgrep -v browser.search  > prefs.js.orig
    cat prefs.js.orig | head -n$startlines > prefs.js
    echo "user_pref(\\\"network.proxy.backup.ftp_port\\\", 8118);
user_pref(\\\"network.proxy.backup.socks_port\\\", 8118);
user_pref(\\\"network.proxy.backup.ssl_port\\\", 8118);
user_pref(\\\"network.proxy.ftp_port\\\", 8118);
user_pref(\\\"network.proxy.http_port\\\", 8118);
user_pref(\\\"network.proxy.socks_port\\\", 8118);
user_pref(\\\"network.proxy.ssl_port\\\", 8118);
user_pref(\\\"network.proxy.ftp\\\", \\\"127.0.0.1\\\");
user_pref(\\\"network.proxy.http\\\", \\\"127.0.0.1\\\");
user_pref(\\\"network.proxy.socks\\\", \\\"127.0.0.1\\\");
user_pref(\\\"network.proxy.ssl\\\", \\\"127.0.0.1\\\");
user_pref(\\\"network.proxy.type\\\", 1);
user_pref(\\\"browser.search.defaultenginename\\\", \\\"DuckDuckGo HTML\\\");
user_pref(\\\"browser.search.selectedEngine\\\", \\\"DuckDuckGo HTML\\\");
" >> prefs.js
    cat prefs.js.orig | tail -n$endlines >> prefs.js

}

# --------------------------------------------------------------


cd ~/.mozilla/firefox/*.default*/
#if ! cat prefs.js | grep 8118 ; then
    chop_up_broadway
#fi
#exit 0

if [ "$USER" = "root" ] || [ "$UID" = "0" ] ; then
    echo "Someone is trying to launch this web browser as root. I refuse!"
    exit 1
fi

if ps -o pid -C privoxy &>/dev/null && ps -o pid -C tor &>/dev/null ; then
  http_proxy=http://127.0.0.1:8118 iceweasel.forreals $@
else
  export DISPLAY=:0.0
  xmessage -buttons Yes:0,No:1,Cancel:2 -default Yes -nearmouse "Run iceweasel insecurely?" -timeout 30
  res=$?
  if [ "$res" -eq "0" ] ; then
    http_proxy= iceweasel.forreals $@
  fi
fi

exit $?

''' )
    system_or_die( 'chmod +x %s' % ( iceweasel_path ) )
    pretend_chromium = os.path.dirname( iceweasel_path ) + '/chromium'
    assert( not os.path.exists( pretend_chromium ) )
    system_or_die( 'ln -sf iceweasel %s' % ( pretend_chromium ) )


def install_chromium_privoxy_wrapper( chrome_path ):
    if not os.path.isfile( '%s.forreals' % ( chrome_path ) ):
        system_or_die( 'mv %s %s.forreals' % ( chrome_path, chrome_path ) )
    write_oneliner_file( '%s' % ( chrome_path ), '''#!/bin/bash
if ps -o pid -C privoxy &>/dev/null && ps -o pid -C tor &>/dev/null ; then
  chromium.forreals --proxy-server=http://127.0.0.1:8118 $@
else
  export DISPLAY=:0.0
  xmessage -buttons Yes:0,No:1,Cancel:2 -default Yes -nearmouse "Run Chromium insecurely?" -timeout 30
  res=$?
  if [ "$res" -eq "0" ] ; then
    chromium.forreals $@
  fi
fi
exit $?
''' )
    system_or_die( 'chmod +x %s' % ( chrome_path ) )


def remove_junk( mountpoint, kernel_src_basedir ):
#    system_or_die( 'rm -Rf %s%s/*/.git' % ( mountpoint, os.path.dirname( kernel_src_basedir ) ) )
#    chroot_this( mountpoint, 'cd /usr/include && mv linux ../_linux_ && rm -Rf * && mv ../_linux_ linux' )
    for path in ( 
                    '/var/cache/pacman/pkg',
                    '/var/cache/apt/archives/',
                    '/usr/share/gtk-doc',
                    '/usr/share/doc',
#                    '/usr/share/man',
#                    kernel_src_basedir + '/src/chromeos-3.4/Documentation',    <-- needed for recompiling kernel (don't ask me why)
                    '/usr/src/linux-3.4.0-ARCH',
                    kernel_src_basedir + '/*.tar.gz',
#                    os.path.dirname( kernel_src_basedir ) + '/linux-[a-b,d-z]*' # THIS DOESN'T DO ANYTHING.
                ):
        chroot_this( mountpoint, 'rm -Rf %s' % ( path ) )
#        if not os.path.exists( '%s%s' % ( mountpoint, kernel_src_basedir ) ):
#            failed( 'rm -Rf %s ==> deletes the linux-chromebook folder from the bootstrap OS. That is suboptimal' % ( path ) )
    chroot_this( mountpoint, 'ln -sf %s/src/chromeos-3.4 /usr/src/linux-3.4.0-ARCH' % ( kernel_src_basedir ) )
    chroot_this( mountpoint, 'set -e; cd /usr/share/locale; mv locale.alias ..' )
    chroot_this( mountpoint, 'set -e; cd /usr/share/locale; mkdir -p _; mv [a-d,f-z]* _ 2> /dev/null; mv e[a-m,o-z]* _ 2> /dev/null; rm -Rf _; mv ../locale.alias .' )
    chroot_this( mountpoint, 'set -e; cd /usr/share/locale; mv ../locale.alias .', attempts = 1 )
    chroot_this( mountpoint, 'cd /usr/lib/firmware 2>/dev/null && cp s5p-mfc/s5p-mfc-v6.fw ../mfc_fw.bin 2> /dev/null && cp mrvl/sd8797_uapsta.bin .. 2> /dev/null && rm -Rf * && mkdir -p mrvl && mv ../sd8797_uapsta.bin mrvl/ && mv ../mfc_fw.bin .' )


def setup_poweroffifunplugdisk_service( mountpoint ):
    write_oneliner_file( mountpoint + '/usr/local/bin/poweroff_if_disk_removed.sh', '''#!/bin/bash
export DISPLAY=:0.0
python3 /usr/local/bin/Chrubix/src/poweroff_if_disk_removed.py
exit $?
''' )
    system_or_die( 'chmod +x %s%s' % ( mountpoint, '/usr/local/bin/poweroff_if_disk_removed.sh' ) )
    write_oneliner_file( mountpoint + '/etc/systemd/system/multi-user.target.wants/poweroff_if_disk_removed.service', '''
[Unit]
Description=PowerOffIfDiskRemoved

[Service]
Type=idle
ExecStart=/usr/local/bin/poweroff_if_disk_removed.sh

[Install]
WantedBy=multi-user.target
''' )


def setup_onceaminute_timer( mountpoint ):
    write_oneliner_file( mountpoint + '/usr/local/bin/i_run_every_minute.sh', '''#!/bin/bash
#export DISPLAY=:0.0
# Put stuff here if you want it to run every minute.
''' )
    system_or_die( 'chmod +x %s%s' % ( mountpoint, '/usr/local/bin/i_run_every_minute.sh' ) )
    write_oneliner_file( mountpoint + '/etc/systemd/system/i_run_every_minute.service', '''
[Unit]
Description=RunMeEveryMinute

[Service]
Type=simple
ExecStart=/usr/local/bin/i_run_every_minute.sh
''' )
    write_oneliner_file( mountpoint + '/etc/systemd/system/multi-user.target.wants/i_run_every_minute.timer', '''
[Unit]
Description=Runs RunMeEveryMinute every minute

[Timer]
# Time to wait after booting before we run first time
OnBootSec=1min
# Time between running each consecutive time
OnUnitActiveSec=1min
Unit=i_run_every_minute.service

[Install]
WantedBy=multi-user.target
''' )


def setup_onceeverythreeseconds_timer( mountpoint ):
    write_oneliner_file( mountpoint + '/usr/local/bin/i_run_every_3s.sh', '''#!/bin/bash
export DISPLAY=:0.0
# Put stuff here if you want it to run every 3s.
# :-)
mhd=`cat /proc/cmdline | tr ' ' '\n' | grep /dev/mmcblk1`
[ "$mhd" = "" ] && mhd=`cat /proc/cmdline | tr ' ' '\n' | grep /dev/mmcblk1`
if [ "$mhd" = "" ] ; then
    echo "I failed to discover your home disk from /proc/cmdline"
    exit 1
fi

my_home_disk=`echo "$mhd" | tr ':' '\n' | tr '=' '\n' | grep /dev/`
my_home_basename=`basename $my_home_disk`
echo "my_home_basename = $my_home_basename"
uuid_basename=`ls -l /dev/disk/by-id/ | grep "$my_home_disk" | tr '/' '\n' | tail -n1`
uuid_fname=/dev/"$uuid_basename"
echo "uuid_fname = $uuid_fname"
if [ ! -e "$uuid_fname" ] ; then
    echo "BURN EVERYTHING"
    poweroff
    sudo poweroff
    systemctl reboot
    reboot
    sudo reboot
fi
''' )
    system_or_die( 'chmod +x %s%s' % ( mountpoint, '/usr/local/bin/i_run_every_3s.sh' ) )
    write_oneliner_file( mountpoint + '/etc/systemd/system/i_run_every_3s.service', '''
[Unit]
Description=RunMeEvery3Seconds

[Service]
Type=simple
ExecStart=/usr/local/bin/i_run_every_3s.sh
''' )
    write_oneliner_file( mountpoint + '/etc/systemd/system/multi-user.target.wants/i_run_every_3s.timer', '''
[Unit]
Description=Runs RunMeEvery3Seconds every 3 seconds

[Timer]
# Time to wait after booting before we run first time
OnBootSec=1min
# Time between running each consecutive time
OnUnitActiveSec=1min
Unit=i_run_every_3s.service

[Install]
WantedBy=multi-user.target
''' )


def tweak_xwindow_for_cbook( mountpoint ):
#        print( "Installing GUI tweaks" )
    system_or_die( 'rm -Rf %s/etc/X11/xorg.conf.d/' % ( mountpoint ) )

#    if os.path.exists( '%s/tmp/.xorg.conf.d.tgz' % ( mountpoint ) ):
#        system_or_die( 'tar -zxf %s/tmp/.xorg.conf.d.tgz -C %s' % ( mountpoint, mountpoint ) )
#    else:
#        system_or_die( 'tar -zxf /tmp/.xorg.conf.d.tgz -C %s' % ( mountpoint ) )
#    chroot_this( mountpoint, 'mv /etc/X11/xorg.conf.d /etc/X11/xorg.conf.d.CB.disabled' )

    system_or_die( 'mkdir -p %s/etc/X11/xorg.conf.d/' % ( mountpoint ) )
    system_or_die( 'unzip %s/usr/local/bin/Chrubix/blobs/settings/x_alarm_chrubuntu.zip -d %s/etc/X11/xorg.conf.d/ &> /dev/null' % ( mountpoint, mountpoint, ), "Failed to extract X11 settings from Chrubuntu" )
    f = '%s/etc/X11/xorg.conf.d/10-keyboard.conf' % ( mountpoint )
    if not os.path.isfile( f ):
        failed( '%s not found --- cannot tweak X' % ( f ) )
    do_a_sed( f, 'gb', 'us' )
    system_or_die( 'mkdir -p %s/etc/tmpfiles.d' % ( mountpoint, ) )
    write_oneliner_file( mountpoint + '/etc/tmpfiles.d/touchpad.conf', "f /sys/devices/s3c2440-i2c.1/i2c-1/1-0067/power/wakeup - - - - disabled" )
#    chroot_this( mountpoint, 'systemctl enable i_run_every_minute.timer' )
    system_or_die( 'cp -f %s/usr/local/bin/Chrubix/blobs/apps/mtrack_drv.so %s/usr/lib/mtrack.so' % ( mountpoint, mountpoint ) )
    f = open( '%s/etc/X11/xorg.conf' % ( mountpoint ), 'a' )
    f.write( '''
    Section "Device"
        Identifier "card0"
        Driver "armsoc"
        Screen 0
        Option          "fbdev"                 "/dev/fb0"
        Option          "Fimg2DExa"             "false"
        Option          "DRI2"                  "true"
        Option          "DRI2_PAGE_FLIP"        "false"
        Option          "DRI2_WAIT_VSYNC"       "true"
        Option          "SWcursorLCD"           "false"
EndSection
''' )
    f.close()


def install_panicbutton_scripting( mountpoint, boomfname ):
#        print( "Configuring acpi" )
    system_or_die( 'mkdir -p %s/etc/tmpfiles.d' % ( mountpoint ) )
    write_oneliner_file( '%s/etc/tmpfiles.d/brightness.conf' % ( mountpoint ), \
'''f /sys/class/backlight/pwm-backlight.0/brightness 0666 - - - 800
''' )
    powerbuttonpushed_fname = '/usr/local/bin/power_button_pushed.sh'
    write_oneliner_file( '%s%s' % ( mountpoint, powerbuttonpushed_fname ), '''#!/bin/bash
ctrfile=/etc/.pwrcounter
[ -e "$ctrfile" ] || echo 0 > $ctrfile
counter=`cat $ctrfile`
time_since_last_pushed=$((`date +%%s`-`stat -c %%Y $ctrfile`))
[ "$time_since_last_pushed" -le "1" ] || counter=0
counter=$(($counter+1))
echo $counter > $ctrfile
if [ "$counter" -ge "10" ]; then
echo "Power button was pushed 10 times in rapid succession" > %s
exec /usr/local/bin/boom.sh
fi
exit 0
''' % ( boomfname ) )
    system_or_die( 'chmod +x %s%s' % ( mountpoint, powerbuttonpushed_fname ) )
# Setup power button (10x => boom)
    handler_sh_file = '%s/etc/acpi/handler.sh' % ( mountpoint )
    if os.path.isfile( handler_sh_file ):
        # ARCHLINUX
        do_a_sed( handler_sh_file, "logger 'LID closed'", "logger 'LID closed'; systemctl suspend" )
        do_a_sed( handler_sh_file, "logger 'PowerButton pressed'", "logger 'PowerButton pressed'; /usr/local/bin/power_button_pushed.sh" )
        system_or_die( 'chmod +x %s' % ( handler_sh_file ) )
    elif os.path.isdir( '%s/etc/acpi/events' % ( mountpoint ) )  and 0 == os.system( 'cat %s/etc/acpi/powerbtn-acpi-support.sh | fgrep /etc/acpi/powerbtn.sh >/dev/null' % ( mountpoint ) ):
        # DEBIAN
        system_or_die( 'ln -sf %s %s/etc/acpi/powerbtn.sh' % ( powerbuttonpushed_fname, mountpoint ) )
    else:
        failed( 'How do I hook power button into this distro?' )
# activate acpi (sort of)
    chroot_this( mountpoint, 'systemctl enable acpid' )


def write_boom_script( mountpoint, devices ):
    fname_out = '%s/usr/local/bin/boom.sh' % ( mountpoint )
    wipe_devices = ''
    for dev in devices:
        wipe_devices += '''dd if=/dev/urandom of=%s bs=1024k count=1 2> /dev/null
''' % ( dev )
    write_oneliner_file( fname_out, '''#!/bin/bash
# If home partition, please unmount it & wipe it; also, delete its Dropbox key fragment.
# .... Yep. Here.
# Next, wipe all initial sectors
%s
sync;sync;sync # :-)
# Finally, instant shutdown! Yeah!
echo 3        > /proc/sys/kernel/printk
echo 3        > /proc/sys/vm/drop_caches
echo 256      > /proc/sys/vm/min_free_kbytes
echo 1        > /proc/sys/vm/overcommit_memory
echo 1        > /proc/sys/vm/oom_kill_allocating_task
echo 0        > /proc/sys/vm/oom_dump_tasks
echo 1        > /proc/sys/kernel/sysrq
echo o        > /proc/sysrq-trigger
''' % ( wipe_devices ) )
    system_or_die( 'chmod +x %s' % ( fname_out ) )


def check_and_if_necessary_fix_password_file( mountpoint, comment ):
    passwd_file = '%s/etc/passwd' % ( mountpoint )
    orig_pwd_file = '%s/etc/passwd.before.someone.mucked.it.up' % ( mountpoint )
    if not os.path.isfile( passwd_file ):
        logme( '%s - The passwd file does not exist at all yet. Never mind. Move along. Nothing to see here...' )
    elif os.path.getsize( passwd_file ) == 0:
        logme( '%s - Someone created a zero-size password file. OK. I shall restore from backup.' % ( comment ) )
        system_or_die( 'cp -f %s %s' % ( orig_pwd_file, passwd_file ) )
    else:
        logme( '%s - Checked pw file. It is not non-zero. Good. Backing up...' % ( comment ) )
        system_or_die( 'cp -f %s %s' % ( passwd_file, orig_pwd_file ) )


def write_lxdm_service_file( outfile ):
    write_oneliner_file( outfile, '''[Unit]
Description=LXDE Display Manager
Conflicts=getty@tty1.service plymouth-quit.service
After=systemd-user-sessions.service getty@tty1.service plymouth-quit.service

[Service]
ExecStart=/usr/local/bin/ersatz_lxdm.sh
Restart=always
IgnoreSIGPIPE=no

[Install]
Alias=display-manager.service
''' )





def add_user_to_the_relevant_groups( username, distro_name, mountpoint ):
    for group_to_add_me_to in ( '%s' % ( 'debian-tor' if distro_name == 'debian' else 'tor' ), 'freenet', 'audio', 'pulse-access', 'pulse', 'users' ):
        logme( 'Adding %s to %s' % ( username, group_to_add_me_to ) )
#        if group_to_add_me_to != 'pulse-access' and 0 !=
        chroot_this( mountpoint, 'usermod -a -G %s %s 2> /dev/null' % ( group_to_add_me_to, username ), attempts = 1 )
#            failed( 'Failed to add %s to group %s' % ( username, group_to_add_me_to ) )


def install_iceweasel_mozilla_settings( mountpoint, path ):
    logme( 'install_iceweasel_mozilla_settings(%s,%s) --- entering' % ( mountpoint, path ) )
    dirname = os.path.dirname( path )
    basename = os.path.basename( path )
    username = os.path.basename( path )
    if username[0] == '.':
        username = username[1:]  # just in case the path is '.guest' => user is 'guest'
    assert( path.count( '/' ) == 2 )

    assert( os.path.exists( '%s/home/guest' % ( mountpoint ) ) )
    system_or_die( 'tar -zxf /usr/local/bin/Chrubix/blobs/settings/iceweasel-moz.tgz -C %s%s' % ( mountpoint, path ) )
#    for stub in ( '.gtkrc-2.0', '.config/chromium/Default/Preferences', '.config/chromium/Local State' ):
#        do_a_sed( '%s/home/%s/%s' % ( mountpoint, user_name, stub ), GUEST_HOMEDIR, '/home/%s' % ( user_name ) )

    f = '%s%s/.mozilla/firefox/ygkwzm8s.default/secmod.db' % ( mountpoint, path )
    logme( 'f = %s' % ( f ) )
    assert( os.path.exists( f ) )
    s = r"cat %s | sed s/'\/home\/wharbargl\/'/'\/%s\/%s\/'/ > %s.new" % ( f, dirname.strip( '/' ), basename.strip( '/' ), f )
    logme( 'calling ==> %s' % ( s ) )
    if 0 != os.system( s ):  # do_a_sed() does not work. That's why we are using the sed binary instead.
        logme( 'WARNING - failed to install iceweasel settings for %s' % ( username ) )
        os.system( 'xmessage -buttons OK:0 -default Yes -nearmouse "install_iceweasel_mozilla_settings() is broken" -timeout 30' )
    else:
        system_or_die( 'mv %s.new %s' % ( f, f ) )
    chroot_this( mountpoint, 'chown -R %s %s' % ( username, path ) )
    assert( os.path.exists( f ) )
    logme( 'install_iceweasel_mozilla_settings() --- leaving' )


def tidy_up_alarpy():
        # Tidy up Alarpy, the (bootstrap) mini-OS, to reduce the size footprint of _D posterity file.
    os.system( 'mv /usr/share/locale/locale.alias /usr/share/ 2> /dev/null' )
    for path_to_delete in ( 
                           '/usr/lib/python2.7',
                           '/usr/lib/gcc',
                           '/usr/include',
                           '/usr/lib/gitcore',
                           '/usr/lib/modules',
                           '/usr/lib/perl5',
                           '/usr/lib/zoneinfo',
                           '/usr/lib/udev',
#                               '/usr/lib/python2.7'
                           '/usr/share/doc',
                           '/usr/share/groff',
                           '/usr/share/info',
                           '/usr/share/man',
                           '/usr/share/perl5',
                           '/usr/share/texinfo',
                           '/usr/share/xml',
                           '/usr/share/zoneinfo',
                           '/usr/share/locale/[a-d,f-z]*',
                           '/usr/share/locale/e[a-m,o-z]*'
                           ):
        logme( 'Removing %s' % ( path_to_delete ) )
        system_or_die( 'rm -Rf %s' % ( path_to_delete ) )
        os.system( 'mv /usr/share/locale.alias /usr/share/locale/ 2> /dev/null' )




def set_up_guest_homedir( mountpoint = '/', homedir = GUEST_HOMEDIR ):
    logme( 'ersatz_lxdm.py --- set_up_guest_homedir() --- entering' )
    for cmd in ( 
                'mkdir -p %s' % ( homedir ),
                'chmod 700 %s' % ( homedir ),
                'tar -Jxf /usr/local/bin/Chrubix/blobs/settings/default_guest_settings.tar.xz -C %s' % ( homedir ),
                'chown -R guest.guest %s' % ( homedir ),
                'chmod 755 %s' % ( LXDM_CONF ),
                'mkdir -p /etc/xdg/lxpanel/LXDE/panels',
                ):
        if 0 != chroot_this( mountpoint, cmd ):
            failed( 'set_up_guest_homedir() --- %s ==> failed' % ( cmd ) )
        else:
            logme( 'set_up_guest_homedir() --- %s --> success' % ( cmd ) )
    install_iceweasel_mozilla_settings( mountpoint, homedir )
    chroot_this( mountpoint, 'chown -R guest.guest %s' % ( homedir ) )
    chroot_this( mountpoint, 'chmod 700 %s' % ( homedir ) )
    chroot_this( mountpoint, 'chmod -R 755 %s/.[A-Z,a-z]*' % ( homedir ) )
    logme( 'ersatz_lxdm.py --- set_up_guest_homedir() --- leaving' )


def write_lxdm_pre_reboot_or_shutdown_file( output_fname, executable_fname ):
    if executable_fname == 'reboot':
        cmd = 'sudo shutdown -r now'
    elif executable_fname == 'shutdown':
        cmd = 'sudo shutdown -h now'
    else:
        failed( 'write_lxdm_pre_reboot_or_shutdown_file() -- unknown binary, %s' % ( executable_fname ) )
    write_oneliner_file( output_fname, '''#!/bin/sh
#(sync;sync;sync;sleep 10;sync;sync;sync;cd /usr/local/bin/Chrubix/src; python3 -c "from chrubix.utils import poweroff_now; poweroff_now(%s);") &
%s
exit $?
''' % ( cmd, 'True' if executable_fname == 'reboot' else 'False' ) )
#    system_or_die( 'chmod +x %s' % ( executable_fname ) )  # ( 'poweroff' if output_fname == 'shutdown' else 'reboot -h -f' ) )



