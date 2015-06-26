#!/usr/local/bin/python3
#
# distros.py


import os, sys, shutil, hashlib, getpass, random, pickle, time, chrubix.utils
from chrubix.utils import rootcryptdevice, mount_device, mount_sys_tmp_proc_n_dev, logme, unmount_sys_tmp_proc_n_dev, failed, \
            chroot_this, wget, do_a_sed, system_or_die, write_oneliner_file, read_oneliner_file, call_binary, install_mp3_files, \
            generate_temporary_filename, backup_the_resolvconf_file, patch_kernel, \
            fix_broken_hyperlinks, disable_root_password, install_windows_xp_theme_stuff, \
            MAXIMUM_COMPRESSION, set_user_password, call_makepkg_or_die, remaining_megabytes_free_on_device, \
            is_this_bindmounted, check_sanity_of_distro, create_impatient_wrapper

from chrubix.utils.postinst import write_lxdm_post_login_file, write_lxdm_post_logout_file, \
            append_lxdm_xresources_addendum, generate_wifi_manual_script, generate_wifi_auto_script, \
            configure_privoxy, tweak_speech_synthesis, \
            configure_lxdm_onetime_changes, configure_lxdm_behavior, configure_lxdm_service, \
            install_chrome_or_iceweasel_privoxy_wrapper, remove_junk, tweak_xwindow_for_cbook, install_panicbutton_scripting, \
            check_and_if_necessary_fix_password_file, install_insecure_browser, append_proxy_details_to_environment_file, \
            setup_onceaminute_timer, setup_onceeverythreeseconds_timer, write_lxdm_service_file, \
            add_user_to_the_relevant_groups, write_login_ready_file, setup_poweroffifunplugdisk_service, write_boom_script, \
            tidy_up_alarpy, GUEST_HOMEDIR, set_up_guest_homedir
from chrubix.utils.mbr import install_initcpio_wiperamonshutdown_files


class Distro():
    '''
    '''
    # Class-level consts
    hewwo = '2015/06/24 @ 17:20'
    crypto_rootdev = "/dev/mapper/cryptroot"
    crypto_homedev = "/dev/mapper/crypthome"
    boomfname = "/etc/.boom"
    ryo_tempdir = "/root/.rmo"
    initramfs_directory = ryo_tempdir + "/initramfs_dir"
    kernel_cksum_fname = ".k.bl.ck"
    important_packages = 'fakeroot xmlto man xmltoman intltool squashfs-tools aircrack-ng gnome-keyring \
liferea gobby busybox bzr cpio cryptsetup curl lzop ed parted libtool patch git nano bc pv pidgin \
python3 python-pip python-setuptools python-crypto python-yaml python-gobject rng-tools \
sudo tzdata unzip wget flex gcc bison autoconf dillo \
gnupg mpg123 pavucontrol ttf-dejavu bluez pulseaudio paprefs pavucontrol \
ffmpeg mplayer notification-daemon ttf-liberation \
ntfs-3g autogen automake docbook-xsl pkg-config dosfstools expect acpid make pwgen asciidoc \
xterm xscreensaver rxvt rxvt-unicode smem python-qrencode python-imaging cmake \
gimp inkscape scribus audacity pitivi poedit alsa-utils libcanberra-pulse sound-juicer \
simple-scan macchanger brasero pm-utils mousepad keepassx claws-mail bluez-utils \
libdevmapper-dev xbindkeys \
'  # palimpsest gnome-session-fallback mate-settings-daemon-pulseaudio
    final_push_packages = 'lxde tor privoxy vidalia systemd syslog-ng gnome-tweak-tool'  # Install these, all at once, when we're ready to break the Internet :)
    # Instance-level attributes
    def __init__( self, *args, **kwargs ):
        self.name = None
        self.branch = None
        self.reboot_into_stage_two = False  # set to True by Evil Maid protector :)
        self.__args = args
        self.__pheasants = False  # Starts FALSE so that the generic _D is... generic. Turns TRUE later on, in migrate_OS().
        self.__kthx = False  # Always TRUE. That way, even the generic stage files have the obfuscated filesystems (xfs, jfs, btrfs).
        self.__crypto_filesystem_format = 'xfs'  # xfs, jfs, btrfs, ext4...?
        self.__device = '/dev/null'  # e.g. /dev/mmcblk1
        self.__kernel_dev = '/dev/null'  # e.g. /dev/mmcblk1p1
        self.__spare_dev = '/dev/null'  # e.g. /dev/mmcblk1p2
        self.__root_dev = '/dev/null'  # e.g. /dev/mmcblk1p3
        self.__boom_pw_hash = None
        self.root_is_encrypted = False
        self.boom_pw_hash_fname = '/etc/.boom.hash'
        self.panic_button = 0  # >0 means panic button is active; 0 means inactive
        self.architecture = None
        self.kernel_rebuild_required = False
        self.initrd_rebuild_required = False
        self.randomized_serial_number = None
        self.package_group_size = 10  # May be overridden by subclass
        self.status_lst = []
        self.mountpoint = None  # not mounted yet :)
        self.list_of_mkfs_packages = None  # This will be defined by subclass
        self.use_latest_kernel = False
        self.lxdm_settings = {'window manager':chrubix.utils.g_default_window_manager,
                              'default wm':chrubix.utils.g_default_window_manager,
                              'enable user lists':True,
                              'autologin':True,
                              'use greeter gui':False,  # Technically, we always call greeter. This switch forces us to use (or not use) the 'scary eyes' X (GUI) side of the greeter.
                              'login as user':'guest',
                              'internet directly':True  # We aren't operating from Starbucks or McDonalds :)
                              }
        self.__dict__.update( kwargs )

    def configure_distrospecific_tweaks( self ):    failed( "please define in subclass" )
    def install_barebones_root_filesystem( self ):  failed( "please define in subclass" )
    def download_mkfs_sources( self ):              failed( "please define in subclass" )
    def build_package( self, source_pathname ):     failed( "build_package(%s) --- please define in subclass" % ( source_pathname ) )
    def install_package_manager_tweaks( self ):     failed( "please define in subclass. Don't forget! Exclude jfsprogs, btrfsprogs, xfsprogs, cryptsetup, Linux kernel." )
    def update_and_upgrade_all( self ):             failed( "please define in subclass" )
    def install_important_packages( self ):         failed( "please define in subclass" )
    def install_i2p( self ):                        failed( "please define in subclass" )
    def install_kernel_and_mkfs( self ):            failed( 'please define in subclass' )
    def configure_boot_process( self ):             failed( 'please define in subclass' )
#    def install_locale( self ):                     failed( 'please define in subclass' )
    def install_final_push_of_packages( self ):     failed( "please define in subclass -- must install network-manager and wmwsystemtray" )
    def build_mkfs_n_kernel_for_OS_w_preexisting_PKGBUILDs( self ):   failed( "please define in subclass" )

    @property
    def pheasants( self ):
        return self.__pheasants
    @pheasants.setter
    def pheasants( self, value ):
        assert( type( value ) is bool )
        if value != self.__pheasants:
            self.__pheasants = value
            logme( 'Because you changed the value of self.pheasants, a rebuild is required.' )
            self.initrd_rebuild_required = True

    @property
    def title_str( self ):
        my_title = self.name
        if self.branch is not None:
            my_title += ' ' + self.branch
        return '%s - Installing %s on %s' % ( self.hewwo, my_title, self.device )
    @title_str.setter
    def title_str( self, value ):
        raise AttributeError( 'Please do not try to set title_str, even to %s' % ( str( value ) ) )

    @property
    def crypto_filesystem_mkfs_binary( self ):
        if self.crypto_filesystem_format == 'jfs':
            return 'jfs_mkfs'
        else:
            return 'mkfs.%s' % ( self.crypto_filesystem_format )
    @crypto_filesystem_mkfs_binary.setter
    def crypto_filesystem_mkfs_binary( self, value ):
        raise AttributeError( 'Please do not try to set crypto_filesystem_mkfs_binary, even to %s' % ( str( value ) ) )

    @property
    def crypto_filesystem_format( self ):
        return self.__crypto_filesystem_format
    @crypto_filesystem_format.setter
    def crypto_filesystem_format( self, value ):
        self.__crypto_filesystem_format = value

    @property
    def crypto_filesystem_formatting_options( self ):
        dct = {'ext4':'-v', 'xfs':'-f', 'jfs':'-f', 'btrfs':'-f -O ^extref -O ^skinny-metadata'}
        return dct[self.crypto_filesystem_format]

    @property
    def sources_basedir( self ):
        return self.ryo_tempdir + "/PKGBUILDs/core"
    @property
    def kernel_src_basedir( self ):
        return self.sources_basedir + "/linux-chromebook"

    @property
    def crypto_filesystem_fstab_options( self ):
        dct = {'ext4':'defaults,noatime,nodiratime',
               'xfs':'defaults,noatime,nodiratime',
               'jfs':'defaults,noatime,nodiratime',
               'btrfs':'defaults,noatime,nodiratime,compress=lzo'}
        return dct[self.crypto_filesystem_format]

    @property
    def crypto_filesystem_mounting_options( self ):
        dct = {'ext4':'-o %s' % ( self.crypto_filesystem_fstab_options ),
               'xfs':'-o %s' % ( self.crypto_filesystem_fstab_options ),
               'jfs':'-o %s' % ( self.crypto_filesystem_fstab_options ),
               'btrfs':'-o %s' % ( self.crypto_filesystem_fstab_options )}
        return dct[self.crypto_filesystem_format]

    @property
    def kthx( self ):
        return self.__kthx
    @kthx.setter
    def kthx( self, value ):
        assert( type( value ) is bool )
        if value != self.__kthx:
            logme( 'SETTING KTHX TO %s' % ( str( value ) ) )
            self.__kthx = value
            logme( 'Because you changed the value of self.kthx, a rebuild is required.' )
            self.initrd_rebuild_required = True

    @property
    def device( self ):
        return self.__device
    @device.setter
    def device( self, value ):
        if value[:5] != '/dev/':
            raise SyntaxError( 'device should begin with /dev/ but it does not; it is %s' % ( value, ) )
        self.__device = value

    @property
    def kernel_dev( self ):
        return self.__kernel_dev
    @kernel_dev.setter
    def kernel_dev( self, value ):
        if value[:5] != '/dev/':
            raise SyntaxError( 'kernel_dev should begin with /dev/ but it does not; it is %s' % ( value, ) )
        self.__kernel_dev = value

    @property
    def spare_dev( self ):
        return self.__spare_dev
    @spare_dev.setter
    def spare_dev( self, value ):
        if value[:5] != '/dev/':
            raise SyntaxError( 'spare_dev should begin with /dev/ but it does not; it is %s' % ( value, ) )
        self.__spare_dev = value

    @property
    def root_dev( self ):
        return self.__root_dev
    @root_dev.setter
    def root_dev( self, value ):
        if value[:5] != '/dev/':
            raise SyntaxError( '__root_dev should begin with /dev/ but it does not; it is %s' % ( value, ) )
        self.__root_dev = value

    @property
    def boom_password( self ):
        raise AttributeError( 'Do not ask for the boom password. It is hashed. Ask for the hash instead.' )
    @boom_password.setter
    def boom_password( self, value ):
        logme( 'Because you changed the value of the boom password, a rebuild is required.' )
        self.initrd_rebuild_required = True
        hexdig = hashlib.sha512( value.encode( 'utf-8' ) ).hexdigest()
        outval = hexdig.encode( 'utf-8' )
        if type( outval ) is bytes:
            self.__boom_pw_hash = outval.decode( 'utf-8' )
        else:
            self.__boom_pw_hash = outval

    @property
    def boom_pw_hash( self ):
        return self.__boom_pw_hash
    @boom_pw_hash.setter
    def boom_pw_hash( self, value ):
        raise AttributeError( 'Do not try to set the boom password hash to %s. Set the boom password instead.' % ( value ) )

    @property
    def fullname( self ):
        s = self.name + ( '' if self.branch is None else self.branch )
        return s
    @fullname.setter
    def fullname( self, value ):
        raise AttributeError( 'Do not try to set the fullname to %s.' % ( value ) )

    def update_status( self, s, newline = False ):
        if self.status_lst in( None, [] ):
            self.status_lst = ['']
        logme( s )
        self.status_lst[-1] += s
        if newline:
            self.status_lst.append( [''] )

    def update_status_with_newline( self, s ):
        self.update_status( s, newline = True )

    def build_mkfs( self ):
        self.update_status( 'Building mk*fs' )
