#!/usr/local/bin/python3
#
# utils.py


'''
Created on May 1, 2014

'''


import re
import os
import subprocess
import string
import random
import time
import sys
import crypt
import logging
import chrubix


g_proxy = None  # if ( 0 != os.system( 'ifconfig | grep inet | fgrep 192.168.0 &> /dev/null' ) or 0 != os.system( 'cat /proc/cmdline | grep dm_verity &> /dev/null' ) ) else '192.168.0.106:8080'
g_default_window_manager = '/usr/bin/startlxde'  # wmaker, startxfce4, startlxde, ...


MAXIMUM_COMPRESSION = False  # True  # Max compression on the left; quicker testing on the right :)
__g_start_time = time.time()


def abort_if_make_is_segfaulting( mountpoint ):
    if 0 == chroot_this( mountpoint, 'which make &> /dev/null', attempts = 1 ):
        res = chroot_this( mountpoint, 'make', attempts = 1 )
        if res == 2:
            logme( 'make returned %d -- cool!' % ( res ) )
        else:
            failed( 'make returned %d -- not cool, brah' % ( res ) )


def logme( message = None ):
    datestr = call_binary( ['date'] )[1].strip()
    handle = open ( '/tmp/chrubix.log', 'a' )
    handle.write( '%s %s\n' % ( datestr, message ) )
    handle.close()
    os.system( 'chmod 777 /tmp/chrubix.log &> /dev/null' )


def is_this_bindmounted( mountpoint ):
    fname = '.flibbertyjibbet'
    os.system( 'touch %s/%s' % ( mountpoint, fname ) )
    found_it = os.path.exists( fname )
    os.unlink( '%s/%s' % ( mountpoint, fname ) )
    if found_it:
        return True
    else:
        return False


def call_binary_and_show_progress( binary_info, title_str, foot_str, status_lst, trim_output = False, pauses_len = 5 ):
    '''
    binary_info:    e.g. ['ls','-l','/tmp']
    title_str:      e.g. 'This is the title'
    status_lst:     e.g. ['First line', 'Second line, '..and so on']
    '''
    import urwid
    max_height = 28
    output_widget = urwid.Text( '' )
    status_lst = [''] + status_lst + ['']  #  # + ''.join( [r + ' ' for r in binary_info ]
    content = [ urwid.Text( r ) for r in status_lst ]
#    content.append( urwid.Text( "%s" % ( ''.join( [r + ' ' for r in binary_info ] ) ) ) )
    content.append( output_widget )

    header = urwid.AttrWrap( urwid.Text( title_str, align = 'center' ), 'header' )
    footer = urwid.AttrWrap( urwid.Text( foot_str, align = 'center' ), 'footer' )
    how_many_lines = max_height - len( status_lst )

    for r in range( len( status_lst ) ):
        s = status_lst[r]
        while len( s ) > 110:
            s = s[115:]
            how_many_lines -= 1  # allow for word wrap :)  ...clumsy & inaccurate, but it'll do

    listbox = urwid.ListBox( content )
    view = urwid.AttrWrap( listbox, 'body' )
    frame_widget = urwid.Frame( view, header = header, footer = footer )
    make_an_alarm = lambda : loop.set_alarm_in( pauses_len, call_me )
    lower_limit = 25 if trim_output else 10

    def exit_on_enter( key ):
        if key == 'enter': raise urwid.ExitMainLoop()

    loop = urwid.MainLoop( frame_widget, unhandled_input = exit_on_enter )
    def received_output( data ):
        old_lst = output_widget.text.split( '\n' )
        try:
            new_data = data.decode( 'utf-8' ).strip( ' .\r\n' ).strip()
        except UnicodeDecodeError:
            new_data = '(unicode error)'
        new_lst_A = [ r.strip( '. \r\n' ) for r in new_data.replace( '\r', '\n' ).split( '\n' ) if len( r.strip() ) >= lower_limit]
        new_lst = []
        for r in [ s.strip() for s in new_lst_A]:
            if r not in new_lst and r != '':
                new_lst.append( r )
