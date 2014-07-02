#!/usr/local/bin/python3
#
# postinst.py


'''
Created on May 9, 2014
'''


import os
from chrubix.utils import write_oneliner_file, failed, system_or_die, logme, do_a_sed, chroot_this, \
                        read_oneliner_file


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
logger "QQQ startx cccc"
syndaemon -t -k -i 1 -d    # disable mousepad for 1s after typing finishes
logger "QQQ startx end of startx addendum"
''' )
    f.close()


def write_lxdm_post_login_file( outfile ):
    f = open( outfile, 'w' )
    f.write( '''#!/bin/sh
#. /etc/bash.bashrc
#. /etc/profile
liu=/tmp/.logged_in_user
echo "$USER" > $liu
export DISPLAY=:0.0
sleep 2
while ! ps wax | grep " X " ; do
    sleep 0.5
done
sleep 1
python3 /usr/local/bin/Chrubix/src/lxdm_post_login.py
''' )
    f.close()


def write_lxdm_post_logout_file( outfile ):
    f = open( outfile, 'w' )
    f.write( '''#!/bin/sh

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


def write_lxdm_pre_login_file( outfile ):
    f = open( outfile, 'w' )
    f.write( '''#!/bin/sh
#. /etc/bash.bashrc
#. /etc/profile
[ -e "/tmp/_root.old" ] && rm /tmp/_root.old
[ -e "/tmp/_root" ] && mv /tmp/_root /tmp/_root.old
ln -sf / /tmp/_root

''' )
    f.close()


def append_lxdm_xresources_addendum( outfile ):
    f = open( outfile, 'a' )
    f.write( '''
# ------- vvv XRESOURCES vvv ------- Make sure rxvf etc. will use chromium to open a web browser if user clicks on http:// link
    echo "
UXTerm*VT100*translations: #override Shift <Btn1Up>: exec-formatted("/usr/local/bin/run_browser_as_guest.sh '%t'", PRIMARY)
UXTerm*charClass: 33:48,36-47:48,58-59:48,61:48,63-64:48,95:48,126:48
URxvt.perl-ext-common: default,matcher
URxvt.url-launcher: /usr/local/bin/run_browser_as_guest.sh
URxvt.matcher.button: 1
''' )
    f.close()