#        chroot_this( self.mountpoint, 'rm -f /lib/libcryptsetup* /lib/*/libcryptsetup* /lib/*/*/libcryptsetup*' )
        for missing_file in ( 'automake', 'aclocal' ):
            if 0 != chroot_this( self.mountpoint, 'which %s-1.14' % ( missing_file ) ):
                chroot_this( self.mountpoint, 'ln -sf %s /usr/bin/%s-1.14' % ( missing_file, missing_file ), on_fail = 'Failed to kludge %s-1.14' % ( missing_file ) )
        for pkg_name in self.list_of_mkfs_packages:
            try:
                self.build_package( '%s/%s' % ( self.sources_basedir, pkg_name ) )
            except RuntimeError:
                if pkg_name.find( 'jfs' ) >= 0:
                    logme( 'jfs source was missing an #include; I have added it; let us try this one more time, eh?' )
                    cmd = 'echo "#include <stdint.h>" >> `find %s%s/%s/%s-*/config.h.in`' % ( self.mountpoint, self.sources_basedir, pkg_name, pkg_name )
                    system_or_die( cmd )
                    self.build_package( '%s/%s' % ( self.sources_basedir, pkg_name ) )
                else:
                    raise RuntimeError
        self.update_status_with_newline( '...mk*fs built.' )

    def build_kernel( self ):
        self.update_status( 'Building kernel' )
        self.build_package( self.kernel_src_basedir )  # , 302200 )
        if self.use_latest_kernel:
            chroot_this( self.mountpoint, '\
cd %s/linux-latest && \
cat ../linux-chromebook/config | sed s/ZSMALLOC=.*/ZSMALLOC=y/ > .config && \
yes "" 2>/dev/null | make oldconfig && \
make' % ( self.sources_basedir ), title_str = self.title_str, status_lst = self.status_lst )
        self.update_status( '...kernel built. ' )

    def redo_mbr_for_encrypted_root( self, chroot_here ):
        self.redo_mbr( root_partition_device = self.crypto_rootdev, chroot_here = chroot_here )

    def redo_mbr_for_squashfs_root( self, chroot_here ):  # VFAT partition == spare dev == p2
        self.redo_mbr( root_partition_device = self.spare_dev, chroot_here = chroot_here )

    def redo_mbr_for_plaintext_root( self, chroot_here ):  # VFAT partition == spare dev == p2
        self.redo_mbr( root_partition_device = self.root_dev, chroot_here = chroot_here )

    def redo_mbr( self, root_partition_device, chroot_here ):  # ,root_partition_dev             ... Also generates hybrid initramfs
        logme( 'redo_mbr() --- starting' )
        if not os.path.exists( '/usr/local/bin/Chrubix' ): failed( 'Someone deleted Chrubix folder. #1' )
        for save_here in ( chroot_here, '/' ):
            system_or_die( 'tar -zxf /tmp/.vbkeys.tgz -C %s' % ( save_here ),
                                status_lst = self.status_lst, title_str = self.title_str )
        if not os.path.exists( '/usr/local/bin/Chrubix' ): failed( 'Someone deleted Chrubix folder. #2' )
        logme( 'Rebuilding kernel' )
        if not os.path.isdir( '%s%s' % ( chroot_here, self.kernel_src_basedir ) ):
            failed( "The kernel's source folder is missing. Please install it." )
        system_or_die( 'mkdir -p %s/%s' % ( chroot_here, self.initramfs_directory ) )
        if self.boom_pw_hash is None:
            logme( 'WARNING - no boom password hash' )
        write_oneliner_file( chroot_here + self.boom_pw_hash_fname, '' if self.boom_pw_hash is None else self.boom_pw_hash )
        system_or_die( 'tar -zxf /tmp/.vbkeys.tgz -C %s' % ( chroot_here ), title_str = self.title_str, status_lst = self.status_lst )
        chroot_this( chroot_here, 'busybox 2> /dev/null', on_fail = 'You are using the bad busybox.' , title_str = self.title_str, status_lst = self.status_lst, attempts = 1 )
        res = system_or_die( 'bash %s/usr/local/bin/redo_mbr.sh %s %s %s' % ( chroot_here,
                                                    self.device, chroot_here, root_partition_device ),
                                                    errtxt = 'Failed to redo kernel & mbr',
                                                    title_str = self.title_str, status_lst = self.status_lst )
        f = '%s%s/src/chromeos-3.4/drivers/mmc/core/mmc.c' % ( chroot_here, self.kernel_src_basedir )
        g = '%s%s/src/chromeos-3.4/fs/btrfs/ctree.h' % ( chroot_here, self.kernel_src_basedir )
        assert( os.path.exists( f ) )
        assert( os.path.exists( g ) )
        self.initrd_rebuild_required = False
        return res

    def install_vbutils_and_firmware_from_cbook( self ):
        for f in ( 'hipxorg', 'vbtools', 'firmware', 'usr_share_alsa_ucm' ):
            system_or_die( 'tar -zxf /tmp/.%s.tgz -C %s 2> /dev/null' % ( f, self.mountpoint ), status_lst = self.status_lst, title_str = self.title_str )
        chroot_this( self.mountpoint, 'cd /lib/firmware/ && ln -sf s5p-mfc/s5p-mfc-v6.fw mfc_fw.bin 2> /dev/null' )

    def set_disk_password( self ):
        if self.mountpoint in ( None, '', '/' ):
            res = 999
            while res != 0:
                urxvt_call = 'urxvt -geometry 60x30+200+200 -name "Change Disk Password" -e sh -c'
                os.system( "export DISPLAY=:0.0" )
                res = os.system( urxvt_call + ' "cryptsetup -y luksAddKey ' + rootcryptdevice() + '"' )
                if res != 0:
                    return 1
                else:
                    res = 1
                    while res != 0:
                        res = os.system( urxvt_call + ' "cryptsetup -y luksDeleteKey ' + rootcryptdevice() + '"' )
            return res
        else:
            failed( "I don't know how to change the disk password by chrooting into a mountpoint. Sorry..." )

    def set_root_password( self, password = None ):
        if password is not None:
            cmd = 'echo -en "%s\n%s\n" | passwd' % ( password, password )
            res = chroot_this( self.mountpoint, cmd, on_fail = 'set_root_password() -- failed to set password' )
        else:
            print( ' ' )
            res = 999
            while res != 'Y' and res != 'N':
                res = input( "Would you like root to be disabled completely (Y/N) ? " ).strip( '\r\n\r\n\r' ).replace( 'y', 'Y' ).replace( 'n', 'N' )
            if res == 'Y':
                logme( 'You want there to be no root password. Fair enough.' )
                res = 0
            else:
                print( 'Please choose a password for your ROOT account.' )
                user = call_binary( ['whoami'] )[1].strip()
                if user not in ( b'root', 'root', '0' , 0 ):
                    raise SystemError( "You should be running me as root, but you are running me as %s" % ( user, ) )
                res = 999
                cmd = 'passwd' if self.mountpoint in ( None, '/' ) else 'chroot %s passwd' % ( self.mountpoint, )
                while res != 0:
                    if os.system( 'ps -o pid -C X >/dev/null 2>/dev/null' ) == 0 and read_oneliner_file( '/proc/cmdline' ).find( 'cros_secure' ) < 0:
                        print( 'Running X, opening a terminal, and calling passwd' )
                        os.system( "export DISPLAY=:0.0" )
                        res = os.system( 'urxvt -geometry 120x30+0+320 -name "Change Root Password" -e sh -c "%s"' % ( cmd, ) )
                    else:
                        print( 'Calling passwd' )
                        res = os.system( cmd )
                    logme( 'cmd=%s ==> res=%s' % ( cmd, res ) )
        return res

    def whitelist_menu_text( self ):
        if self.pheasants:
            return 'Remove whitelist'
        else:
            return 'Insert whitelist'

    def flip_whitelist_setting( self ):
        if self.pheasants:
            self.pheasants = False
        else:
            self.pheasants = True
        self.initrd_rebuild_required = True
        return 0

    def patch_and_modify_kernel_and_mkfs_sources( self, apply_kali_and_unionfs_patches = True ):
        logme( 'modify_kernel_and_mkfs_sources() --- starting' )
        if apply_kali_and_unionfs_patches:
            patch_kernel( self.mountpoint, self.kernel_src_basedir + '/src/chromeos-3.4', 'http://patches.aircrack-ng.org/mac80211.compat08082009.wl_frag+ack_v1.patch' )
            patch_kernel( self.mountpoint, self.kernel_src_basedir + '/src/chromeos-3.4', 'http://download.filesystems.org/unionfs/unionfs-2.x/unionfs-2.5.13_for_3.4.84.diff.gz' )
        self.update_status( '...patched. ' )
        self.call_bash_script_that_modifies_kernel_n_mkfs_sources()
        self.update_status( '...customized. ' )
        assert( 0 == os.system( 'cat %s%s/config | grep UNION_FS' % ( self.mountpoint, self.kernel_src_basedir ) ) )

    def call_bash_script_that_modifies_kernel_n_mkfs_sources( self ):
        self.update_status( 'Modifying kernel and mkfs sources (KTHX=%s PHEASANTS=%s)...' % ( ( 'yes' if self.kthx else 'no' ), ( 'yes' if self.pheasants else 'no' ) ) )
        if not self.kthx:
            self.update_status( 'call_bash_script_that_modifies_kernel_n_mkfs_sources() --- kthx was false; I shall make it True' )
            self.kthx = True
        if 0 != chroot_this( self.mountpoint, 'cd %s/cryptsetup/ && cd / || return 1' % ( self.sources_basedir ) ):
            failed( 'WHERE IS cryptsetup SOURCE? It should have been downloaded. Vart de herk?' )
        try:
            old_sn = read_oneliner_file( '%s/etc/.randomized_serno' % ( self.mountpoint ) )
            logme( 'Randomized serial number was %s' % ( old_sn ) )
        except:
            logme( 'No serial number... yet.' )
        system_or_die( 'bash /usr/local/bin/modify_sources.sh %s %s %s %s' % ( 
                                                                self.device,
                                                                self.mountpoint,
                                                                'yes' if self.pheasants else 'no',
                                                                'yes' if self.kthx else 'no',
                                                                ), "Failed to modify kernel/mkfs sources", title_str = self.title_str, status_lst = self.status_lst )
        self.randomized_serial_number = read_oneliner_file( '%s/etc/.randomized_serno' % ( self.mountpoint ) )
        logme( 'Randomized serial number is %s' % ( self.randomized_serial_number ) )

    def download_modify_build_and_install_kernel_and_mkfs( self ):
        logme( 'modify_build_and_install_mkfs_and_kernel_for_OS() --- starting' )
        diy = True
        mounted = False
        tarball_fname = '/tmp/posterity/%s/%s_PKGBUILDs.tar.xz' % ( self.fullname, self.fullname )
        os.system( 'mkdir -p %s%s' % ( self.mountpoint, os.path.dirname( tarball_fname ) ) )
        system_or_die( 'mkdir -p /tmp/posterity' )
        if os.system( 'mount /dev/sda1 /tmp/posterity &> /dev/null' ) == 0 \
        or os.system( 'mount /dev/sdb1 /tmp/posterity &> /dev/null' ) == 0 \
        or os.system( 'mount | grep /tmp/posterity &> /dev/null' ) == 0:
            mounted = True
            if os.path.exists( tarball_fname ):
                diy = False
        if diy:
            self.download_kernel_and_mkfs_sources()
            self.patch_and_modify_kernel_and_mkfs_sources( apply_kali_and_unionfs_patches = True )
            self.build_kernel_and_mkfs()
        else:
            system_or_die( 'rm -Rf %s%s' % ( self.mountpoint, self.ryo_tempdir ) )
            system_or_die( 'mkdir -p %s%s' % ( self.mountpoint, self.ryo_tempdir ) )
            system_or_die( 'tar -Jxf %s -C %s%s' % ( tarball_fname, self.mountpoint, self.ryo_tempdir ), status_lst = self.status_lst, title_str = self.title_str )
            system_or_die( 'mkdir -p %s%s/initramfs_dir' % ( self.mountpoint, self.ryo_tempdir ) )
        f = '%s%s/src/chromeos-3.4/drivers/mmc/core/mmc.c' % ( self.mountpoint, self.kernel_src_basedir )
        g = '%s%s/src/chromeos-3.4/fs/btrfs/ctree.h' % ( self.mountpoint, self.kernel_src_basedir )
        assert( os.path.exists( f ) )
        assert( os.path.exists( g ) )
        if mounted and diy:
            chroot_this( '/', 'cd %s%s && tar -c PKGBUILDs | xz -9 > %s' % ( self.mountpoint, self.ryo_tempdir, tarball_fname ),
                                                    status_lst = self.status_lst, title_str = self.title_str )
            chroot_this( '/', 'sync;sync;sync;umount /tmp/posterity' , status_lst = self.status_lst, title_str = self.title_str )
        self.install_kernel_and_mkfs()

    def download_kernel_and_mkfs_sources( self ):
        logme( 'download_kernel_and_mkfs_sources() --- starting' )