#        if not trim_output:
        full_lst = old_lst + new_lst
        last_N_lines_of_lst = full_lst[-how_many_lines:]
        output_text = ''.join( [ r + '\n' for r in last_N_lines_of_lst ] )
        if output_text not in ( None, '' ):
            while output_text[-1] in ( '\r\n' ):
                output_text = output_text[:-1]
                if len( output_text ) == 0:
                    break
        if status_lst is not None:
            current_time = time.time()
            time_taken = current_time - __g_start_time
            s = 'Time taken so far: %02d:%02d:%02d' % ( time_taken // 3600, ( time_taken // 60 ) % 60, time_taken % 60 )
            frame_widget.footer = urwid.AttrWrap( urwid.Text( s, align = 'center' ), 'footer' )
            output_widget.set_text( output_text )
    def call_me( x, y ):
        x = x  # stop Eclipse warning
        y = y  # stop Eclipse warning
        if proc.poll() is not None:
            raise urwid.ExitMainLoop
        make_an_alarm()

    write_fd = loop.watch_pipe( received_output )
    proc = subprocess.Popen( 
#        ['find', '/Volumes/HMR3T/Video', '-type', 'f'],
        binary_info,
        stdout = write_fd,  # None if 'pacman' in str( binary_info ) else write_fd,
        stderr = write_fd,  # if 'pacman' in str( binary_info ) else None,
        close_fds = True )

    make_an_alarm()
    loop.run()
#    logme( 'call_binary_and_show_progress() is returning' )
    return proc.poll()
#    proc.kill()


def wget( url, save_as_file = None, extract_to_path = None, decompression_flag = None, quiet = False, title_str = None, status_lst = None, attempts = 5 ):
    attempt_number = 0
    while attempt_number < attempts:
        extra_params = '-e use_proxy=yes -e http_proxy=' + g_proxy if g_proxy is not None and attempt_number == 0 else''
        extra_params += ' --quiet' if quiet else ''
        if save_as_file and not extract_to_path:
            system_or_die( 'mkdir -p %s' % ( os.path.dirname( save_as_file ) ) )
            cmd = 'wget %s %s -O %s' % ( extra_params, url, save_as_file )
#            logme( 'cmd = %s' % ( cmd ) )
        elif extract_to_path and not save_as_file:
            system_or_die( 'mkdir -p %s' % ( extract_to_path ) )
            if decompression_flag not in ( 'J', 'z' ):
                raise SyntaxError( 'Specify compression flag: J for xz, z for gzip' )
            cmd = 'wget %s %s -O - | tar -%s -C %s' % ( extra_params, url, decompression_flag + 'x', extract_to_path )
#            logme( 'cmd = %s' % ( cmd ) )
            if decompression_flag not in ( 'J', 'z' ):
                raise SyntaxError( 'Are you sure %s is a valid decompression flag?' % ( decompression_flag ) )
        else:
            cmd = None
            raise SyntaxError( 'wget must either save a file or extract to path. You specified neither/both.' )
        res = chroot_this( mountpoint = '/', cmd = cmd, title_str = title_str, status_lst = status_lst )
        if res == 0:
            logme( 'wget => %s => successful' % ( cmd ) )
            return res
        else:
#            logme( "Retrying" )
            os.system( 'sync;sync;sync;sleep 1' )
        attempt_number += 1
    raise SystemError( "Failed to run '%s'" % ( cmd ) )


def failed( s, exception = None ):
    print( s )
    if exception is None:
        raise RuntimeError( s )
    else:
        raise exception( s )
#    sys.exit( 1 )  # We never reach this line


def write_oneliner_file( fname, value = '' ):
    if os.path.isdir( fname ):
        raise SyntaxError( '%s is a directory; you cannot write a one-liner file to it' % ( fname ) )
#    if os.path.isfile( fname ):
#        logme( "Deleting %s before writing it" % ( fname ) )
#        os.unlink( fname )
    f = open( fname, 'w' )  # IDGAF if you think I should use 'wb'
    f.write( value )
    f.close()


def read_oneliner_file ( fname ):
    f = open( fname, 'r' )  # IDGAF if you think I should use 'rb'
    value = f.readline().strip( '\n\r\n\r\n' )
    return value


def rootcryptdevice():
    f = open( '/proc/cmdline', 'rb' )
    cmdline = f.readline().strip( '\n\r\n' )
    f.close()
    return cmdline[cmdline.find( 'cryptdevice=' ):].split( ' ' )[0].split( ':' )[0].split( '=' )[1]


def call_binary( func_call ):
    result = 0
    assert( type( func_call ) is list )  # e.g. ['ls','-f','/dev']
    try:
        result = subprocess.check_output( func_call, stderr = subprocess.STDOUT )
        return ( 0, result )
    except subprocess.CalledProcessError as e:
        return ( e.returncode, result )  # errno, result


def mount_device( device, mountpoint ):
    cmd = 'mount -o noatime ' + device + ' ' + mountpoint
    logme( 'mount_device(%s,%s) ==> cmd=%s' % ( device, mountpoint, cmd ) )
    if 0 != os.system( cmd ):
        if 0 != os.system( cmd ):
            failed( 'Failed to ' + cmd )
    logme( 'mount_device() --- success?' )
    if os.system( 'mount | fgrep " %s " &>/dev/null' % ( mountpoint ) ) != 0:
        failed( 'Nope. Failure.' )
    logme( 'mount_device() --- success. Yay.' )


def mount_sys_tmp_proc_n_dev( mountpoint, force = False ):  # Consider combining or using mount_device() ...?
    for mydir, dtype in ( ( 'dev', 'devtmpfs' ), ( 'proc', 'proc' ), ( 'tmp', 'tmpfs' ), ( 'sys', 'sysfs' ) ):
        where_to_mount_it = '%s/%s' % ( mountpoint, mydir )
        os.system( 'mkdir -p %s' % ( where_to_mount_it ) )
        if force or ( os.system( 'mount | grep " %s " &> /dev/null' % ( where_to_mount_it ) ) != 0 ):
            cmd = 'mount %s %s -t %s' % ( dtype, where_to_mount_it, dtype )
            if os.system( cmd ) != 0:
                failed ( 'Failed to ' + cmd )


def unmount_sys_tmp_proc_n_dev( mountpoint ):
    os.system( 'umount %s/{tmp,proc,sys,dev} 2> /dev/null' % ( mountpoint ) )
    os.system( 'sync;sync;sync 2> /dev/null' )
    os.system( 'umount %s/{tmp,proc,sys,dev} 2> /dev/null' % ( mountpoint ) )
    os.system( 'sync;sync;sync 2> /dev/null' )
    os.system( 'umount %s/dev %s/proc %s/tmp %s/sys 2> /dev/null' % ( mountpoint, mountpoint, mountpoint, mountpoint ) )
    os.system( 'sync;sync;sync' )
    os.system( 'umount %s/dev %s/proc %s/tmp %s/sys 2> /dev/null' % ( mountpoint, mountpoint, mountpoint, mountpoint ) )
    os.system( 'sync;sync;sync' )
    os.system( 'umount %s' % ( mountpoint ) )


def generate_temporary_filename( dirpath = None ):
    dp = '' if dirpath is None else dirpath + '/'
    return '%s%s' % ( dp , ''.join( random.choice( string.ascii_uppercase + string.digits ) for _ in range( 10 ) ) )


def system_or_die( cmd, errtxt = None, title_str = None, status_lst = None ):
#    logme( 'system_or_die => %s' % ( cmd ) )
    if title_str is not None and status_lst is not None:
        res = chroot_this( '/', cmd, title_str = title_str, status_lst = status_lst )
    else:
        res = os.system( cmd )
    if res != 0:
        logme( 'system_or_die(%s) is returning w/ res=%d' % ( cmd, res ) )
        if errtxt is None:
            failed( '%s failed\nres=%d' % ( cmd, res ) )
        else:
            failed( '%s failed\n%s\nres=%d' % ( cmd, errtxt, res ) )
        os.system( 'clear' )
#        logme( "%s failed" % ( cmd, ) )
    return res


def chroot_this( mountpoint, cmd, on_fail = None, attempts = 3, title_str = None, status_lst = None, pauses_len = 1, user = 'root' ):
#    logme( 'chroot_this (%s) ==> %s' % ( mountpoint, cmd ) )
    proxy_info = '' if g_proxy in ( None, '' ) else 'export http_proxy=http://%s;' % ( g_proxy )
    my_executable_script = generate_temporary_filename( '/tmp' )
    if not os.path.isdir( mountpoint ):
        failed( '%s not found --- are you sure the chroot is operational?' % ( mountpoint ) )
    f = open( mountpoint + my_executable_script, 'wb' )
    outstr = '#!/bin/bash\n%s\n%s\nexit $?\n' % ( proxy_info, cmd )
    if os.path.exists( mountpoint + '/bin/sh' ) and not os.path.exists( mountpoint + '/bin/bash' ):
        failed( 'That is wrong. There is /bin/sh but not /bin/bash. Ugh.' )
    f.write( outstr.encode( 'utf-8' ) )
    f.close()
    system_or_die( 'chmod 777 %s' % ( mountpoint + my_executable_script ) )
    system_or_die( 'chmod +x %s' % ( mountpoint + my_executable_script ) )
#    logme( 'chroot_this() --- calling %s' % ( cmd ) )
    for att in range( attempts ):
        att = att  # hide Eclipse warning
        if title_str is not None or status_lst is not None:
            res = call_binary_and_show_progress( binary_info = ['chroot', mountpoint, my_executable_script], title_str = title_str, foot_str = cmd, status_lst = status_lst,
                                                 trim_output = True if 'wget' in cmd else False,
                                                 pauses_len = pauses_len )
        else:
            if user == 'root':
                res = os.system( 'chroot %s %s' % ( mountpoint, my_executable_script ) )
            elif mountpoint in ( '/', None ):  # build within alarpy, NOT within final distro
                res = os.system( 'chroot --userspec=%s %s %s' % ( user, '/', my_executable_script ) )
            else:
                res = os.system( 'chroot --userspec=%s %s %s' % ( user, mountpoint, my_executable_script ) )
        if res == 0:
            break
        else:
            os.system( 'sync;sync;sync' )
            time.sleep( pauses_len )
    if res != 0 and on_fail is not None:
        failed( '%s chroot in %s of "%s" failed after several attempts; %s' % ( proxy_info, mountpoint, cmd, on_fail ) )
#    if os.path.exists( mountpoint + my_executable_script ):
    os.unlink( mountpoint + my_executable_script )
    os.system( 'sync;sync;sync' )
    logme( 'chroot("%s") is returning w/ res=%d' % ( cmd, res ) )
    return res



def backup_the_resolvconf_file( mountpoint ):
    import shutil
    if not os.path.exists( mountpoint + '/etc/resolv.conf.pristine' ):
        os.rename( mountpoint + '/etc/resolv.conf', mountpoint + '/etc/resolv.conf.pristine' )
    shutil.copy( '/etc/resolv.conf', mountpoint + '/etc/resolv.conf' )
    os.system( 'echo nameserver 8.8.8.8 >> %s/etc/resolv.conf' % ( mountpoint ) )


def do_a_sed( filename, replace_me, with_this ):
    with open( filename, "r" ) as sources:
        lines = sources.readlines()
    with open( filename, "w" ) as sources:
        for line in lines:
            sources.write( re.sub( replace_me, with_this, line ) )


def fix_broken_hyperlinks( dir_to_fix ):
    contents = [ f for f in os.listdir( dir_to_fix ) ]
    for filename in contents:
        if not os.path.isdir( '%s/%s' % ( dir_to_fix, filename ) ) and os.path.exists( os.readlink( '%s/%s' % ( dir_to_fix, filename ) ) ):
    #        print('%s is broken' % (filename))
            if os.path.exists( '%s/../%s' % ( dir_to_fix, filename ) ):
                system_or_die( 'ln -sf ../%s %s/%s' % ( filename, dir_to_fix, filename ) )
            else:
                raise IOError( 'Unable to fix %s/%s' % ( dir_to_fix, filename ) )

def patch_kernel( mountpoint, folder, url ):
    tmpfile = generate_temporary_filename( '/tmp' )
    wget( url = url, save_as_file = '%s%s' % ( mountpoint, tmpfile ), quiet = True )
    if url[-3:] == '.gz':
        system_or_die( 'mv %s%s %s%s.gz' % ( mountpoint, tmpfile, mountpoint, tmpfile ) )
        system_or_die( 'gunzip %s%s.gz' % ( mountpoint, tmpfile ) )
    if not os.path.isdir( '%s%s' % ( mountpoint, folder ) ):
        failed( 'This should be a directory but it is not one. ==> %s%s' % ( mountpoint, folder ) )
    assert( os.path.isfile( '%s%s' % ( mountpoint, tmpfile ) ) )
    if 0 != chroot_this( mountpoint, 'patch -p1 --no-backup-if-mismatch -d %s < %s' % ( folder, tmpfile ), attempts = 1 ):
        failed( 'Failed to apply %s patch to kernel.' % ( url ) )


def set_user_password( login, password, mountpoint = '/' ):
#!/usr/bin/env python
    i = None
    r = i  # ...to prevent annoying 'i not used' warning.
    ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    salt = ''.join( random.choice( ALPHABET ) for i in range( 8 ) )
    shadow_password = crypt.crypt( password, '$1$' + salt + '$' )
    if mountpoint == '/':
        r = subprocess.call( ( 'usermod', '-p', shadow_password, login ) )
    else:
        r = chroot_this( mountpoint, "usermod -p '%s' %s" % ( shadow_password, login ) )
    if r != 0:
        failed( 'Failed to set password for %s' % ( login ) )


def disable_root_password( mountpoint ):
    chroot_this( mountpoint, 'passwd -l root' )  # Disable root password entirely


def write_spoof_script_file( my_spoof_script_fname ):  # Typically, this is used by Alarmist only.
    write_oneliner_file( my_spoof_script_fname, '''#!/bin/bash
IF=$1
STATUS=$2

wait_for_process() {
  PNAME=$1
  PID=`/usr/bin/pgrep $PNAME`
  while [ -z "$PID" ]; do
        sleep 3;
        PID=`/usr/bin/pgrep $PNAME`
  done
}

if [ "$IF" = "mlan0" ] || [ "$IF" = "wlan0" ] ; then
    if [ "$STATUS" = "up" ]; then
        macchanger -e $IF            # vendor remains the same
    else
        macchanger -r $IF            # random vendor
    fi
fi
        ''' )
    system_or_die( 'chmod +x %s' % ( my_spoof_script_fname ) )


def enable_xfce_theme( theme_name ):
    system_or_die( 'xfconf-query -c xsettings -p /Net/ThemeName -s "%s"' % ( theme_name ) )


def install_windows_xp_theme_stuff( mountpoint ):
    my_temp_dir = '%s/tmp/.luna.tmp' % ( mountpoint )
    system_or_die( 'mkdir -p %s' % ( my_temp_dir ) )
    system_or_die( 'tar -zxf %s/usr/local/bin/Chrubix/blobs/xp/tails-xp.tgz -C %s' % ( mountpoint, mountpoint ) )
    system_or_die( 'tar -zxf %s/usr/local/bin/Chrubix/blobs/xp/linux_xp_luna_theme_install.tar.gz -C %s &> /dev/null' % ( mountpoint, my_temp_dir ) )
    for area in ( 'icons', 'themes' ):
        system_or_die( 'cp -af %s/%s/Luna %s/usr/share/%s/' % ( my_temp_dir, area, mountpoint, area ) )
    system_or_die( 'cp -af %s/usr/share/icons/GnomeXP/* %s/usr/share/icons/Luna/' % ( mountpoint, mountpoint ) )
    system_or_die( 'cp -af %s/usr/share/icons/GnomeXP/* %s/usr/share/icons/Luna/' % ( mountpoint, mountpoint ) )
    system_or_die( 'cp -f %s/luna_background.jpg %s/usr/share/backgrounds/mate/desktop/' % ( my_temp_dir, mountpoint ) )
    # Install XP themes for OpenBox and Gtk
    system_or_die( 'yes "" 2> /dev/null | unzip -o %s/usr/local/bin/Chrubix/blobs/xp/162880-XPTheme.zip -d %s/usr/share/themes &>/dev/null' % ( mountpoint, mountpoint ) )
    for icon_theme in ( 'GnomeXP', 'Luna' ):
        for res_num in ( 22, 24, 48 ):
            resolution = '%dx%d' % ( res_num, res_num )
            system_or_die( 'cp -f %s/usr/share/themes/XPLuna/start.png %s/usr/share/icons/%s/%s/places/start-here.png' % ( mountpoint, mountpoint, icon_theme, resolution ) )
    for res_num in ( 24, 32, 48, 64 ):
        resolution = '%dx%d' % ( res_num, res_num )
        system_or_die( 'cp %s/usr/share/icons/GnomeXP/48x48/apps/iceweasel.png %s/usr/share/icons/hicolor/%s/apps/chromium.png' % ( mountpoint, mountpoint, resolution ) )
    chroot_this( mountpoint, 'mv -f /usr/share/backgrounds/mate/desktop/luna_background.jpg /usr/share/backgrounds/mate/desktop/luna_background_orig.jpg' )
    chroot_this( mountpoint, 'cp -f /usr/local/bin/Chrubix/blobs/xp/win7_wallpaper.jpg /usr/share/backgrounds/mate/desktop/luna_background.jpg' )


def install_mp3_files( mountpoint ):
    mydir = '%s/etc/.mp3' % ( mountpoint )
    system_or_die( 'mkdir -p %s' % ( mydir ) )
    for myname in ( 'boom', 'error1', 'error2', 'MacStartUp', 'online', 'pg2back', 'pgclean', 'pghere', 'welcome', 'wrongCB', 'winxp', 'wrongSD', 'xpshutdown' ):
        system_or_die( 'cp -f %s/usr/local/bin/Chrubix/blobs/audio/%s.mp3.gz %s/' % ( mountpoint, myname, mydir ) )
        system_or_die( 'gunzip -f %s/%s.mp3.gz 2> /dev/null' % ( mydir, myname ) )


def poweroff_now():
    for ( val, fname ) in ( 
                         ( '3', '/proc/sys/kernel/printk' ),
                         ( '3', '/proc/sys/vm/drop_caches' ),
                         ( '256', '/proc/sys/vm/min_free_kbytes' ),
                         ( '1', '/proc/sys/vm/overcommit_memory' ),
                         ( '1', '/proc/sys/vm/oom_kill_allocating_task' ),
                         ( '0', '/proc/sys/vm/oom_dump_tasks' ),
                         ( '1', '/proc/sys/kernel/sysrq' ),
                         ( 'o', '/proc/sysrq-trigger' )
                         ):
        write_oneliner_file( fname, val )  # See http://major.io/2009/01/29/linux-emergency-reboot-or-shutdown-with-magic-commands/


def patch_org_freedesktop_networkmanager_conf_file( config_file, patch_file ):
    if os.path.exists( '%s.orig' % ( config_file ) ):
        system_or_die( 'cp -f %s.orig %s' % ( config_file, config_file ) )
    else:
        system_or_die( 'cp -f %s %s.orig' % ( config_file, config_file ) )
#    failed( 'nefarious porpoises' )
    assert( os.path.exists( config_file ) )
    assert( os.path.exists( patch_file ) )
    cmd = 'cat %s | gunzip | patch -p1 %s' % ( patch_file, config_file )
    return os.system( cmd )


def call_makepkg_or_die( cmd, mountpoint, package_path, errtxt ):
    my_user = 'nobody'  # git
    gittify_this_folder = package_path[:package_path.rfind( '/root' ) + 5]
    logme( 'gittifying %s' % ( gittify_this_folder ) )
    chroot_this( mountpoint, r'mkdir -p %s' % ( package_path ) )
    chroot_this( mountpoint, r'chown -R %s %s' % ( my_user, gittify_this_folder ) )
    chroot_this( mountpoint, r'chmod -R 777 %s' % ( gittify_this_folder ) )
    chroot_this( mountpoint, r'chmod 777 /dev/null' )
    res = chroot_this( mountpoint, cmd, user = my_user, attempts = 1 )
#    if not os.path.exists( '%s/PKGBUILD' % ( package_path ) ):
#        failed( 'PKGBUILD is not present in dest path' )
    if res != 0:
        chroot_this( mountpoint, r'pacman-db-upgrade', attempts = 1 )
        res = chroot_this( mountpoint, cmd, user = my_user )
        if res != 0:
            failed( "call_makepkg_or_die(mountpoint='%s',cmd='%s',package_path='%s' failed ==> %s => res=%d" % ( mountpoint, cmd, package_path, errtxt, res ) )
    chroot_this( mountpoint, r'chown -R root %s' % ( gittify_this_folder ) )
    chroot_this( mountpoint, r'chmod -R 700 %s' % ( gittify_this_folder ) )
    return res


def remaining_megabytes_free_on_device( dev ):  # FIXME broken
    lst = call_binary( ['df', '-m', dev] )[1].decode( 'utf-8' ).split( '\n' )
    possible_candidates = [ s for s in lst if s.rfind( dev ) >= 0]
    if possible_candidates in ( None, [] ):
        failed( 'Unable to find %s remaining space' % ( dev ) )
    else:
        this_one = possible_candidates[0].replace( '  ', ' ' ).replace( '  ', ' ' ).replace( '  ', ' ' ).replace( '  ', ' ' ).replace( '  ', ' ' )
        res = this_one.split( ' ' )[3]
        logme( '%s has %s MB remaining' % ( dev, res ) )
        try:
            return int( res )
        except ( TypeError, SyntaxError ):
            failed( 'Unable to return %s' % str( res ) )


def check_sanity_of_distro( mountpoint, kernel_src_basedir ):
    flaws = 0
    broken_pkgs = ''
    if not os.path.exists( '/usr/local/bin/Chrubix' ):
        failed( 'Someone deleted Chrubix folder. #15' )
    system_or_die( 'chmod +x %s/usr/local/*' % ( mountpoint ) )  # Shouldn't be necessary... but it is. For some reason, greeter.sh and CHRUBIX aren't executable. Grr.
    assert( os.path.exists( '%s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( mountpoint, kernel_src_basedir ) ) )
    for executable_to_find in ( 
                                'startlxde', 'lxdm', 'wifi_auto.sh', 'wifi_manual.sh', \
                                'chrubix.sh', 'mkinitcpio', 'dtc', 'wmsystemtray', 'florence', \
                                'pidgin', 'gpgApplet', 'macchanger', 'gpg', 'chrubix.sh', 'greeter.sh', \
                                'dropbox_uploader.sh', 'power_button_pushed.sh', \
                                'sayit.sh', 'vidalia', 'i2prouter', 'claws-mail', \
                                'CHRUBIX', 'libreoffice', 'ssss-combine', 'ssss-split', 'dillo'
                              ):
        if chroot_this( mountpoint, 'which %s &> /dev/null' % ( executable_to_find ), attempts = 1 ):
            broken_pkgs += '%s ' % ( executable_to_find )
            flaws += 1
    logme( "This sanity-checker is incomplete. Please improve it." )
    return broken_pkgs




def migrate_to_obfuscated_filesystem( distro ):
    failed( 'migrate_to_obfuscated_filesystem() -- nefarious porpoises' )
    os.system( 'clear' )
    if distro.status_lst not in ( None, [] ) and len( distro.status_lst ) > 1:
        distro.status_lst = distro.status_lst[-1:]
    distro.update_status_with_newline( '*** %s ***' % ( distro.hewwo ) )
    distro.update_status_with_newline( 'Welcome back!' )
    distro.update_status_with_newline( '****************************************************************************************' )
    distro.update_status_with_newline( 'Migrating from a temporary system to an encrypted, permanent system...' )
    distro.pheasants = True  # HOWEVER, we don't want to modify the sources! If we do that, we lose our existing magic#.
    distro.kthx = True  # HOWEVER....., we don't want to modify the sources! If we do that, we lose our existing magic#.
    distro.initrd_rebuild_required = True
    assert( os.path.exists( '%s/etc/.randomized_serno' % ( distro.mountpoint ) ) )
    system_or_die( 'rm -f %s%s/core/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( distro.mountpoint, distro.kernel_src_basedir ) )
    for cmd in ( 
                    'mkdir -p %s' % ( distro.sources_basedir ),
                    'mkdir -p /tmp/shoopwhoop',
                    'mount %s /tmp/shoopwhoop' % ( distro.root_dev ),
                    'tar -Jxf /tmp/shoopwhoop/.mkfs.tar.xz -C /',
                    'umount /tmp/shoopwhoop',
                    '''
FSTYPE="blah"
while [ "$FSTYPE" != "ext4" ] && [ "$FSTYPE" != "btrfs" ] && [ "$FSTYPE" != "xfs" ] && [ "$FSTYPE" != "jfs" ] ; do
    echo -en "Your filesystem may use ext4, xfs, jfs, or btrfs. (btrfs=best!) Please choose. => "
    read FSTYPE
done
echo $FSTYPE > %s/.cryptofstype
''' % ( distro.mountpoint )
                    ):
        chroot_this( distro.mountpoint, cmd, on_fail = 'Failed to run %s' % ( cmd ) )
    distro.crypto_filesystem_format = read_oneliner_file( '%s/.cryptofstype' % ( distro.mountpoint ) )
    new_mtpt = '/tmp/_enc_root'
    distro.set_root_password()
    distro.configure_guestmode_prior_to_migration()
# NOOO!  system_or_die( 'rm -f /.squashfs.sqfs %s/.squashfs.sqfs' % ( distro.mountpoint ) )    # NOOO! What if we're RUNNING LIVE?!
    distro.lxdm_settings['use greeter gui'] = False
    chrubix.save_distro_record( distro_rec = distro, mountpoint = distro.mountpoint )
    distro.migrate_all_data( new_mtpt )  # also mounts new_mtpt and rejigs kernel
    mount_sys_tmp_proc_n_dev( new_mtpt, force = True )
#        distro.mountpoint = new_mtpt
    distro.update_status( 'PKGBUILDs' )
    for cmd in ( 
                    'mkdir -p %s' % ( distro.sources_basedir ),
                    'mkdir -p /tmp/whoopshoop',
                    'mount %s /tmp/whoopshoop' % ( distro.root_dev ),
# FIXME comment out the next line & see what happens
                    'tar -Jxf /tmp/whoopshoop/.PKGBUILDs.tar.xz -C %s' % ( distro.ryo_tempdir ),
                    'tar -Jxf /tmp/whoopshoop/.PKGBUILDs.additional.tar.xz -C %s' % ( distro.ryo_tempdir ),
# FIXME comment out the next 19 lines & see what happens
                    '''
cd %s
errors=0
for ddd in `find *fs* -maxdepth 1 -mindepth 1 -type d | grep fs`; do
    echo ddd=$ddd >> /tmp/chrubix.log
    cd $ddd
    if [ -e "Makefile" ] ; then
        if make ; then
            if make install ; then
                echo $ddd=OK >> /tmp/chrubix.log
            else
                errors=$(($errors+10))
            fi
        else
            errors=$(($errors+1))
        fi
    fi
    cd ../..
done
exit $errors
''' % ( distro.sources_basedir ),
                    'cp -f /tmp/whoopshoop/.*gz /tmp/',
                    'cp -f /tmp/whoopshoop/.*gz /'
                    ):
        chroot_this( new_mtpt, cmd, on_fail = 'Failed to run %s' % ( cmd ), status_lst = distro.status_lst, title_str = distro.title_str, attempts = 1 )
        distro.update_status( '.' )
# Were the binaries installed?
    for looking_for_cmd in ( 'mkfs.xfs', 'jfs_mkfs', 'mkfs.btrfs' ):
        if 0 != os.system( 'which %s 2> /dev/null' % ( looking_for_cmd ), attempts = 1 ):
            failed( 'Unable to locate %s in current filesystem, even though I rebuilt it a moment ago.' % ( looking_for_cmd ) )
    system_or_die( 'cp -f %s/tmp/whoopshoop/.*gz /tmp/' % ( new_mtpt ) )
    distro.redo_mbr_for_encrypted_root( new_mtpt )
    chrubix.save_distro_record( distro_rec = distro, mountpoint = new_mtpt )  # save distro record to new disk (not old mountpoint)
    distro.update_status_with_newline( '5. Reboot!' )
    try:
        os.system( 'umount %s/%s/tmp/whoopshoop' % ( distro.mountpoint, new_mtpt ) )
        unmount_sys_tmp_proc_n_dev( new_mtpt )
        os.system( 'umount %s/%s' % ( distro.mountpoint, new_mtpt ) )
        if distro.mountpoint != '/':
            unmount_sys_tmp_proc_n_dev( distro.mountpoint )
    except ( SystemError, SyntaxError ):
        pass
    os.system( 'cryptsetup luksClose %s' % ( os.path.basename( distro.crypto_rootdev ) ) )
    os.system( 'clear; echo "Press ENTER and reboot.; read line' )
    failed( 'Reboot now.' )
    os.system( 'sync;sync;sync; reboot' )


def create_impatient_wrapper( mountpoint, name_of_binary ):
    path_and_fname = '/sbin/%s' % ( name_of_binary )
    if not os.path.exists( path_and_fname ):
        path_and_fname = '/usr/sbin/%s' % ( name_of_binary )
        if not os.path.exists( path_and_fname ):
            failed( 'create_impatient_wrapper() -- unable to find %s' % ( name_of_binary ) )
    system_or_die( 'mv %s%s %s%s.therealthing' % ( mountpoint, path_and_fname, mountpoint, path_and_fname ) )
    write_oneliner_file( path_and_fname, '''#!/bin/sh
%s &
sudo %s &
sleep 20
# copied from poweroff_now()
sync;sync;sync
echo 3   > /proc/sys/kernel/printk
echo 3   > /proc/sys/vm/drop_caches
echo 256 > /proc/sys/vm/min_free_kbytes
echo 1   > /proc/sys/vm/overcommit_memory
echo 1   > /proc/sys/vm/oom_kill_allocating_task
echo 0   > /proc/sys/vm/oom_dump_tasks
echo 1   > /proc/sys/kernel/sysrq
echo o   > /proc/sysrq-trigger

exit 0
''' % ( path_and_fname, path_and_fname ) )
    system_or_die( 'chmod +x %s%s' % ( mountpoint, path_and_fname ) )


def field_value( big_chunk, field_name ):
#    print( 'Looking for %s' % ( field_name ) )
    big_list = big_chunk.split( '\n' )
    res = ''
#    print( 'It is now split up...' )
    try:
        relevant_line = [r for r in big_list if r.find( field_name ) >= 0][-1]
        res = relevant_line.split( ':' )[-1].strip( ' ' )
    except IndexError:
        res = ''
        print( 'Unable to find %s in %s' % ( field_name, big_list ) )
#    print( 'Relevant line = %s' % ( relevant_line ) )
#    print( 'Res = %s' % ( relevant_line ) )
    return res

def process_power_status_info( battery_result, charger_result ):
    dct = {}
    dct['online'] = field_value( charger_result, 'online:' )
    print( 'online? %s' % ( dct['online'] ) )
    if dct['online'] == 'no':
        dct['status'] = 'discharging'
        dct['percentage'] = field_value( battery_result, 'percentage:' )
        dct['time remaining'] = field_value( battery_result, 'time to empty:' )
    else:
        dct['status'] = 'charging'
        dct['percentage'] = field_value( charger_result, 'percentage:' )
        dct['time remaining'] = field_value( charger_result, 'time to full:' )
    dct['summary'] = 'Battery @ %s and %s. Remaining time: %s.' % ( dct['status'], dct['percentage'], dct['time remaining'] )
    if dct['percentage'] == '100%':
        dct['status'] = 'Battery fully charged'
    print ( 'dct = ', dct )
    return dct