def generate_wifi_manual_script( outfile ):
    write_oneliner_file( outfile, '''#/bin/sh
lockfile=/tmp/.go_online_manual.lck
manual_mode() {
logger "QQQ wifi-manual --- starting"
res=999
#clear
while [ "$res" -ne "0" ] ; do
    echo -en "Searching..."
    all=""
    loops=0
    while [ "`echo "$all" | wc -c`" -lt "4" ] && [ "$loops" -le "10" ] ; do
        all="`nmcli --nocheck dev wifi list | grep -v "SSID.*BSSID" | sed s/'    '/^/ | cut -d'^' -f1 | awk '{printf ", " substr($0,2,length($0)-2);}' | sed s/', '//`"
        if [ "$all" = "" ] ; then
            if ! ps wax | fgrep nm-applet | grep -v grep ; then
                nm-applet &
            fi
        fi
        sleep 1
        echo -en "."
        loops=$(($loops+1))
    done
    if [ "`echo "$all" | wc -c`" -lt "4" ] ; then
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
    write_oneliner_file( outfile, '''#/bin/sh
lockfile=/tmp/.go_online_auto.lck
try_to_connect() {
  local lst res netname_tabbed netname
  logger "QQQ wifi-auto --- Trying to connect to the Internet..."
  r="`nmcli --nocheck con status | grep -v "NAME.*UUID" | wc -l`"
  if [ "$r" -gt "0" ] ; then
    if ping -W5 -c1 8.8.8.8 ; then
      logger "QQQ wifi-auto --- Cool, we're already online. Fair enough."
      return 0
    else
      logger "QQQ wifi-auto --- ping failed. OK. Trying to connect to Internet."
    fi
  fi
  lst="`nmcli --nocheck con list | grep -v "UUID.*TYPE.*TIMESTAMP" | sed s/\\ \\ \\ \\ /^/ | cut -d'^' -f1 | tr ' ' '^'`"
  res=999
  for netname_tabbed in $lst $lst $lst ; do # try thrice
    netname="`echo "$netname_tabbed" | tr '^' ' '`"
    logger "QQQ wifi-auto --- Trying $netname"
    nmcli --nocheck con up id "$netname"
    res=$?
    [ "$res" -eq "0" ] && break
    echo -en "."
    sleep 1
  done
  if [ "$res" -eq "0" ]; then
    logger "QQQ wifi-auto --- Successfully connected to WiFi - ID=$netname"
  else
    logger "QQQ wifi-auto --- failed to connect; Returning res=$res"
  fi

  return $res
}
# -------------------------
logger "QQQ wifi-auto --- trying to get online automatically"
if [ -e "$lockfile" ] ; then
  p="`cat $lockfile`"
  while ps $p &> /dev/null ; do
    logger "QQQ wifi-auto --- Already running at $$. Waiting."
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


def install_guest_browser_script( mountpoint ):
    system_or_die( 'echo "H4sIAF52SVMAA1WMvQrCMBzE9zzF2YYukkYfoBbBVQXnTKZ/TaBJpEmhQx/eUNTidMd9/MqNvFsvo2EsudfD9tTIbGQXhKOa346X0/X8L3UekzYBgjyK8gtQnu+Vp8kmKN4qX+AA/mEybVzosJ3WJI4QPZ4jxQShfzmqCgPFZod5Xgxv2eDW28LnuWBvkUV8bboAAAA=" \
| base64 -d | gunzip > %s/usr/local/bin/run_as_guest.sh' % ( mountpoint ) )
    system_or_die( 'chmod +x %s/usr/local/bin/run_as_guest.sh' % ( mountpoint ) )
    write_oneliner_file( '%s/usr/local/bin/run_browser_as_guest.sh' % ( mountpoint ), '''#!/bin/sh
GUEST_HOMEDIR=/tmp/.guest
sudo /usr/local/bin/run_as_guest.sh "export DISPLAY=:0.0; chromium --user-data-dir=$GUEST_HOMEDIR $1"
exit $?
''' )
    system_or_die( 'chmod +x %s/usr/local/bin/run_browser_as_guest.sh' % ( mountpoint ) )


def add_speech_synthesis_script( mountpoint ):
    write_oneliner_file( '%s/usr/local/bin/sayit.sh' % ( mountpoint ), '''#!/bin/sh
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
    write_lxdm_pre_login_file( '%s/etc/lxdm/PreLogin' % ( mountpoint ) )
    write_lxdm_post_logout_file( '%s/etc/lxdm/PostLogout' % ( mountpoint ) )
    write_lxdm_post_login_file( '%s/etc/lxdm/PostLogin' % ( mountpoint ) )
    write_login_ready_file( '%s/etc/lxdm/LoginReady' % ( mountpoint ) )
    append_lxdm_xresources_addendum( '%s/root/.Xresources' % ( mountpoint ) )
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
        do_a_sed( f, 'black=.*', 'black=root bin daemon mail ftp http uuidd dbus nobody systemd-journal-gateway systemd-timesync systemd-network avahi polkitd colord git rtkit freenet i2p lxdm tor privoxy' )
        do_a_sed( f, 'white=.*', 'white=guest' )
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
    logme( 'configure_lxdm_behavior --- leaving' )


def write_login_ready_file( fname ):
    write_oneliner_file( fname, '''#!/bin/sh
#. /etc/bash.bashrc
#. /etc/profile
export DISPLAY=:0.0
xset s off
xset -dpms
''' )


def configure_lxdm_service( mountpoint ):
    if 0 != chroot_this( mountpoint, 'systemctl enable lxdm', attempts = 1 ):
        if 0 != chroot_this( mountpoint, 'ln -sf /usr/lib/systemd/system/lxdm.service /etc/systemd/system/display-manager.service' ):
            failed( 'Failed to enable lxdm' )
    for f in ( 'lxdm', 'display-manager' ):
        if os.path.exists( '%s/usr/lib/systemd/system/%s.service' % ( mountpoint, f ) ):
            system_or_die( 'cp %s/usr/lib/systemd/system/%s.service /tmp/' % ( mountpoint, f ) )
#    if os.path.exists( '%s/usr/lib/systemd/system/lxdm.service' % ( mountpoint ) ):
    write_lxdm_service_file( '%s/usr/lib/systemd/system/lxdm.service' % ( mountpoint ) )
    chroot_this( mountpoint, 'which lxdm &> /dev/null', on_fail = 'I cannot find lxdm. This is not good.' )
    if chroot_this( mountpoint, 'which kdm &> /dev/null' ) == 0:
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
    write_oneliner_file( '%s' % ( iceweasel_path ), '''#!/bin/sh
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
    write_oneliner_file( '%s' % ( chrome_path ), '''#!/bin/sh
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
                    os.path.dirname( kernel_src_basedir ) + '/linux-[a-b,d-z]*'
                ):
        chroot_this( mountpoint, 'rm -Rf %s' % ( path ) )
#        if not os.path.exists( '%s%s' % ( mountpoint, kernel_src_basedir ) ):
#            failed( 'rm -Rf %s ==> deletes the linux-chromebook folder from the bootstrap OS. That is suboptimal' % ( path ) )

    # TODO: Consider %kernel_src_basedir/linux-chromebook/pkg/*
    chroot_this( mountpoint, 'ln -sf %s/src/chromeos-3.4 /usr/src/linux-3.4.0-ARCH' % ( kernel_src_basedir ) )
    chroot_this( mountpoint, 'set -e; cd /usr/share/locale; mv locale.alias ..' )
    chroot_this( mountpoint, 'set -e; cd /usr/share/locale; mkdir -p _; mv [a-d,f-z]* _; mv e[a-m,o-z]* _; rm -Rf _; mv ../locale.alias .' )
    chroot_this( mountpoint, 'set -e; cd /usr/share/locale; mv ../locale.alias .' )
    chroot_this( mountpoint, 'cd /usr/lib/firmware 2>/dev/null && cp s5p-mfc/s5p-mfc-v6.fw ../mfc_fw.bin && cp mrvl/sd8797_uapsta.bin .. && rm -Rf * && mkdir -p mrvl && mv ../sd8797_uapsta.bin mrvl/ && mv ../mfc_fw.bin .' )


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
    system_or_die( 'mkdir -p %s/etc/X11/xorg.conf.d/' % ( mountpoint ) )
    system_or_die( 'unzip %s/usr/local/bin/Chrubix/blobs/settings/x_alarm_chrubuntu.zip -d %s/etc/X11/xorg.conf.d/ &> /dev/null' % ( mountpoint, mountpoint, ), "Failed to extract X11 settings from Chrubuntu" )
    f = '%s/etc/X11/xorg.conf.d/10-keyboard.conf' % ( mountpoint )
    if not os.path.isfile( f ):
        failed( '%s not found --- cannot tweak X' % ( f ) )
    do_a_sed( f, 'gb', 'us' )
    system_or_die( 'mkdir -p %s/etc/tmpfiles.d' % ( mountpoint, ) )
    write_oneliner_file( mountpoint + '/etc/tmpfiles.d/touchpad.conf', "f /sys/devices/s3c2440-i2c.1/i2c-1/1-0067/power/wakeup - - - - disabled" )
    write_oneliner_file( mountpoint + '/usr/share/festival/festival.scm', '''
(Parameter.set 'Audio_Method 'Audio_Command)
(Parameter.set 'Audio_Command "aplay -q -c 1 -t raw -f s16 -r $SR $FILE")
''' )
#    chroot_this( mountpoint, 'systemctl enable i_run_every_minute.timer' )
    f = open( '%s/etc/X11/xorg.conf' % ( mountpoint ), 'a' )
    system_or_die( 'cp -f %s/usr/local/bin/Chrubix/blobs/apps/mtrack_drv.so %s/usr/lib/mtrack.so' % ( mountpoint, mountpoint ) )
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


def install_panicbutton( mountpoint, boomfname ):
#        print( "Configuring acpi" )
    system_or_die( 'mkdir -p %s/etc/tmpfiles.d' % ( mountpoint ) )
    write_oneliner_file( '%s/etc/tmpfiles.d/brightness.conf' % ( mountpoint ), \
                        'f /sys/class/backlight/pwm-backlight.0/brightness 0666 - - - 800' )
    powerbuttonpushed_fname = '/usr/local/bin/power_button_pushed.sh'
    write_oneliner_file( '%s%s' % ( mountpoint, powerbuttonpushed_fname ), '''#!/bin/sh
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
    write_oneliner_file( fname_out, '''#!/bin/sh
# If home partition, please unmount it & wipe it; also, delete its Dropbox key fragment.
# .... Yep. Here.
# Next, wipe all initial sectors
%s sync;sync;sync # :-)
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




def ask_the_user__temp_or_perm( mountpoint ):
    if os.path.exists( '/.temp_or_perm.txt' ):
#            logme( 'Found a temp_or_perm file that was created by sh file.' )
        r = read_oneliner_file( '/.temp_or_perm.txt' )
        if r == 'perm':
            res = 'P'
        elif r == 'temp':
            res = 'T'
        elif r == 'meh':
            res = 'M'
        else:
            failed( 'I do not understand this temp-or-mount file contents - %s' % ( r ) )
    else:
        print( '''Would you prefer a temporary setup or a permanent one? Before you choose, consider your options.

TEMPORARY: When you boot, you will see a little popup window that asks you about mimicking Windows XP,
spoofing your MAC address, etc. Whatever you do while the OS is running, nothing will be saved to disk.

PERMANENT: When you boot, you will be prompted for a password. No password? No access. The whole disk
is encrypted. Although you will initially be logged in as a guest whose home directory is on a ramdisk,
you have the option of creating a permanent user, logging in as that user, and saving files to disk.
In addition, you will be prompted for a 'logging in under duress' password. Pick a short one.

MEH: No encryption. No duress password. Changes are permanent. Guest Mode still exists, though.

''' )
        res = 999
        while res != 'T' and res != 'P' and res != 'M':
            res = input( "(T)emporary, (P)ermanent, or (M)eh ? " ).strip( '\r\n\r\n\r' ).replace( 't', 'T' ).replace( 'p', 'P' ).replace( 'm', 'M' )
        if res == 'T':
            write_oneliner_file( '%s/.temp_or_perm.txt' % ( mountpoint ), 'temp' )
        elif res == 'P':
            write_oneliner_file( '%s/.temp_or_perm.txt' % ( mountpoint ), 'perm' )
        else:
            write_oneliner_file( '%s/.temp_or_perm.txt' % ( mountpoint ), 'meh' )
    return res

def add_user_to_the_relevant_groups( username, distro_name, mountpoint ):
    for group_to_add_me_to in ( '%s' % ( 'debian-tor' if distro_name == 'debian' else 'tor' ), 'freenet', 'audio', 'pulse-access', 'users' ):
        logme( 'Adding %s to %s' % ( username, group_to_add_me_to ) )
        if group_to_add_me_to != 'pulse-access' and 0 != chroot_this( 
                                    mountpoint, 'usermod -a -G %s %s' % ( group_to_add_me_to, username ) ):
            failed( 'Failed to add %s to group %s' % ( username, group_to_add_me_to ) )


def ask_the_user__guest_mode_or_user_mode__and_create_one_if_necessary( distro_name, mountpoint ):
    success = False
    while not success:
        user_name = input( "Short, one-word name of your default user (or press Enter for guest): " ).strip()
        if user_name == '' or user_name == 'guest':
            return 'guest'
        try:
#            print( 'Calling useradd %s => mountpoint=%s' % ( user_name, mountpoint ) )
            chroot_this( mountpoint, 'useradd %s' % ( user_name ) )
            success = True
        except ( IOError, RuntimeError ):
            print( 'Failed to create user %s' % ( user_name ) )
            continue
    success = False
    while not success:
        try:
            chroot_this( mountpoint, 'passwd %s' % ( user_name ) )
            success = True
        except ( IOError, RuntimeError ):
            continue
    system_or_die( 'mkdir -p %s/home/%s' % ( mountpoint, user_name ) )
    add_user_to_the_relevant_groups( user_name, distro_name, mountpoint )
    system_or_die( 'tar -Jxf /usr/local/bin/Chrubix/blobs/settings/default_guest_files.tar.xz -C %s/home/%s' % ( mountpoint, user_name ) )
    for stub in ( '.gtkrc-2.0', '.config/chromium/Default/Preferences', '.config/chromium/Local State' ):
        do_a_sed( '%s/home/%s/%s' % ( mountpoint, user_name, stub ), '/tmp/.guest', '/home/%s' % ( user_name ) )
#    assert( 0 != os.system( 'fgrep -rnl /tmp/.guest %s/home/%s/.[a-z]*' % ( mountpoint, user_name ) ) )
    chroot_this( mountpoint, 'chown -R %s.users /home/%s' % ( user_name, user_name ) )
    chroot_this( mountpoint, 'chmod -R 700 /home/%s' % ( user_name ) )
    return user_name