#        kernel_version = call_binary( ['uname', '-r'] )[1].decode( 'utf-8' ).split( '\n' )
#        if kernel_version != '3.8.11':
#            failed( 'Rebuild PKGBUILDs to allow for new kernel, please. Oh, and edit 3.8.11 in distros/__init__.py, please.' )
        os.system( 'mount /dev/sda1 /tmp/posterity &> /dev/null' )
        raw_pkgbuilds_fname = '/tmp/posterity/%s/%s_raw_PKGBUILDs.tar.xz' % ( self.fullname, self.fullname )
        logme( 'download_kernel_and_mkfs_sources() -- looking for %s' % ( raw_pkgbuilds_fname ) )
        if os.path.exists( raw_pkgbuilds_fname ):
            self.update_status( "Restoring source from raw tarball..." )
            system_or_die( 'rm -Rf %s%s' % ( self.mountpoint, self.ryo_tempdir ) )
            system_or_die( 'mkdir -p %s%s' % ( self.mountpoint, self.ryo_tempdir ) )
            system_or_die( 'tar -Jxf %s -C %s%s' % ( raw_pkgbuilds_fname, self.mountpoint, self.ryo_tempdir ), status_lst = self.status_lst, title_str = self.title_str )
            self.update_status( 'awesome.' )
        else:
#            failed ( "Why could I not find %s?" % ( raw_pkgbuilds_fname ) )
            self.update_status_with_newline( "Setting up build environment" )
            system_or_die( "rm -Rf %s" % ( self.mountpoint + self.ryo_tempdir ) )
            system_or_die( "mkdir -p %s" % ( self.mountpoint + self.ryo_tempdir ) )
            self.update_status( '...Downloading kernel' )
            self.download_kernel_source()  # Must be done before mkfs. Otherwise, 'git' complains & quits.
#            self.download_current_ChromeOS_kernel_source()  # ...to enable me to build the btrfs, xfs, jfs modules & run them within ChromeOS
            if self.use_latest_kernel:
                self.download_latest_kernel_src()
                system_or_die( 'cp -f %s%s/config %s%s/linux-latest/.config' % ( self.mountpoint, self.kernel_src_basedir, self.mountpoint, self.sources_basedir ) )
            self.update_status( '...Downloading mk*fs' )
            self.download_mkfs_sources()
            self.update_status( '...downloaded. Creating raw tarball...' )
            chroot_this( '/', 'cd %s%s && tar -c PKGBUILDs | xz -9 > %s' % ( self.mountpoint, self.ryo_tempdir, raw_pkgbuilds_fname ),
                                                    status_lst = self.status_lst, title_str = self.title_str )
            self.update_status( 'awesome.' )

    def download_latest_kernel_src( self ):
        logme( 'Downloading latest kernel source from kernel.org' )
        system_or_die( '''curl https://www.kernel.org/`curl https://www.kernel.org -o - | fgrep tar.xz | grep -v testing | head -n1 | tr '"' '\n' | fgrep tar.xz` -o %s%s/latest-kernel.tar.xz''' % ( self.mountpoint, self.sources_basedir ),
                             title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( '''cd %s%s && mkdir -p abq && cd abq && tar -Jxf ../latest-kernel.tar.xz && mv linux-* linux-latest && mv linux-latest .. && cd .. && rmdir abq''' % ( self.mountpoint, self.sources_basedir ),
                                    title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'rm -f %s%s/latest-kernel.tar.xz''' % ( self.mountpoint, self.sources_basedir ) )

    def build_kernel_and_mkfs( self ):
        if 0 != chroot_this( self.mountpoint, 'cd %s/cryptsetup/ && cd / || return 1' % ( self.sources_basedir ) ):
            failed( 'WHERE IS cryptsetup SOURCE? It should have been downloaded. Wart de furq?' )
        self.build_mkfs()
        self.build_kernel()  # also makes sara lee initramfs

    def install_timezone( self ):
#        print( "Installing timezone" )
        utc_hour_str = call_binary( ['date', '-u', '+%H'] )[1].decode( 'utf-8' )
        loc_hour_str = call_binary( ['date', '+%H'] )[1].decode( 'utf-8' )
        if utc_hour_str[0] == '0':
            utc_hour_str = utc_hour_str[1:]
        if loc_hour_str[0] == '0':
            loc_hour_str = loc_hour_str[1:]
        utc_hour = int( utc_hour_str )
        loc_hour = int( loc_hour_str )
        gmt_diff = loc_hour - utc_hour
#        print( '%s->%d vs %s->%d ===> %d' % ( utc_hour_str, utc_hour, loc_hour_str, loc_hour, gmt_diff ) )
        new_tz = 'GMT%d' % ( gmt_diff )
        dest_file = '/usr/share/zoneinfo/posix/Etc/%s' % ( new_tz )
        if not os.path.isfile( dest_file ):
            failed( 'We want %s, but %s does not exist' % ( new_tz, dest_file ) )
        src_file = '%s/etc/localtime' % ( self.mountpoint )
        system_or_die( 'ln -sf %s %s' % ( dest_file, src_file ) )

    def configure_dbus_sudo_and_groups( self ):
        system_or_die( 'mkdir -p %s/usr/share/dbus-1/services' % ( self.mountpoint ) )
        write_oneliner_file( '%s/usr/share/dbus-1/services/org.gnome.Notifications.service' % ( self.mountpoint ), '''
[D-BUS Service]
Name=org.freedesktop.Notifications
Exec=/usr/lib/notification-daemon-1.0/notification-daemon
''' )  # See https://wiki.archlinux.org/index.php/Desktop_notifications
        system_or_die( 'echo "%%wheel ALL=(ALL) ALL\nALL ALL=(ALL) NOPASSWD: \
/usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh,/usr/local/bin/tweak_lxdm_and_reboot,/usr/local/bin/tweak_lxdm_and_shutdown,\
/usr/local/bin/run_as_guest.sh,/usr/local/bin/chrubix.sh,/usr/bin/nm-applet,/sbin/shutdown,/sbin/reboot\n" >> %s/etc/sudoers' % ( self.mountpoint ) )
        add_user_to_the_relevant_groups( 'guest', self.name, self.mountpoint )
        if os.path.exists( '%s/usr/lib/notification-daemon' % ( self.mountpoint ) ) and not os.path.exists( '%s/usr/lib/notification-daemon-1.0' % ( self.mountpoint ) ):
            chroot_this( self.mountpoint, 'ln -sf /usr/lib/notification-daemon /usr/lib/notification-daemon-1.0' )

    def configure_networking( self ):
        for pretend_name, real_name in ( 
                                        ( 'syslog', 'syslog-ng' ),
                                        ( 'dbus-org.freedesktop.NetworkManager', 'NetworkManager' ),
                                        ( 'dbus-org.freedesktop.nm-dispatcher', 'NetworkManager-dispatcher' ),
                                        ( 'multi-user.target.wants/privoxy', 'privoxy' ),
                                        ( 'multi-user.target.wants/freenet', 'freenet' ),
                                        ( 'multi-user.target.wants/i2prouter', 'i2prouter' )
                                        ):
            chroot_this( self.mountpoint, 'ln -sf /usr/lib/systemd/system/%s.service /etc/systemd/system/%s.service' % ( real_name, pretend_name ) )
        services_to_disable = ( 'tor', 'netctl.service', 'netcfg.service', 'netctl' )
        for pkg in services_to_disable:
            chroot_this( self.mountpoint, 'systemctl disable %s' % ( pkg ) , title_str = self.title_str, status_lst = self.status_lst, attempts = 1 )
        generate_wifi_manual_script( '%s/usr/local/bin/wifi_manual.sh' % ( self.mountpoint ) )
        generate_wifi_auto_script( '%s/usr/local/bin/wifi_auto.sh' % ( self.mountpoint ) )
        chroot_this( self.mountpoint, 'chmod u+s `which ping`' , title_str = self.title_str, status_lst = self.status_lst )
        write_oneliner_file( '%s/usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh' % ( self.mountpoint ), '''#!/bin/bash
systemctl start privoxy
systemctl start tor
systemctl start freenet
systemctl start i2p
su -l freenet /opt/freenet/run.sh start
su -l root /opt/i2p/runplain.sh
su -l i2psvc i2prouter start
''' )
        do_a_sed( '%s/etc/passwd' % ( self.mountpoint ), 'i2p:/bin/false', 'i2p:/bin/bash' )
        os.system( 'chmod +x %s/usr/local/bin/start_privoxy_freenet_i2p_and_tor.sh' % ( self.mountpoint ) )

    def migrate_all_data( self, new_mountpt ):
#        self.update_status('Migrating all data to the encrypted partition'] )
        system_or_die( 'cd /' )
        os.system( 'mkdir -p %s' % ( new_mountpt ) )  # errtxt = 'Failed to create new mountpoint %s ' % ( new_mtpt ) )
        res = 999
        while res != 0:
            print( """

    Type YES (not yes or Yes but YES). Then, please choose a strong
    password with which to encrypt root ('/'). Enter it three times.
    """ )
#            print("Unmounting %s" % (self.spare_dev))
#            os.system('umount %s' % (self.spare_dev))
            res = chroot_this( self.mountpoint, 'cryptsetup -v luksFormat %s -c aes-xts-plain -y -s 512 -c aes -s 256 -h sha256' % ( self.spare_dev ) )
            if res != 0:
                print( "Cryptsetup returned an error during initial call" )
        res = 999
        while res != 0:
            res = chroot_this( self.mountpoint, 'cryptsetup luksOpen %s %s' % ( self.spare_dev, os.path.basename( self.crypto_rootdev ) ) )
#            if res != 0:
#                res = chroot_this( self.mountpoint, 'cryptsetup open %s %s' % ( self.spare_dev, os.path.basename( self.crypto_rootdev ) ) )
            if res != 0:
                failed( 'Cryptsetup returned an error during second call' )
#        os.system( 'clear' )
        print( """
Rules for the 'boom' password:
(1) Don't leave blank. (2) Don't use 'boom'. (3) Don't reuse another password.

""" )
        res = 999
        while res != 0:
            boompw = getpass.getpass( """

Choose the 'boom' password : """ ).strip( '\r\n\r\n\r' )
            boompwB = getpass.getpass( "Enter a second time, please: " ).strip( '\r\n\r\n\r' )
            if boompw != boompwB:
                print ( "Passwords did not match" )
            elif boompw == "":
                print ( "A blank secondary password is not allowed" )
            else:
                res = 0
        self.boom_password = boompw
        boompw = ""
        boompwB = ""
        system_or_die( 'dd if=/dev/zero of=%s bs=16k count=1 2> /dev/null' % ( self.crypto_rootdev ) )
        logme( 'crypto filesystem format = %s' % ( self.crypto_filesystem_format ) )
        if 0 != chroot_this( self.mountpoint, 'which %s 2> /dev/null' % ( self.crypto_filesystem_mkfs_binary ), attempts = 1 ):
            failed( 'Unable to find executable %s; therefore, I cannot format your crypt partition. Sorry!' % ( self.crypto_filesystem_mkfs_binary ) )
        system_or_die( 'yes 2> /dev/null | %s %s %s' % ( self.crypto_filesystem_mkfs_binary, self.crypto_filesystem_formatting_options, self.crypto_rootdev ) , title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'mv %s/etc/fstab %s/etc/fstab.orig' % ( self.mountpoint, self.mountpoint ) )
        system_or_die( 'cat %s/etc/fstab.orig | grep -v " /boot " | grep -v " / " > %s/etc/fstab' % ( self.mountpoint, self.mountpoint ) )
        self.update_status( 'Migrating OS to encrypted volume...' )
        write_oneliner_file( self.boom_pw_hash_fname, '' if self.boom_pw_hash is None else self.boom_pw_hash )
        system_or_die( 'mkdir -p ' + new_mountpt )
        mount_device( self.crypto_rootdev, new_mountpt )
        # FIXME save time by merely mkdir'ing /root instead of copying the whole bloody thing.
        for my_dir in ( 'bin', 'boot', 'etc', 'home', 'lib', 'mnt', 'opt', 'root', 'run', 'sbin', 'srv', 'usr', 'var' ):
            self.update_status( '%s..' % ( my_dir ) )
            system_or_die( 'cp -af %s/%s %s' % ( self.mountpoint, my_dir, new_mountpt ), status_lst = self.status_lst, title_str = self.title_str )
#        self.update_status_with_newline( "..OK." )

    def generate_tarball_of_my_rootfs( self, output_file ):
        compression_parameters = '-6e' if ( output_file.find( '_D' ) >= 0 or chrubix.utils.MAXIMUM_COMPRESSION is True ) else '-1'
        self.update_status( 'Creating tarball %s of my rootfs' % ( output_file ) )
        dirs_to_backup = 'bin boot etc home lib mnt opt root run sbin srv usr var'
        if not is_this_bindmounted( self.mountpoint ):
            for dir_name in dirs_to_backup.split( ' ' ):
                dirs_to_backup += ' .alarpy/%s' % ( dir_name )
        system_or_die( 'mkdir -p %s%s' % ( self.mountpoint, os.path.dirname( output_file ) ) )
        system_or_die( 'rm -Rf %s/.*rash*' % ( os.path.dirname( output_file ) ) )
        system_or_die( 'cd %s && tar -c %s | xz %s > %s/temp.data' % ( self.mountpoint, dirs_to_backup, compression_parameters, os.path.dirname( output_file ) ), title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'mv %s/temp.data %s' % ( os.path.dirname( output_file ), output_file ) )
        self.update_status_with_newline( '...created.' )
        return 0

    def write_my_rootfs_from_tarball( self, fname ):
        self.update_status( 'Restoring rootfs from %s' % ( fname ) )
        if os.path.exists( fname ):
            system_or_die( 'tar -Jxf %s -C %s' % ( fname, self.mountpoint ), title_str = self.title_str, status_lst = self.status_lst )
            self.update_status( '...restored.' )
            return 0
        else:
            self.update_status( '...Nope, sorry. Failed.' )
            del self.status_lst[-1]
            return 998

    def install_and_mount_barebones_OS( self ):
        self.update_status( "Downloading and installing skeleton" )
        system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
        self.install_barebones_root_filesystem()
        system_or_die( 'mkdir -p %s/{dev,sys,proc,tmp}' % ( self.mountpoint, ), "Can't make important dirs" )
        backup_the_resolvconf_file( self.mountpoint )
        self.update_status( '...installed.' )
        system_or_die( 'mkdir -p %s/usr/local/bin' % ( self.mountpoint, ) )
        self.update_status( "Mounting partitions" )
        mount_sys_tmp_proc_n_dev( self.mountpoint )
        self.update_status( '...mounted.' )
#        assert( 0 == chroot_this( self.mountpoint, '' ) )

    def update_barebones_OS( self ):
        self.update_status( "Updating skeleton" )
        self.install_package_manager_tweaks()
#        system_or_die( 'rm -f /var/lib/pacman/db.lck; sync; sync; sync; sleep 2; sync; sync; sync; sleep 2' )
        chroot_this( '/', r'yes "" 2>/dev/null | pacman -Sy', "Failed to upgrade OS", attempts = 3, title_str = self.title_str, status_lst = self.status_lst )
        self.update_status( "...updated." )

    def install_all_important_packages_in_OS( self ):
        self.update_status( 'Installing OS' )
        mount_sys_tmp_proc_n_dev( self.mountpoint )  # Shouldn't be necessary...
        self.install_important_packages()

    def install_urwid_and_dropbox_uploader( self ):
        self.update_status( 'Installing dropbox uploader, Python easy_install, and urwid' )
        chroot_this( self.mountpoint, 'which easy_install3 2>/dev/null && easy_install3 urwid', status_lst = self.status_lst, title_str = self.title_str )
        self.update_status( '.' )
        chroot_this( self.mountpoint, 'which easy_install  2>/dev/null && easy_install  urwid', status_lst = self.status_lst, title_str = self.title_str )
        self.update_status( '.' )
        for my_executable in ( 'mkinitcpio', 'dtc' ):
            chroot_this( self.mountpoint, 'which %s &> /dev/null' % ( my_executable ), on_fail = 'Programmer forgot to install %s as part of %s distro' % ( my_executable, self.name ), attempts = 1 )
        self.update_status( '.' )
        wget( url = 'https://raw.github.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh', save_as_file = self.mountpoint + '/usr/local/bin/dropbox_uploader.sh', \
                                            title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'chmod +x %s/usr/local/bin/dropbox_uploader.sh' % ( self.mountpoint ) )
        if not os.path.exists( '%s/etc/mtab' % ( self.mountpoint ) ):
            system_or_die( 'ln -sf /proc/mounts %s/etc/mtab' % ( self.mountpoint ) )
        self.update_status( '...word.' )

    def install_panic_button( self ):
        install_panicbutton_scripting( self.mountpoint , self.boomfname )
        write_boom_script( self.mountpoint, ( self.spare_dev, ) )  # self.root_dev, self.kernel_dev, self.spare_dev, self.device ) )

    def configure_hostname( self ):
        write_oneliner_file( '%s/etc/hostname' % ( self.mountpoint ), self.name )

    def configure_xwindow_and_timers( self ):
        if 0 != chroot_this( self.mountpoint, 'which xbindkeys' ):
            chroot_this( self.mountpoint, 'yes Y | apt-get install xbindkeys' )  # FIXME remove by 7/1/2015
        tweak_xwindow_for_cbook( self.mountpoint )
        setup_onceaminute_timer( self.mountpoint )
        setup_onceeverythreeseconds_timer( self.mountpoint )

    def install_extra_menu_items_in_gui ( self ):
        system_or_die( 'rm -f %s/usr/local/bin/make_me_permanent.sh' % ( self.mountpoint ) )
        f = '%s/usr/local/bin/xterm_mmp.sh' % ( self.mountpoint )  # FIXME this file should be created by another subroutine instead, perhaps?
        write_oneliner_file( f, '''#!/bin/sh
/usr/bin/x-terminal-emulator -e /usr/local/bin/make_me_persistent.sh
exit $?
''' )
        system_or_die( 'chmod +x %s' % ( f ) )
        f = '%s/usr/share/applications/make_me_persistent.desktop' % ( self.mountpoint )
        write_oneliner_file( f, '''[Desktop Entry]
Name=CREATE A PERSISTENT VOLUME
Comment=Creates a persistent, encrypted storage locker on this disk
Encoding=UTF-8
Exec=gksu /usr/local/bin/xterm_mmp.sh
Icon=/usr/local/bin/Chrubix/src/ui/alarmist.png
StartupNotify=true
Terminal=false
X-MultipleArgs=false
Type=Application
Categories=GTK;Utility;TerminalEmulator;
''' )  # FIME should use /usr/local/bin/make_me_persistent.sh

    def configure_lxdm_login_manager( self ):
        configure_lxdm_onetime_changes( self.mountpoint )
        configure_lxdm_behavior( self.mountpoint, self.lxdm_settings )
        configure_lxdm_service( self.mountpoint )
        chroot_this( self.mountpoint, 'chmod +x /etc/lxdm/L*' )
        chroot_this( self.mountpoint, 'chmod +x /etc/lxdm/P*' )

    def tweak_resolv_conf_file( self ):
        system_or_die( 'echo -en "search localhost\nnameserver 8.8.8.8\n" >> %s/etc/resolv.conf' % ( self.mountpoint ) )

    def install_gpg_applet( self ):
        self.update_status( 'GPGapplet...' )
        system_or_die( 'tar -zxf %s/usr/local/bin/Chrubix/blobs/apps/gpgApplet.tgz -C %s' % ( self.mountpoint, self.mountpoint ) )

    def configure_privacy_tools( self ):
        configure_privoxy( self.mountpoint )
        append_proxy_details_to_environment_file( '%s/etc/environment' % ( self.mountpoint ) )
        setup_poweroffifunplugdisk_service( self.mountpoint )

    def configure_chrome_or_iceweasel( self ):
#        if 0 != chroot_this( self.mountpoint, 'which chromium', status_lst = self.status_lst, title_str = self.title_str ):
#            self.build_and_install_package_from_deb_or_ubu_source( 'chromium-browser', 'https://packages.debian.org/' + self.branch )
        install_chrome_or_iceweasel_privoxy_wrapper( self.mountpoint )
        try:
            install_insecure_browser ( self.mountpoint )
        except:
            self.update_status( 'Warning - failed to install insecure browser' )

    def configure_sound_speech_and_font_cache( self ):
        tweak_speech_synthesis( self.mountpoint )
        chroot_this( self.mountpoint, 'fc-cache' )
        self.tweak_pulseaudio()

    def tweak_pulseaudio( self ):
        if os.path.exists( '%s/etc/pulse/default.pa' % ( self.mountpoint ) ):
            new_str = 'load-module module-alsa-sink device=sysdefault #QQQ'
            do_a_sed( '%s/etc/pulse/default.pa' % ( self.mountpoint ), '#load-module module-alsa-sink', new_str )
        else:
            logme( 'tweak_pulseaudio() -- unable to modify /etc/pulse/default.pa; it does not exist' )
        if os.path.exists( '%s/etc/default/pulseaudio' % ( self.mountpoint ) ):
            do_a_sed( '%s/etc/default/pulseaudio' % ( self.mountpoint ), 'PULSEAUDIO_SYSTEM_START=0', 'PULSEAUDIO_SYSTEM_START=1' )
        else:
            logme( 'tweak_pulseaudio() -- unable to modify /etc/default/pulseaudio; it does not exist' )

    def add_reboot_user( self ):
        self.add_user_SUB( 'reboot' )

    def add_shutdown_user( self ):
        self.add_user_SUB( 'shutdown' )

    def add_user_SUB( self, username, userhome = None ):
        cmd = username if username != 'shutdown' else 'poweroff'
        if userhome is None:
            userhome = '/etc/.%s' % ( username )
        if 0 != chroot_this( self.mountpoint, "mkdir -p %s" % ( userhome ), attempts = 1 ):
            system_or_die( 'mkdir -p %s%s' % ( self.mountpoint, userhome ) )
        if 0 != chroot_this( self.mountpoint, "useradd %s -d %s" % ( username, userhome ), attempts = 1, status_lst = self.status_lst, title_str = self.title_str ):
            if 0 != os.system( 'cat %s/etc/passwd | grep %s &> /dev/null' % ( self.mountpoint, username ) ):
                # 0=success; 9=user exists already
                failed( 'Failed to add user %s' % ( username ) )
        chroot_this( self.mountpoint, "chmod 700 %s" % ( userhome ), attempts = 1, on_fail = 'Failed to chmod for user %s' % ( username ) )
        do_a_sed( '%s/etc/shadow' % ( self.mountpoint ), r'%s:!:' % ( username ), r'%s::' % ( username ) )
        do_a_sed( '%s/etc/passwd' % ( self.mountpoint ), r'%s:!:' % ( username ), r'%s::' % ( username ) )

#        chroot_this( self.mountpoint, "cat %s | sed s/%s':.:'/%s'::'/ > /etc/shadow" % ( tmpfile, username, username ) )
        profile_fname = '%s%s/.profile' % ( self.mountpoint, userhome )
        write_oneliner_file( profile_fname, '''#!/bin/bash
sudo tweak_lxdm_and_%s
''' % ( username ) )
        system_or_die( 'chmod +x %s' % ( profile_fname ) )
        if 0 != chroot_this( self.mountpoint, "chown -R %s.%s %s" % ( username, username, userhome ), attempts = 1, status_lst = self.status_lst, title_str = self.title_str ):
            chroot_this( self.mountpoint, "chown -R %s.root %s" % ( username, userhome ), attempts = 1, status_lst = self.status_lst, title_str = self.title_str, on_fail = 'Failed to modify permissions of %s config file' % ( username ) )
        write_oneliner_file( '%s/usr/local/bin/tweak_lxdm_and_%s' % ( self.mountpoint, username ), '''#!/bin/bash
sync;sync;sync
systemctl %s
exit 0
    ''' % ( cmd ) )
        system_or_die( 'chmod +x %s/usr/local/bin/tweak_lxdm_and_%s' % ( self.mountpoint, username ) )

    def add_guest_user( self ):
        if 0 == chroot_this( self.mountpoint, 'cat /etc/passwd | fgrep "guest:" > /dev/null' ):
            chroot_this( self.mountpoint, 'userdel guest', on_fail = 'Failed to delete old guest ID' )
        chroot_this( self.mountpoint, 'mkdir -p %s' % ( GUEST_HOMEDIR ), on_fail = 'Failed to mkdir for guest' )
        chroot_this( self.mountpoint, 'chmod 777 %s' % ( GUEST_HOMEDIR ), on_fail = 'Failed to chmod guest' )
        chroot_this( self.mountpoint, 'useradd guest -d %s' % ( GUEST_HOMEDIR ) , on_fail = "Failed to add user guest" )
        chroot_this( self.mountpoint, 'chmod 700 %s' % ( GUEST_HOMEDIR ), on_fail = 'Failed to chmod guest' )
#        do_a_sed( passwd_file, r'guest:x:', r'guest::' )
#        do_a_sed( passwd_file, r'guest::', r'guest:x:' )
        set_user_password( login = 'guest', password = 'guest', mountpoint = self.mountpoint )
        set_up_guest_homedir( mountpoint = self.mountpoint )
#        set_up_guest_homedir( mountpoint = self.mountpoint, homedir = '/tmp/.guest' )
        if 0 == chroot_this( self.mountpoint, 'ls -dl %s | grep root' % ( GUEST_HOMEDIR ), attempts = 1 ):
            failed( 'For some reason, the guest directory contents still belongs to root.' )
        if 0 == chroot_this( self.mountpoint, 'ls -dl %s/.[a-z,A-Z]* | grep root' % ( GUEST_HOMEDIR ), attempts = 1 ):
            failed( 'For some reason, the guest directory still belongs to root.' )

    def remove_all_junk( self ):
        # Tidy up the actual OS
        if not os.path.exists( '%s%s' % ( self.mountpoint, self.kernel_src_basedir ) ):
            failed( 'For some reason, the linux-chromebook folder is missing from the bootstrap OS. That is not good!' )
        self.update_status( 'Removing superfluous files and directories from OS' )
        remove_junk( self.mountpoint, self.kernel_src_basedir )
        if not os.path.exists( '%s%s' % ( self.mountpoint, self.kernel_src_basedir ) ):
            failed( 'remove_junk() deletes the linux-chromebook folder from the bootstrap OS. That is not good!' )
        tidy_up_alarpy()
        self.update_status_with_newline( '...removed.' )

    def migrate_OS( self, encrypt_root_please = False ):
        self.status_lst.append( ['Migrating OS'] )
#        self.reinstall_chrubix_if_missing()
        if not os.path.exists( '%s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( self.mountpoint, self.kernel_src_basedir ) ):
            system_or_die( 'cp -f /tmp/.vmlinuz.uimg %s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( self.mountpoint, self.kernel_src_basedir ) )
        for f in ( '/etc/lxdm/lxdm.conf', self.kernel_src_basedir + '/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg',
                  '/lib/firmware/mrvl/sd8797_uapsta.bin', '/usr/local/bin/chrubix.sh', '/usr/local/bin/ersatz_lxdm.sh' ):
            if not os.path.exists( self.mountpoint + f ):
                failed( '%s%s does not exist' % ( self.mountpoint, f ) )
        system_or_die( 'rm -f %s/.squashfs.sqfs /.squashfs.sqfs' % ( self.mountpoint ) )
#            os.system( 'clear' )
        self.set_root_password()
        username = 'guest'  # ask_the_user__guest_mode_or_user_mode__and_create_one_if_necessary( self.name, self.mountpoint )
        self.lxdm_settings['login as user'] = username
        if username != 'guest':  # Login as specific user, other than guest
            self.lxdm_settings['autologin'] = False
        system_or_die( 'rm -f /.squashfs.sqfs %s/.squashfs.sqfs' % ( self.mountpoint ) )
        if encrypt_root_please:
            self.migrate_to_encrypted_OS()
        else:
            chrubix.save_distro_record( distro_rec = self, mountpoint = self.mountpoint )
            self.redo_mbr_for_plaintext_root( self.mountpoint )

    def migrate_to_encrypted_OS( self ):
        self.status_lst[-1] += 'excellent.'
        self.kernel_rebuild_required = True  # ...because the initramfs needs our boom pw, which means we'll have to rebuild initramfs.... which means rebuilding kernel!
        self.root_is_encrypted = True
        self.pheasants = True
        self.kthx = True
        self.call_bash_script_that_modifies_kernel_n_mkfs_sources()
        self.build_kernel_and_mkfs()  # Recompile mk*fs because our new kernel will probably use random magic#'s for xfs, jfs, and btrfs
        self.install_kernel_and_mkfs()
#        self.forcibly_rebuild_initramfs_and_vmlinux()
        system_or_die( 'cd /' )
        new_mtpt = '/tmp/_enc_root'
        os.system( 'mkdir -p %s' % ( new_mtpt ) )  # errtxt = 'Failed to create new mountpoint %s ' % ( new_mtpt ) )
        self.migrate_all_data( new_mtpt )  # also mounts new_mtpt and rejigs kernel
        mount_sys_tmp_proc_n_dev( new_mtpt )
        self.redo_mbr_for_encrypted_root( new_mtpt )
        chrubix.save_distro_record( distro_rec = self, mountpoint = new_mtpt )  # save distro record to new disk (not old mountpoint)
        try:
            unmount_sys_tmp_proc_n_dev( new_mtpt )
            os.system( 'umount %s/%s' % ( self.mountpoint, new_mtpt ) )
            unmount_sys_tmp_proc_n_dev( self.mountpoint )
        except ( SystemError, SyntaxError ):
            pass

    def squash_OS_or_setup_stage_two( self ):
        if self.reboot_into_stage_two:
            self.setup_for_stage_two()
        else:
#            self.set_root_password( 'hi' )
            self.squash_OS()

    def setup_for_stage_two( self ):
        write_oneliner_file( '%s/.stage2.sh' % ( self.mountpoint ), '''#!/bin/bash
export PATH=/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin
mount devtmpfs /dev  -t devtmpfs
mount tmpfs    /tmp  -t tmpfs
mount proc     /proc -t proc
mount sysfs    /sys  -t sysfs
ln -s /proc/self/fd /dev/
ln -s /proc/self/fd/0 /dev/stdin
ln -s /proc/self/fd/1 /dev/stdout

mv /.*z /tmp/                # .vbutils.tgz, .vbkeys.tgz, ...
echo "Calling Chrubix's stage 2..."
cd /usr/local/bin/Chrubix/src
python3 stage2.py
echo "Shelling to root, because I'm nice like that."
bash
echo "Rebooting..."
umount /tmp /proc /dev/sys
reboot
sleep 10
''' )
        system_or_die( 'chmod +x %s/.stage2.sh' % ( self.mountpoint ) )
        assert( os.path.exists( '%s/.vbkeys.tgz' % ( self.mountpoint ) ) )
        self.kernel_rebuild_required = True
        self.initrd_rebuild_required = True
        self.call_bash_script_that_modifies_kernel_n_mkfs_sources()
        self.build_kernel_and_mkfs()
        self.install_kernel_and_mkfs()
#            self.forcibly_rebuild_initramfs_and_vmlinux()   # Is this necessary? Remember, squash_OS() calls redo_mbr(). which rebuilds initramfs and vmlinux.
        try:
            assert( self.kernel_rebuild_required is False )
            assert( self.initrd_rebuild_required is False )
        except AssertionError:
            logme( '**FYI, assertion error in rebuild_EVERYTHING_if_evil_maid_mode()**' )
            self.kernel_rebuild_required = False
            self.initrd_rebuild_required = False
        self.redo_mbr_for_plaintext_root( self.mountpoint )
        chrubix.save_distro_record( self, self.mountpoint )

    def squash_OS( self, prefixpath = '' ):
        if prefixpath == '':  # In other words, if we AREN'T being run within stage 2...
            self.update_status( 'Checking sanity of distro...' )
            broken_pkgs = check_sanity_of_distro( self.mountpoint, self.kernel_src_basedir )
            if broken_pkgs in ( None, '' ):
                self.update_status_with_newline( 'distro is not insane. (How nice)' )
            else:
                self.update_status_with_newline( 'squash_OS() -- distro has issues w/ %s' % ( broken_pkgs ) )
        self.update_status( 'Squashing OS...' )
        if not os.path.exists( '%s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( self.mountpoint, self.kernel_src_basedir ) ):
            system_or_die( 'cp -f /tmp/.vmlinuz.uimg %s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( self.mountpoint, self.kernel_src_basedir ) )
        for f in ( '/etc/lxdm/lxdm.conf', self.kernel_src_basedir + '/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg',
                  '/lib/firmware/mrvl/sd8797_uapsta.bin', '/usr/local/bin/chrubix.sh', '/usr/local/bin/ersatz_lxdm.sh' ):
            if not os.path.exists( '%s%s' % ( self.mountpoint, f ) ):
                failed( '%s%s does not exist' % ( self.mountpoint, f ) )
        system_or_die( 'rm -f %s/.squashfs.sqfs /.squashfs.sqfs' % ( self.mountpoint ) )
        self.lxdm_settings['use greeter gui'] = True
        chrubix.save_distro_record( distro_rec = self, mountpoint = self.mountpoint )
        # Here comes the science!
        self.redo_mbr_for_squashfs_root( self.mountpoint )  # '/tmp/squashfs_dir' )
        self.generate_squashfs_of_my_OS( prefixpath = prefixpath )
        os.system( 'rm -f %s/etc/.randomized_serno*' % ( self.mountpoint ) )
        return 0

    def configure_guestmode_prior_to_migration( self ):
        self.lxdm_settings['login as user'] = 'guest'
        self.lxdm_settings['autologin'] = False

    def unmount_and_clean_up( self ):
        self.update_status( '...Bonzer.' )
        unmount_sys_tmp_proc_n_dev( self.mountpoint )
        logme( 'leaving phase 6 of 6.' )

    def install_moose( self ):
        self.update_status( '...Moose...' )
        for module_name in ( 'GnuPG', 'GnuPG::Interface', 'Moose', ):
            chroot_this( self.mountpoint, """yes "Yes" | perl -MCPAN -e 'install %s'""" % ( module_name ),
                         status_lst = self.status_lst, title_str = self.title_str, on_fail = 'Failed to install moose' )

    def build_and_install_software_from_archlinux_git( self, package_name, yes_download = True, yes_build = True, yes_install = True, quiet = False ):
    #    pkgbuild_url_template = 'https://projects.archlinux.org/svntogit/packages.git/plain/trunk/%s?h=packages/%s'
        what_im_doing = ''
        what_im_doing += 'Downloading/' if yes_download else ''
        what_im_doing += 'Building/'    if yes_build    else ''
        what_im_doing += 'Installing/'  if yes_install  else ''
        if what_im_doing != '':
            what_im_doing = what_im_doing[:-1]
        if self.status_lst is not None and not quiet:
            self.update_status( "%s ArchLinux's %s, from git, into your OS" % ( what_im_doing, package_name ) )
        for mytool in ( 'patch', 'git' ):
            if os.system( 'which %s &>/dev/null' % ( mytool ) ) != 0:
                system_or_die( 'yes "" 2> /dev/null | pacman -S %s' % ( mytool ), title_str = self.title_str, status_lst = self.status_lst )
        if not os.path.isdir( '%s/%s' % ( self.mountpoint, self.kernel_src_basedir ) ):
            chroot_this( self.mountpoint, 'cd %s && git clone git://github.com/archlinuxarm/PKGBUILDs.git' % ( self.ryo_tempdir ), \
                             on_fail = "Failed to git clone kernel source", title_str = self.title_str, status_lst = self.status_lst )
        tmpfile = generate_temporary_filename( '/tmp' )
        cmd = 'find %s/%s -name PKGBUILD -type f | fgrep /%s/ | head -n1 > %s' % ( self.mountpoint, os.path.dirname( self.sources_basedir ), package_name, tmpfile )
        res = os.system( cmd )
        if res != 0:
            failed( "Cannot find PKGBUILD file of %s" % ( package_name ) )
        pkgbuild_pathname = read_oneliner_file( tmpfile )
    #    print( "pkgbuild pathname = %s" % ( pkgbuild_pathname ) )
        if pkgbuild_pathname in ( None, '' ):
            raise RuntimeError( "Package %s is absent from ArchLinux's git repository" % ( package_name ) )
        if yes_download:
            if os.path.basename( pkgbuild_pathname ) != os.path.basename( self.sources_basedir ):
                src_dir = os.path.dirname( pkgbuild_pathname )
                dest_dir = '%s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name )
                if src_dir != dest_dir:
                    system_or_die( 'mkdir -p %s' % ( dest_dir ), title_str = self.title_str, status_lst = self.status_lst )
                    if os.path.dirname( src_dir ) != os.path.dirname( dest_dir ):
                        system_or_die( 'cp -af %s/* %s' % ( src_dir, dest_dir ), title_str = self.title_str, status_lst = self.status_lst )
                    else:
                        system_or_die( 'cd %s && ln -sf %s %s' % ( os.path.dirname( src_dir ), os.path.basename( dest_dir ), os.path.basename( src_dir ) ) )
                system_or_die( 'mv %s/%s/%s/PKGBUILD %s' % ( self.mountpoint, self.sources_basedir, package_name, tmpfile ) )
                system_or_die( r'''cat %s | sed s/march/phr34k/ | sed s/\'libutil-linux\'// | sed s/\'java-service-wrapper\'// | sed s/arch=\(.*/arch=\(\'armv7h\'\)/ | sed s/phr34k/march/ > %s/%s/%s/PKGBUILD''' \
                                                % ( tmpfile, self.mountpoint, self.sources_basedir, package_name ) )
                call_makepkg_or_die( r'cd %s/%s/%s && makepkg --skipchecksums --nobuild' % ( self.mountpoint, self.sources_basedir, package_name ), \
                                                mountpoint = self.mountpoint, \
                                                package_path = '%s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ), \
                                                errtxt = 'Failed to download %s into Alarpy' % ( package_name ) )
        if yes_build:
            chroot_this( self.mountpoint, 'cd %s/%s; cp PKGBUILD my_build.sh; echo srcdir=src >> my_build.sh; echo build >> my_build.sh; chmod +x my_build.sh; bash my_build.sh' % ( self.sources_basedir, package_name ),
                                                         on_fail = 'Failed to build and install %s for new %s distro' % ( package_name, self.name ), \
                                                         title_str = self.title_str, status_lst = self.status_lst )
        if yes_install:
            assert( package_name != 'linux-chromebook' )
            chroot_this( self.mountpoint, 'cd %s/%s/src; cd `find * -maxdepth 0 -type d | head -n1`; installfiles=`ls *.install 2>/dev/null`; make install; if [ "$installfiles" != "" ] ; then for f in $installfiles; do bash $f; done; fi' % ( self.sources_basedir, package_name ), \
                                                         on_fail = 'Failed to install %s for new %s distro' % ( package_name, self.name ), \
                                                         title_str = self.title_str, status_lst = self.status_lst )
        if self.status_lst is not None and not quiet:
            self.update_status( '...Easy.' )

    def build_and_install_package_into_alarpy_from_source( self, pkg_name, quiet = False ):
        logme( 'DebianDistro - build_and_install_package_into_alarpy_from_source() - starting' )
        if not quiet:
            self.update_status( 'Installing %s from source' % ( pkg_name ) )
        system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
        if 0 != wget( url = 'https://aur.archlinux.org/packages/%s/%s/%s.tar.gz'
                                    % ( pkg_name[:2], pkg_name, pkg_name ),
                                    extract_to_path = self.sources_basedir, decompression_flag = 'z',
                                    title_str = self.title_str,
                                    status_lst = self.status_lst ):
            failed( "Failed to download tarball of %s source code" % ( pkg_name ) )
        if not quiet:
            self.update_status( '.' )
        call_makepkg_or_die( cmd = 'cd %s/%s && makepkg --skipchecksums -f'
                                % ( self.sources_basedir, pkg_name ),
                                mountpoint = '/',
                                package_path = '%s/%s' % ( self.sources_basedir, pkg_name ),
                                errtxt = 'failed to build %s into alarpy from source' % ( pkg_name ) )
        if not quiet:
            self.update_status( '.' )
        system_or_die( 'yes "" | pacman -U `ls %s/%s/%s*pkg.tar.xz`'
                                % ( self.sources_basedir, pkg_name, pkg_name ),
                                title_str = self.title_str,
                                status_lst = self.status_lst )
        if not quiet:
            self.update_status( 'Yep.' )

    def build_and_install_software_from_archlinux_source( self, package_name, only_download = False, quiet = False, nodeps = False ):
        chroot_this( '/', 'yes "" 2>/dev/null | pacman -Sy --needed --force fakeroot', title_str = self.title_str, status_lst = self.status_lst,
                         on_fail = 'Failed to install fakeroot #1' )
    #    pkgbuild_url_template = 'https://projects.archlinux.org/svntogit/packages.git/plain/trunk/%s?h=packages/%s'
        if not quiet and self.status_lst is not None:
            self.update_status( "%s ArchLinux's %s, from source, into your OS" % ( 'Downloading' if only_download else 'Installing' , package_name ) )
        tmpfile = generate_temporary_filename( '/tmp' )
        system_or_die( 'rm -Rf %s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        system_or_die( 'mkdir -p %s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        our_url = 'aur.archlinux.org/packages/%s/%s/%s.tar.gz' % ( package_name[:2], package_name, package_name )
        try:
            wget( url = our_url, extract_to_path = '%s/%s' % ( self.mountpoint, self.sources_basedir ), decompression_flag = 'z',
                                                        attempts = 1,
                                                        title_str = self.title_str, status_lst = self.status_lst )
        except SystemError:
            raise RuntimeError( "Package %s is absent from ArchLinux's online sources" % ( package_name ) )
        system_or_die( 'mv %s/%s/%s/PKGBUILD %s' % ( self.mountpoint, self.sources_basedir, package_name, tmpfile ) )
        system_or_die( r'''cat %s | sed s/march/phr34k/ | sed s/\'libutil-linux\'// | sed s/\'java-service-wrapper\'// | sed s/arch=\(.*/arch=\(\'armv7h\'\)/ | sed s/phr34k/march/ > %s/%s/%s/PKGBUILD''' \
                                        % ( tmpfile, self.mountpoint, self.sources_basedir, package_name ) )
        for f in ( 'apache-ant', 'jdk6' ):
            if package_name == 'java-service-wrapper' and not os.path.exists( '/etc/profile.d/%s.sh' % ( f ) ):
                system_or_die( 'ln -sf %s/etc/profile.d/%s.sh /etc/profile.d/' % ( self.mountpoint, f ) )
        call_makepkg_or_die( mountpoint = '/',
                             package_path = '%s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ),
                             cmd = 'cd %s/%s/%s && makepkg --skipchecksums --nodeps --nobuild %s' % ( self.mountpoint, self.sources_basedir, package_name, '--nodeps' if nodeps else '' ),
                             errtxt = 'Failed to download %s into new distro' % ( package_name ) )
        if not only_download:
            if package_name == 'ssss':
                do_a_sed( '%s/%s/%s/PKGBUILD' % ( self.mountpoint, self.sources_basedir, package_name ),
                          'url=.*',
                          'url="http://ftp.riken.jp/Linux/ubuntu/pool/universe/s/ssss/ssss_0.5.orig.tar.gz"' )
            if self.name == 'archlinux':
                # i2p comes w/ broken hyperlinks (MYDISK_MTPT/... instead of ../...). Fix 'em.
                if package_name in ( 'i2p', 'freenet', 'gtk-theme-adwaita-x', 'java-service-wrapper' ):
                    fix_broken_hyperlinks( '%s%s/%s/src' % ( self.mountpoint, self.sources_basedir, package_name ) )
                call_makepkg_or_die( mountpoint = self.mountpoint,
                                        cmd = 'cd %s/%s && makepkg --skipchecksums %s && yes "" | pacman -U %s*pkg.tar.xz' %
                                                    ( self.sources_basedir, package_name, '-f' if package_name == 'java-service-wrapper' else '--noextract', package_name ),
                                        package_path = '%s/%s' % ( self.sources_basedir, package_name ),
                                        errtxt = 'Failed to build&install %s within new %s distro' % ( package_name, self.name ) )
            else:
                chroot_this( self.mountpoint, 'cd %s/%s/src; cd `find * -maxdepth 0 -type d | head -n1`; [ -e "configure" ] && ./configure || echo -en ""' % ( self.sources_basedir, package_name ), \
                                                             on_fail = 'Failed to configure %s for Alarpy' % ( package_name ), \
                                                             title_str = self.title_str, status_lst = self.status_lst )
                chroot_this( self.mountpoint, 'cd %s/%s/src; cd `find * -maxdepth 0 -type d | head -n1`; [ -e "setup.py" ] && python setup.py install || (make && make install)' % ( self.sources_basedir, package_name ), \
                                                             on_fail = 'Failed to make %s for Alarpy' % ( package_name ), \
                                                             title_str = self.title_str, status_lst = self.status_lst )
            #    chroot_this( self.mountpoint, 'cd %s/%s/src; cd `find * -maxdepth 0 -type d | head -n1`;make install' % ( self.sources_basedir, package_name ), \
            #                                                 on_fail = 'Failed to install %s for Alarpy' % ( package_name ), \
            #                                                 title_str = self.title_str, status_lst = self.status_lst )
                chroot_this( self.mountpoint, 'cd %s/%s/src; cd `find * -maxdepth 0 -type d | head -n1`; installfiles=`ls *.install 2>/dev/null`; if [ "$installfiles" != "" ] ; then for f in $installfiles; do bash $f; done; fi' % ( self.sources_basedir, package_name ), \
                                                             on_fail = 'Failed to install %s for Alarpy' % ( package_name ), \
                                                             title_str = self.title_str, status_lst = self.status_lst )
        if not quiet and self.status_lst is not None:
            self.update_status( '...OK.' )

    def install_locale( self ):
        write_oneliner_file( '%s/etc/locale.conf' % ( self.mountpoint ), '''LANG="en_US.UTF-8"
''' )
        write_oneliner_file( '%s/etc/locale.gen' % ( self.mountpoint ), '''en_US.UTF-8 UTF-8
''' )
        write_oneliner_file( '%s/etc/vconsole.conf' % ( self.mountpoint ), '''KEYMAP="us"
''' )
        chroot_this( self.mountpoint, 'locale-gen' , title_str = self.title_str, status_lst = self.status_lst,
                     on_fail = 'Failed to run locale-gen to initialize the new locale' )

    def install_chrubix( self ):
        self.update_status( 'Installing Chrubix in bootstrapped OS' )
        # Save the old-but-groovy chrubix.sh; it was modified (its vars resolved) by chrubix_stage1.sh
        # Delete old copy of Chrubix from mountpoint.
        system_or_die( 'rm -Rf %s/usr/local/bin/Chrubix*' % ( self.mountpoint ) )
        if not is_this_bindmounted( self.mountpoint ):
            system_or_die( 'cp -af /usr/local/bin/Chrubix %s/usr/local/bin/' % ( self.mountpoint ) )
            system_or_die( 'tar -cz /usr/local/bin/Chrubix | tar -zx -C %s' % ( self.mountpoint ) )
            # YES, this next line IS necessary.
            system_or_die( 'cp /usr/local/bin/Chrubix/bash/chrubix.sh %s/usr/local/bin/Chrubix/bash/chrubix.sh' % ( self.mountpoint ) )
            # ^^^ Yes, it is necessary.
        system_or_die( 'ln -sf Chrubix/bash/chrubix.sh %s/usr/local/bin/chrubix.sh' % ( self.mountpoint ) )
        assert( os.path.islink( '%s/usr/local/bin/chrubix.sh' % ( self.mountpoint ) ) )
        system_or_die( 'chmod +x %s/usr/local/bin/Chrubix/bash/*' % ( self.mountpoint ) )
        for f in ( 'chrubix.sh', 'CHRUBIX', 'greeter.sh', 'preboot_configurer.sh', 'modify_sources.sh', \
                   'redo_mbr.sh', 'ersatz_lxdm.sh', 'make_me_persistent.sh', 'adjust_brightness.sh' ):
            system_or_die( 'ln -sf Chrubix/bash/%s %s/usr/local/bin/%s' % ( f, self.mountpoint, f ) )
            system_or_die( 'chmod +x %s/usr/local/bin/Chrubix/bash/%s' % ( self.mountpoint, f ) )
        mytitle = ( self.fullname ).title()
        do_a_sed( '%s/usr/local/bin/Chrubix/src/ui/AlarmistGreeter.ui' % ( self.mountpoint ), 'W E L C O M E', 'Welcome to %s' % ( mytitle ) )
        os.system( 'rm -f %s/usr/local/bin/redo_mbr' % ( self.mountpoint ) )
        chroot_this( self.mountpoint, 'chmod +x /usr/local/bin/*' )
#        chroot_this( self.mountpoint, 'chmod +x /usr/local/bin/*' )
#        system_or_die( 'cp -af /tmp %s/usr/local/bin/Chrubix/bash/chrubix.sh' % ( self.mountpoint ) )
        for f in 'blobs/apps/freenet.tar.xz src/chrubix/distros/debian.py blobs/settings/x_alarm_chrubuntu.zip bash/chrubix.sh bash/greeter.sh bash/modify_sources.sh bash/redo_mbr.sh src/main.py src/greeter.py src/tinker.py'.split( ' ' ):
            g = '%s/usr/local/bin/Chrubix/%s' % ( self.mountpoint, f )
            if os.path.exists( g ):
                logme( '%s exists' % ( g ) )
            else:
                failed( '%s does not exist' % ( g ) )
        if os.path.exists( '%s/usr/bin/python3' % ( self.mountpoint ) ) and not os.path.exists( '%s/usr/local/bin/python3' % ( self.mountpoint ) ):
            system_or_die( 'ln -sf ../../bin/python3 %s/usr/local/bin/python3' % ( self.mountpoint ) )
            if os.path.exists( '%s/usr/bin/python3' % ( self.mountpoint ) ) and not os.path.exists( '%s/usr/local/bin/python3' % ( self.mountpoint ) ):
                failed( 'Well, that escalated rather quickly.' )
        for cmd in ( 'chmod -R 755 /usr/local/bin', 'chmod +x /usr/local/bin/*' ):
            chroot_this( self.mountpoint, cmd, on_fail = 'Failed to %s' % ( cmd ), attempts = 1, status_lst = self.status_lst, title_str = self.title_str )
        self.update_status( '...installed.' )

    def generate_squashfs_of_my_OS( self, prefixpath = '' ):
        logme( 'generate_squashfs_of_my_OS() --- hi' )
        assert( os.path.isdir( '%s/usr/local/bin/Chrubix' % ( self.mountpoint ) ) )
        system_or_die( 'mkdir -p /tmp/posterity' )  # Might be unnecessary
        system_or_die( 'rm -f %s/.squashfs.sqfs /.squashfs.sqfs' % ( self.mountpoint ) )
        if 0 == os.system( 'mount /dev/sda1 /tmp/posterity &> /dev/null' ) \
        or 0 == os.system( 'mount /dev/sdb1 /tmp/posterity &> /dev/null' ) \
        or 0 == os.system( 'mount | grep /tmp/posterity &> /dev/null' ):
#            logme( 'Perhaps.' )
            if os.path.exists( '/tmp/posterity/%s/%s.sqfs' % ( self.fullname, self.fullname ) ):
                self.update_status( 'Restoring squashfs from backup' )
                system_or_die( 'cp -f /tmp/posterity/%s/%s.sqfs /.squashfs.sqfs' % ( self.fullname, self.fullname ) )
                self.update_status( '...restored.' )
#                logme( 'Yes.' )
#            else:
#                logme( 'No.' )
        if not os.path.exists( '/tmp/posterity/%s/%s.sqfs' % ( self.fullname, self.fullname ) ):
            self.update_status( 'Generating squashfs of this OS' )
            system_or_die( 'mkdir -p %s/_to_add_to_squashfs/{dev,proc,sys,tmp,root}' % ( self.mountpoint ) )
            chroot_this( self.mountpoint, 'mkdir -p /usr/share/doc' )
            cmd = 'mksquashfs /bin /boot /etc /home /lib /mnt /opt /run /sbin /usr /srv /var /_to_add_to_squashfs/* %s/.squashfs.sqfs %s' % \
                                                         ( prefixpath, '-b 1048576 -comp xz -Xdict-size 100%' if chrubix.utils.MAXIMUM_COMPRESSION else '' )
            logme( 'cmd = %s' % ( cmd ) )
            if prefixpath != '':
                system_or_die( 'mkdir -p %s' % ( prefixpath ) )
                system_or_die( 'mount %s %s' % ( self.spare_dev, prefixpath ) )
                system_or_die( cmd, status_lst = self.status_lst, title_str = self.title_str, errtxt = 'Failed to generate squashfs' )
                assert( os.path.exists( '%s%s/.squashfs.sqfs' % ( prefixpath, self.mountpoint ) ) )  # FIXME remove by 8/1/2015
                res = system_or_die( 'sync;sync;sync;umount %s' % ( prefixpath ) )
            else:
                res = chroot_this( self.mountpoint, cmd, status_lst = self.status_lst, title_str = self.title_str, attempts = 1, on_fail = 'Failed to generate squashfs' )
                assert( os.path.exists( '%s%s/.squashfs.sqfs' % ( prefixpath, self.mountpoint ) ) )  # FIXME remove by 8/1/2015
            self.update_status( '...generated.' )
        if res != 0:
            failed( 'generate_squashfs_of_my_OS() -- mksquashfs returned an error.' )
        if prefixpath == '':  # Don't save the resultant squashfs file if we're running in Evil Maid Protection Mode
            system_or_die( 'mkdir -p /tmp/posterity' )
            if 0 == os.system( 'mount /dev/sda1 /tmp/posterity &> /dev/null' ) \
            or 0 == os.system( 'mount /dev/sdb1 /tmp/posterity &> /dev/null' ) \
            or 0 == os.system( 'mount | grep /tmp/posterity &> /dev/null' ):
                self.update_status( 'Backing up the squashed fs' )
                logme( 'Backing up squashs' )
                os.system( 'sync;sync;sync' )
                assert( os.path.exists( '%s%s/.squashfs.sqfs' % ( prefixpath, self.mountpoint ) ) )
                system_or_die( 'cp -f %s/.squashfs.sqfs /tmp/posterity/%s/%s.sqfs' % ( self.mountpoint, self.fullname, self.fullname ) )
                system_or_die( 'cp -f %s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg /tmp/posterity/%s/%s.kernel' % ( self.mountpoint, self.kernel_src_basedir, self.fullname, self.fullname ) )
                os.system( 'sync;sync;sync' )
                self.update_status( '...backed up.' )
                system_or_die( 'umount /tmp/posterity &> /dev/null' )
        system_or_die( 'cp -f %s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg %s/.kernel.dat' % ( self.mountpoint, self.kernel_src_basedir, self.mountpoint ) )
#        assert( os.path.exists( '%s/.squashfs.sqfs' % ( self.mountpoint ) ) )
#        assert( os.path.exists( '%s/.kernel.dat' % ( self.mountpoint ) ) )
        return 0

    def download_kernel_source( self ):  # This also downloads all the other PKGBUILDs (for btrfs-progs, jfsutils, etc.)
        # Consider using ArchlinuxDistro.download_package_source()
        attempt = 0  # to stop Eclipse from warning :)
        for attempt in range( 3 ):
            try:
                if 0 != system_or_die( 'cd %s && rm -Rf PKGBUILDs && git clone git://github.com/archlinuxarm/PKGBUILDs.git' % ( self.mountpoint + self.ryo_tempdir ), \
                                                        title_str = self.title_str, status_lst = self.status_lst ):
                    failed( 'Failed to use git to clone the kernel source' )
                call_makepkg_or_die( mountpoint = '/',
                                    cmd = 'cd %s && makepkg --skipchecksums --nobuild -f' % ( self.mountpoint + self.kernel_src_basedir ),
                                    errtxt = 'Failed to make/build kernel source',
                                    package_path = self.mountpoint + self.kernel_src_basedir )
                return 0
            except RuntimeError:
                self.update_status( ' git or makepkg failed. Retrying...' )
        failed( 'Failed to download kernel source, even after %d attempts' % ( attempt ) )
#        self.download_package_source( os.path.basename( self.kernel_src_basedir ), ( 'PKGBUILD', ) )

    def configure_winxp_camo_and_guest_default_files( self ):
        install_windows_xp_theme_stuff( self.mountpoint )
        install_mp3_files( self.mountpoint )
#        if os.path.exists( '%s/usr/share/icons/GnomeXP' % ( self.mountpoint ) ):
#            raise RuntimeError( 'I have already installed the groovy XP stuff, FYI.' )
        assert( os.path.exists( '%s/etc/.mp3/winxp.mp3' % ( self.mountpoint ) ) )

    def install_leap_bitmask( self ):
        logme( 'bitmask...' )
        self.update_status( ' Installing leap bitmask' )
        chroot_this( self.mountpoint, 'easy_install-2.7 psutil==1.2.1 leap.common markerlib leap.bitmask' )  # ,status_lst = self.status_lst, title_str = self.title_str )
        if 0 != chroot_this( self.mountpoint, 'which qmake' ):
            chroot_this( self.mountpoint, 'ln -sf `find /usr -type f -name qmake | head -n1` /usr/local/bin/qmake', on_fail = 'Failed to link to qmake' )
        write_oneliner_file( '%s/tmp/install_leap_bitmask.sh' % ( self.mountpoint ), '''#!/bin/bash
failed() {
    echo "$1" >> /dev/stderr
    exit 1
}

#export http_proxy=
#export ftp_proxy=
which pip2 || ln -sf pip-2.7 /usr/bin/pip2
for pkg in keyring pysqlcipher pyOpenSSL ; do
  yes "" 2>/dev/null | pip2 install $pkg || echo "Failed to install $pkg."
done
if ! yes "" 2>/dev/null | pip2 install keyring pysqlcipher pyOpenSSL ; then
    yes "" | easy_install-2.7 keyring pysqlcipher pyOpenSSL
fi
easy_install-2.7 u1db || echo "Warning - error occurred while installing u1db"
cd %s
rm -Rf soledad
git clone https://github.com/leapcode/soledad.git || failed "Failed to pull soledad from git"
cd soledad
git fetch origin
git checkout develop
cd client
if ! yes | python2 setup.py install ; then
    pip2 install leap.soledad || failed "I think I failed to install soledad"
fi
mkdir -p /tmp/qrs
cd /tmp/qrs
rm -f `find /usr/lib/python2.7/site-packages | grep psutil`
easy_install-2.7 psutil==1.2.1
easy_install markerlib leap.common
pip2 install --no-dependencies leap.bitmask || failed "Failed to install leap.bitmask"
chmod 644 -R /usr/lib/python2.7/*
exit 0
''' % ( self.sources_basedir ) )
        os.system( 'chmod +x %s/tmp/install_leap_bitmask.sh' % ( self.mountpoint ) )
        if 0 != chroot_this( self.mountpoint, 'bash /tmp/install_leap_bitmask.sh',
                                        status_lst = self.status_lst, title_str = self.title_str,
                                        attempts = 3 ):
            self.update_status( '...shucks. Failed to install leap.bitmask :-(' )
        else:
            self.update_status( '...yay! Succeeded :-)' )

    def install_freenet( self ):
        self.update_status( 'Freenet...' )
        logme( 'Deleting /opt/freenet' )
        chroot_this( self.mountpoint, 'rm -Rf /opt/freenet',
                     status_lst = self.status_lst, title_str = self.title_str, on_fail = 'Failed to remove old freenet files, if any' )
        logme( 'Deleting freenet from group, passwd, shadow files' )
        for file_stub in ( 'group', 'passwd', 'shadow' ):
            do_a_sed( '%s/etc/%s' % ( self.mountpoint, file_stub ), 'freenet:.*', '' )
        logme( 'Adding freenet user and disabling its login' )
        try:
#        if 0 != chroot_this( self.mountpoint, 'cat /etc/passwd | grep freenet &> /dev/null' ):
            chroot_this( self.mountpoint, 'useradd -d /opt/freenet -m -U freenet',
                          status_lst = self.status_lst, title_str = self.title_str, on_fail = 'Failed to add freenet user' )
        except RuntimeError:
            pass
        chroot_this( self.mountpoint, 'passwd -l freenet',
                          status_lst = self.status_lst, title_str = self.title_str, on_fail = 'Failed to disable freenet user login' )
        write_oneliner_file( '%s/.install_freenet_like_this.sh' % ( self.mountpoint ), '''#!/bin/bash
rm -Rf /opt/freenet/.[a-z]*
rm -Rf /opt/freenet/*
echo "/opt/freenet
1
1
1
" | java -jar /.new_installer_offline.jar -console
res=$?
if [ "$res" -le "1" ] ; then
  exit 0
else
  exit $res
fi
''' )
        system_or_die( 'chmod +x %s/.install_freenet_like_this.sh' % ( self.mountpoint ) )
        write_oneliner_file( '%s/usr/lib/systemd/system/freenet.service' % ( self.mountpoint ), '''[Unit]
Description=An encrypted network without censorship or monitoring.
After=network.target

[Service]
Type=forking
ExecStart=/bin/su freenet -c "/opt/freenet/run.sh start"
ExecStop=/bin/su freenet -c "/opt/freenet/run.sh stop"
WorkingDirectory=/opt/freenet

[Install]
WantedBy=multi-user.target
''' )
        logme( 'Installing freenet from Java jar file' )
        if self.name.find( 'debian' ) >= 0:
            wget( url = 'https://freenetproject.org/jnlp/freenet_installer.jar', save_as_file = '%s/.new_installer_offline.jar' % ( self.mountpoint ),
                                                            status_lst = self.status_lst, title_str = self.title_str )
            chroot_this( self.mountpoint, 'su -l freenet /.install_freenet_like_this.sh', attempts = 1,
                                on_fail = 'Failed to install Freenet',
                                status_lst = self.status_lst, title_str = self.title_str )
            system_or_die( 'rm -f %s/.new_installer_offline.jar' % ( self.mountpoint ) )
            system_or_die( 'rm -f %s/.install_freenet_like_this.sh' % ( self.mountpoint ) )
            if os.path.exists( '%s/opt/freenet/bin/wrapper' % ( self.mountpoint ) ) and os.path.exists( '%s/opt/freenet/run.sh' % ( self.mountpoint ) ):
                system_or_die( 'ln -sf wrapper-linux-armhf-32 %s/opt/freenet/bin/wrapper' % ( self.mountpoint ) )
        else:
            logme( 'OK. Traditional install of freenet failed. I shall do it from tarball instead.' )
            chroot_this( self.mountpoint, 'tar -Jxf /usr/local/bin/Chrubix/blobs/apps/freenet.tar.xz -C /', on_fail = 'Failed to install Freenet from tarball' )
        chroot_this( self.mountpoint, 'chown freenet.freenet /opt/freenet', on_fail = 'Failed to chown freenet folder' )

#    def create_reboot_and_shutdown_wrappers( self ):
#        create_impatient_wrapper( self.mountpoint, 'reboot' )
#        create_impatient_wrapper( self.mountpoint, 'shutdown' )

    def save_for_posterity_if_possible_A( self ):
        return self.save_for_posterity_if_possible( '_A' )

    def save_for_posterity_if_possible_B( self ):
        return self.save_for_posterity_if_possible( '_B' )

    def save_for_posterity_if_possible_C( self ):
        return self.save_for_posterity_if_possible( '_C' )

    def save_for_posterity_if_possible_D( self ):
        return self.save_for_posterity_if_possible( '_D' )

    def able_to_restore_from_posterity_A( self ):
        return self.able_to_restore_from_posterity( '_A' )

    def able_to_restore_from_posterity_B( self ):
        return self.able_to_restore_from_posterity( '_B' )

    def able_to_restore_from_posterity_C( self ):
        return self.able_to_restore_from_posterity( '_C' )

    def able_to_restore_from_posterity_D( self ):
        return self.able_to_restore_from_posterity( '_D' )

    def save_for_posterity_if_possible( self, tailend ):
        res = self.load_or_save_posterity_file( tailend, self.generate_tarball_of_my_rootfs )
        if 0 != res:
            self.update_status( 'Unable to save %s progress for posterity' % ( tailend ) )
#                failed( 'Failed to save for posterity' )
        else:
            logme( 'Saved for posterity. Yay.' )
        return res

    def load_or_save_posterity_file( self, tailend, func_to_call ):
        logme( 'load_or_save_posterity_file() --- entering' )
        os.system( 'mkdir -p /tmp/posterity' )
        if os.system( 'mount | grep /tmp/posterity &> /dev/null' ) == 0 \
        or os.system( 'mount /dev/sda1 /tmp/posterity &> /dev/null' ) == 0 \
        or os.system( 'mount /dev/sdb1 /tmp/posterity &> /dev/null' ) == 0:
            fname = '/tmp/posterity/%s%s/%s%s_%s.xz' % ( self.name,
                                                         '' if self.branch is None else self.branch,
                                                         self.name,
                                                         '' if self.branch is None else self.branch,
                                                         tailend )
            system_or_die( 'mkdir -p %s' % ( os.path.dirname( fname ) ) )
            res = func_to_call( fname )
            logme( '%s(%s) returned %d' % ( func_to_call.__name__, fname, res ) )
            assert( res == 0 )
            logme( 'load_or_save_posterity_file() --- leaving' )
            return res
        else:
            logme( 'Failed to backup/restore' )
            logme( 'load_or_save_posterity_file() --- leaving' )
            return 257

    def nop( self ):
        pass

    def able_to_restore_from_posterity( self, tailend ):
        res = self.load_or_save_posterity_file( tailend, self.write_my_rootfs_from_tarball )
        if 0 == res:
            # I thought about calling load_distro_record() here. Then I decided not to. Why complicate things?
            system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
            system_or_die( 'mkdir -p %s/{dev,sys,proc,tmp}' % ( self.mountpoint, ), "Can't make important dirs" )
            system_or_die( 'mkdir -p %s/usr/local/bin' % ( self.mountpoint, ) )
            mount_sys_tmp_proc_n_dev( self.mountpoint )
            self.update_status( 'Successfully restored %s progress from posterity' % ( tailend ) )
            self.update_and_upgrade_all()
        return res

    def install_mkinitcpio_ramwipe_hooks( self ):  # See https://bbs.archlinux.org/viewtopic.php?id=136283
        install_initcpio_wiperamonshutdown_files( self.mountpoint )

    def forcibly_rebuild_initramfs_and_vmlinux( self ):
        self.update_status( 'Forcibly rebuilding initramfs and vmlinux' )
        self.initrd_rebuild_required = True
#        self.build_kernel_and_mkfs()
        self.redo_mbr( root_partition_device = self.root_dev, chroot_here = self.mountpoint )
        self.update_status( '...rebuilt. ' )
        assert( os.path.exists( '%s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( self.mountpoint, self.kernel_src_basedir ) ) )
        assert( not self.initrd_rebuild_required )
        system_or_die( 'cp -f %s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg /tmp/.vmlinux.uimg' % ( self.mountpoint, self.kernel_src_basedir ) )

    def abort_here( self ):
        failed( 'Now... Save the squash fs file to a thumb drive and re-run the installation script. Ask the author for help if necessary.' )

    def install( self ):
        '''
        At this point, I am chroot()'d to self.root_dev, my /proc, /sys, /tmp, and /dev are mounted,
        and I am ready to install my OS at either self.spare_dev (which I may reformat/assign to crypto
        if I like) or self.root_dev (no formatting allowed, because I 'live' there in .bootstrap).
        Kernel will go in self.kernel_dev of course.
        '''
        logme( 'install() - starting' )
        if ( self.mountpoint is None ):
            failed( 'Please specify mountpoint when you are calling me!' )
        system_or_die( 'mkdir -p ' + self.mountpoint, 'Failed to create self.mountpoint ' + self.mountpoint )
        if 0 != os.system( 'mount %s %s 2> /dev/null' % ( self.root_dev, self.mountpoint ) ) :  #        mount_device( self.root_dev, self.mountpoint )
            if 0 == os.system( 'mount | fgrep " %s " &> /dev/null' % ( self.mountpoint ) ):
                logme( 'Cool. %s is already mounted. Yay.' % ( self.root_dev ) )
            else:
                logme( 'Warning. Failed to mount %s %s' % ( self.root_dev, self.mountpoint ) )
        first_stage = ( 
                                self.install_and_mount_barebones_OS,
                                self.install_locale,
                                self.add_reboot_user,
                                self.add_shutdown_user,
                                self.add_guest_user,
                                self.configure_hostname,
                                self.update_barebones_OS,
                                self.save_for_posterity_if_possible_A )
        second_stage = ( 
                                self.install_all_important_packages_in_OS,
                                self.install_timezone,
                                self.install_i2p,
                                self.install_freenet,
                                self.install_urwid_and_dropbox_uploader,
                                self.install_mkinitcpio_ramwipe_hooks,
                                self.install_chrubix,
                                self.install_moose,
                                self.install_gpg_applet,
                                self.install_leap_bitmask,
                                self.download_modify_build_and_install_kernel_and_mkfs,
                                self.save_for_posterity_if_possible_B )
        third_stage = ( 
                                self.install_final_push_of_packages,  # After this, assume Internet access is gone.
                                self.forcibly_rebuild_initramfs_and_vmlinux,  # Is this necessary?
                                self.save_for_posterity_if_possible_C )
        fourth_stage = ( 
                                self.call_bash_script_that_modifies_kernel_n_mkfs_sources,  # Why are these three lines here?
                                self.build_kernel_and_mkfs,  # ...............................If they work, let's leave them
                                self.install_kernel_and_mkfs,  # .............................alone, but are they needed?
                                self.forcibly_rebuild_initramfs_and_vmlinux,  # ...............What about this? Is this needed too?
                                self.remove_all_junk,
                                self.save_for_posterity_if_possible_D )
        fifth_stage = ( # Chrubix ought to have been installed in MYDISK_MTPT/{dest distro} already, by the stage 1 bash script.
                                self.add_guest_user,
                                self.install_panic_button,
                                self.install_vbutils_and_firmware_from_cbook,
                                self.configure_dbus_sudo_and_groups,
                                self.configure_lxdm_login_manager,
                                self.configure_privacy_tools,
                                self.configure_chrome_or_iceweasel,
                                self.configure_networking,
                                self.configure_sound_speech_and_font_cache,
                                self.configure_winxp_camo_and_guest_default_files,
                                self.configure_xwindow_and_timers,
#                                self.create_reboot_and_shutdown_wrappers,
                                self.install_extra_menu_items_in_gui,
                                self.configure_distrospecific_tweaks,
                                self.install_vbutils_and_firmware_from_cbook,  # just in case the new user's tools differ from the original builder's tools
                                self.squash_OS_or_setup_stage_two,  # ... depending on self.reboot_into_stage_two
                                self.unmount_and_clean_up
                                )
        all_my_funcs = first_stage + second_stage + third_stage + fourth_stage + fifth_stage
        if os.path.exists( '%s/.checkpoint.txt' % ( self.mountpoint ) ):
            checkpoint_number = int( read_oneliner_file( '%s/.checkpoint.txt' % ( self.mountpoint ) ) )
            if checkpoint_number == 9999:
                url_or_fname = read_oneliner_file( '%s/.url_or_fname.txt' % ( self.mountpoint ) )
                self.update_status_with_newline( 'I was restored from %s by the installer bash script; cool.' % ( url_or_fname ) )
                mount_sys_tmp_proc_n_dev( self.mountpoint )  # This line is unnecessary, probably
                if url_or_fname.find( '_D' ) >= 0:        checkpoint_number = len( first_stage ) + len( second_stage ) + len( third_stage ) + len( fourth_stage )
                elif url_or_fname.find( '_C' ) >= 0:      checkpoint_number = len( first_stage ) + len( second_stage ) + len( third_stage )
                elif url_or_fname.find( '_B' ) >= 0:      checkpoint_number = len( first_stage ) + len( second_stage )
                elif url_or_fname.find( '_A' ) >= 0:      checkpoint_number = len( first_stage )
                else:                                     failed( 'Incomprehensible posterity restore - %s' % ( url_or_fname ) )
            else:
                self.update_status_with_newline( 'Cool -- resuming from checkpoint#%d' % ( checkpoint_number ) )
        else:
            checkpoint_number = 0
        logme( 'Starting at checkpoint#%d' % ( checkpoint_number ) )
        assert( self.mountpoint is not None )
        mount_sys_tmp_proc_n_dev( self.mountpoint )
        for myfunc in all_my_funcs[checkpoint_number:]:
            logme( 'Running %s' % ( myfunc.__name__ ) )
            if not os.path.exists( '%s%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( self.mountpoint, self.kernel_src_basedir ) ):
                logme( 'FYI, vmlinux.uimg is missing' )
            if remaining_megabytes_free_on_device( self.root_dev ) < 300:
                chroot_this( self.mountpoint, 'rm -Rf /usr/share/doc' )
                if remaining_megabytes_free_on_device( self.root_dev ) < 300:
                    failed( '%s is nearly full --- you might want to tweak the partitioner in bit.do/that' % ( self.root_dev ) )
            myfunc()
            checkpoint_number += 1
            write_oneliner_file( '%s/.checkpoint.txt' % ( self.mountpoint ), str( checkpoint_number ) )
        logme( 'install() - leaving' )


