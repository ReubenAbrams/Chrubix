#!/usr/local/bin/python3
#
# distros.py


# TODO: Make sure memory is getting wiped at shutdown (play a tune?). See https://bbs.archlinux.org/viewtopic.php?id=136283
import os, sys, shutil, hashlib, getpass, random, pickle, time, chrubix.utils
from chrubix.utils import rootcryptdevice, mount_device, mount_sys_tmp_proc_n_dev, logme, unmount_sys_tmp_proc_n_dev, failed, \
            chroot_this, wget, do_a_sed, system_or_die, write_oneliner_file, read_oneliner_file, call_binary, install_mp3_files, \
            generate_temporary_filename, backup_the_resolvconf_file, install_gpg_applet, patch_kernel, \
            fix_broken_hyperlinks, disable_root_password, install_windows_xp_theme_stuff, running_on_a_test_rig
from chrubix.utils.postinst import append_lxdm_post_login_script, append_lxdm_pre_login_script, append_lxdm_post_logout_script, \
            append_lxdm_xresources_addendum, generate_wifi_manual_script, generate_wifi_auto_script, \
            install_guest_browser_script, configure_privoxy, add_speech_synthesis_script, \
            configure_lxdm_onetime_changes, configure_lxdm_behavior, configure_lxdm_service, \
            install_chrome_or_iceweasel_privoxy_wrapper, remove_junk, tweak_xwindow_for_cbook, install_panicbutton, \
            check_and_if_necessary_fix_password_file, install_insecure_browser, append_proxy_details_to_environment_file, \
            setup_timer_to_keep_dpms_switched_off, write_lxdm_service_file
import chrubix
from chrubix.utils.mbr import install_initcpio_wiperamonshutdown_files
from xml.dom import NotFoundErr

# FIXME: paman and padevchooser are deprecated
class Distro():
    '''
    '''
    # Class-level consts
    hewwo = '2014/06/15 @ 18:41'
    crypto_rootdev = "/dev/mapper/cryptroot"
    crypto_homedev = "/dev/mapper/crypthome"
    boot_prompt_string = "boot: "
    guest_homedir = "/tmp/.guest"
    stop_jfs_hangsup = "echo 0 > /proc/sys/kernel/hung_task_timeout_secs"
    boom_pw_hash_fname = "/etc/.sha512bm"
    boomfname = "/etc/.boom"
    ryo_tempdir = "/root/.rmo"
    kernel_cksum_fname = ".k.bl.ck"
    loglevel = "2"
    tempdir = "/tmp"
    important_packages = 'xmlto man xmltoman intltool squashfs-tools aircrack-ng gnome-keyring \
liferea gobby busybox bzr cpio cryptsetup curl lzop ed parted libtool patch git nano bc pv pidgin \
python3 python-pip python-setuptools python-crypto python-yaml python-gobject rng-tools \
sudo tzdata unzip wget flex gcc bison autoconf dillo \
gnupg mpg123 pavucontrol ttf-dejavu bluez pulseaudio ffmpeg mplayer notification-daemon ttf-liberation \
ntfs-3g autogen automake docbook-xsl pkg-config dosfstools expect acpid make pwgen asciidoc \
xterm xscreensaver rxvt rxvt-unicode smem python-qrencode python-imaging \
gimp inkscape scribus audacity pitivi poedit alsa-utils libcanberra-pulse sound-juicer \
simple-scan macchanger brasero pm-utils mousepad keepassx claws-mail bluez-utils \
'  # palimpsest gnome-session-fallback mate-settings-daemon-pulseaudio
    final_push_packages = 'lxde tor privoxy vidalia systemd syslog-ng gnome-tweak-tool'  # Install these, all at once, when we're ready to break the Internet :)
    # Instance-level attributes
    def __init__( self, *args, **kwargs ):
        self.name = None
        self.branch = None
        self.__args = args
        self.__pheasants = False  # If True, the new kernel will reject all USB/MMC until the one is found on which the OS resides
        self.__kthx = False  # if True, the new kernel will use regular (not randomized) markers for filesystems
        self.__crypto_filesystem_format = 'ext4'
        self.__device = '/dev/null'  # e.g. /dev/mmcblk1
        self.__kernel_dev = '/dev/null'  # e.g. /dev/mmcblk1p1
        self.__spare_dev = '/dev/null'  # e.g. /dev/mmcblk1p2
        self.__root_dev = '/dev/null'  # e.g. /dev/mmcblk1p3
        self.__boom_pw_hash = None
        self.architecture = None
        self.kernel_rebuild_required = False
        self.randomized_serial_number = None
        self.package_group_size = 8
        self.status_lst = []
        self.mountpoint = None  # not mounted yet :)
        self.list_of_mkfs_packages = None  # This will be defined by subclass
        self.typical_install_duration = -1
        self.use_latest_kernel = False
        self.lxdm_settings = {'window manager':chrubix.utils.g_default_window_manager,
                              'default wm':chrubix.utils.g_default_window_manager,
                              'enable user lists':True,
                              'autologin':True,
                              'use greeter gui':False,  # Technically, we always call greeter. This switch forces us to use (or not use) the 'scary eyes' X (GUI) side of the greeter.
                              'user':'guest'
                              }
        self.__dict__.update( kwargs )

    def configure_distrospecific_tweaks( self ):  failed( "please define in subclass" )
    def install_barebones_root_filesystem( self ):  failed( "please define in subclass" )
    def download_mkfs_sources( self ):              failed( "please define in subclass" )
    def build_package( self, source_pathname ):     failed( "build_package(%s) --- please define in subclass" % ( source_pathname ) )
    def install_package_manager_tweaks( self ):     failed( "please define in subclass. Don't forget! Exclude jfsprogs, btrfsprogs, xfsprogs, linux kernel." )
    def update_and_upgrade_all( self ):             failed( "please define in subclass" )
    def install_important_packages( self ):         failed( "please define in subclass" )
    def install_kernel_and_mkfs( self ):            failed( 'please define in subclass' )
    def install_locale( self ):                     failed( 'please define in subclass' )
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
            logme( 'qqq Because you changed the value of self.pheasants, a rebuild is required.' )
            self.kernel_rebuild_required = True

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
    def crypto_filesystem_format( self ):
        return self.__crypto_filesystem_format
    @crypto_filesystem_format.setter
    def crypto_filesystem_format( self, value ):
        if read_oneliner_file( '/proc/cmdline' ).find( 'cros_secure' ) < 0:
            self.__crypto_filesystem_format = value
        else:
            raise EnvironmentError( "You cannot use %s (a non-ext4 fs) while you're running in ChromeOS" % ( value ) )

    @property
    def initramfs_directory( self ):
        return self.ryo_tempdir + "/initramfs_dir"

    @property
    def crypto_filesystem_formatting_options( self ):
        dct = {'ext4':'-v', 'xfs':'-f', 'jfs':'-f', 'btrfs':'-f -O ^extref'}
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
            self.__kthx = value
            logme( 'qqq Because you changed the value of self.kthx, a rebuild is required.' )
            self.kernel_rebuild_required = True

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
        logme( 'qqq Because you changed the value of the boom password, a rebuild is required.' )
        self.kernel_rebuild_required = True
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

    def build_mkfs( self ):
        self.status_lst.append( ['Building mk*fs'] )
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
        self.status_lst[-1] += '...mk*fs built.'

    def build_kernel( self ):
        self.status_lst.append( ['Building kernel'] )
        self.build_package( self.kernel_src_basedir )  # , 302200 )
        if self.use_latest_kernel:
            chroot_this( self.mountpoint, '\
cd %s/linux-latest && \
cat ../linux-chromebook/config | sed s/ZSMALLOC=.*/ZSMALLOC=y/ > .config && \
yes "" 2>/dev/null | make oldconfig && \
make' % ( self.sources_basedir ), title_str = self.title_str, status_lst = self.status_lst )
        self.status_lst[-1] += '...kernel built.'

    def redo_mbr_for_encrypted_root( self, chroot_here ):
        self.redo_mbr( root_partition_device = self.crypto_rootdev, chroot_here = chroot_here )

    def redo_mbr_for_plain_root( self, chroot_here ):
        self.redo_mbr( root_partition_device = self.root_dev, chroot_here = chroot_here )

    def redo_mbr( self, root_partition_device, chroot_here ):  # ,root_partition_dev             ... Also generates hybrid initramfs
        res = 0
        logme( 'redo_mbr() --- starting' )
        for save_here in ( chroot_here, '/' ):
            system_or_die( 'tar -zxvf /tmp/.vbkeys.tgz -C %s' % ( save_here ),
                                status_lst = self.status_lst, title_str = self.title_str )
        if self.kernel_rebuild_required:
            logme( 'qqq Rebuilding kernel' )
            if not os.path.isdir( '%s%s' % ( chroot_here, self.kernel_src_basedir ) ):
                failed( "The kernel's source folder is missing. Please install it." )
            system_or_die( 'mkdir -p %s/%s' % ( chroot_here, self.initramfs_directory ) )
            if self.boom_pw_hash is None:
                logme( 'WARNING - no boom password hash' )
            write_oneliner_file( chroot_here + self.boom_pw_hash_fname, '' if self.boom_pw_hash is None else self.boom_pw_hash )
            system_or_die( 'tar -zxf /tmp/.vbkeys.tgz -C %s' % ( chroot_here ), title_str = self.title_str, status_lst = self.status_lst )
            if self.name == 'debian':
                self.status_lst.append( ['Doing Debian-specific mods'] )
                chroot_this( chroot_here, 'busybox', on_fail = 'You are using the bad busybox.' , title_str = self.title_str, status_lst = self.status_lst )
#            if 0 != chroot_this( chroot_here, 'bash /usr/local/bin/redo_mbr.sh %s %s %s' % ( self.device, chroot_here, root_partition_device ),
#                                                        title_str = self.title_str, status_lst = self.status_lst,
#                                                        attempts = 1 ):
            self.status_lst.append( ['Rerunning redo_mbr.sh'] )
            system_or_die( 'bash %s/usr/local/bin/redo_mbr.sh %s %s %s' % ( chroot_here,
                                                        self.device, chroot_here, root_partition_device ),
                                                        errtxt = 'Failed to redo kernel & mbr',
                                                        title_str = self.title_str, status_lst = self.status_lst )
            f = '%s%s/src/chromeos-3.4/drivers/mmc/core/mmc.c' % ( chroot_here, self.kernel_src_basedir )
            g = '%s%s/src/chromeos-3.4/fs/btrfs/ctree.h' % ( chroot_here, self.kernel_src_basedir )
            assert( os.path.exists( f ) )
            assert( os.path.exists( g ) )
            if os.path.exists( '%s.phezSullied' % f ):
                assert( os.path.exists( '%s.kthxSullied' % g ) )
                assert( 0 == os.system( 'diff %s.phez%s %s' % ( f, 'Sullied' if self.pheasants else 'Pristine', f ) ) )
                assert( 0 == os.system( 'diff %s.kthx%s %s' % ( g, 'Sullied' if self.kthx else 'Pristine', g ) ) )
            else:
                assert( not os.path.exists( '%s.kthxSullied' % g ) )
                self.status_lst.append( ['Warning - source code was never modified. I hope that is not a bad sign.'] )
            self.kernel_rebuild_required = False
        else:
            logme( 'qqq No need to rebuild kernel. Merely signing existing kernel' )
            if root_partition_device.find( '/dev/mapper' ) >= 0:
                param_A = 'cryptdevice=%s:%s' % ( self.spare_dev, os.path.basename( root_partition_device ) )
            else:
                param_A = self.root_dev
            param_B = ''
            res = self.sign_and_write_custom_kernel( root_partition_device, param_A, param_B )
        logme( 'redo_mbr() --- leaving w/ res=%d' % ( res ) )
        return res

    def sign_and_write_custom_kernel( self, my_root_device, extra_params_A, extra_params_B ):
        print( "Writing kernel to boot device (replacing nv_u-boot)..." )
        kernel_flags_fname = '%s/root/.kernel.flags' % ( self.mountpoint )
        raw_kernel_fname = '%s/%s/src/chromeos-3.4/arch/arm/boot/vmlinux.uimg' % ( self.mountpoint, self.kernel_src_basedir )
        signed_kernel_fname = '%s/root/.vmlinuz.signed' % ( self.mountpoint )
        readwrite = 'rw'
        loglevel_str = 'loglevel=%s' % ( self.loglevel )
        write_oneliner_file( kernel_flags_fname,
 'console=tty1 %s root=%s rootwait %s quiet systemd.show_status=0 %s lsm.module_locking=0 init=/sbin/init %s' \
                            % ( extra_params_A, my_root_device, readwrite, loglevel_str, extra_params_B ) )
        system_or_die( 'dd if=/dev/zero of=%s bs=1k count=1 2> /dev/null' % ( self.kernel_dev ) )
        system_or_die( 'vbutil_kernel --pack %s --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --config %s/root/.kernel.flags --vmlinuz %s --arch arm' \
                            % ( signed_kernel_fname, self.mountpoint, raw_kernel_fname ) )
        system_or_die( 'dd if=%s of=%s' % ( signed_kernel_fname, self.kernel_dev ), "Failed to write kernel" )
        return 0

    def install_vbutils_from_cbook( self ):
        system_or_die( 'tar -zxvf /tmp/.hipxorg.tgz -C %s' % ( self.mountpoint ),
                      status_lst = self.status_lst, title_str = self.title_str )
        system_or_die( 'tar -zxvf /tmp/.vbtools.tgz -C %s' % ( self.mountpoint ),
                      status_lst = self.status_lst, title_str = self.title_str )

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

    def set_root_password( self ):
        os.system( 'clear' )
        user = call_binary( ['whoami'] )[1].strip()
        if user not in ( b'root', 'root', '0' , 0 ):
            raise SystemError( "You should be running me as root, but you are running me as %s" % ( user, ) )
        res = 999
        cmd = 'passwd' if self.mountpoint in ( None, '/' ) else 'chroot %s passwd' % ( self.mountpoint, )
        while res != 0:
            if os.system( 'ps -o pid -C X &>/dev/null' ) == 0 and read_oneliner_file( '/proc/cmdline' ).find( 'cros_secure' ) < 0:
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
        self.kernel_rebuild_required = True
        return 0

    def modify_kernel_and_mkfs_sources( self, apply_kali_and_unionfs_patches = True ):
        logme( 'modify_kernel_and_mkfs_sources() --- starting' )
        if apply_kali_and_unionfs_patches:
            patch_kernel( self.mountpoint, self.kernel_src_basedir + '/src/chromeos-3.4', 'http://patches.aircrack-ng.org/mac80211.compat08082009.wl_frag+ack_v1.patch' )
            patch_kernel( self.mountpoint, self.kernel_src_basedir + '/src/chromeos-3.4', 'http://download.filesystems.org/unionfs/unionfs-2.x/unionfs-2.5.13_for_3.4.84.diff.gz' )
        self.status_lst[-1] += '...patched'
        self.call_bash_script_that_modifies_kernel_n_mkfs_sources()
        self.status_lst[-1] += '...customized'
        assert( 0 == os.system( 'cat %s%s/config | grep UNION_FS' % ( self.mountpoint, self.kernel_src_basedir ) ) )

    def call_bash_script_that_modifies_kernel_n_mkfs_sources( self ):
        self.status_lst.append( ['Modifying kernel and mkfs sources'] )
        # FIXME: Examine modify_sources.sh; grep it for TTTTTTTTTT; is that section necessary? Run some tests. Find out.
        system_or_die( 'bash /usr/local/bin/modify_sources.sh %s %s %s %s' % ( 
                                                                self.device,
                                                                self.mountpoint,
                                                                'yes' if self.pheasants else 'no',
                                                                'yes' if self.kthx else 'no',
                                                                ), "Failed to modify kernel/mkfs sources", title_str = self.title_str, status_lst = self.status_lst )
        self.randomized_serial_number = read_oneliner_file( '%s/etc/.randomized_serno' % ( self.mountpoint ) )

    def download_modify_and_build_kernel_and_mkfs( self ):
        logme( 'modify_build_and_install_mkfs_and_kernel_for_OS() --- starting' )
        diy = True
        if running_on_a_test_rig():
            fname = '/tmp/posterity/%s_PKGBUILDs.tgz' % ( self.name + ( '' if self.branch is None else self.branch ) )
            mounted = False
            system_or_die( 'mkdir -p /tmp/posterity' )
            if os.system( 'mount /dev/sda4 /tmp/posterity &> /dev/null' ) == 0 \
            or os.system( 'mount /dev/sdb4 /tmp/posterity &> /dev/null' ) == 0 \
            or os.system( 'mount | grep /tmp/posterity &> /dev/null' ) == 0:
                mounted = True
                if os.path.exists( fname ):
                    diy = False
        if diy:
            self.download_kernel_and_mkfs_sources()
            self.modify_kernel_and_mkfs_sources( apply_kali_and_unionfs_patches = True )
            self.build_kernel_and_mkfs()
        else:
            system_or_die( 'rm -Rf %s%s' % ( self.mountpoint, self.ryo_tempdir ) )
            system_or_die( 'mkdir -p %s%s' % ( self.mountpoint, self.ryo_tempdir ) )
            system_or_die( 'tar -zxf %s -C %s%s' % ( fname, self.mountpoint, self.ryo_tempdir ), status_lst = self.status_lst, title_str = self.title_str )
            system_or_die( 'mkdir -p %s%s/initramfs_dir' % ( self.mountpoint, self.ryo_tempdir ) )
        f = '%s%s/src/chromeos-3.4/drivers/mmc/core/mmc.c' % ( self.mountpoint, self.kernel_src_basedir )
        g = '%s%s/src/chromeos-3.4/fs/btrfs/ctree.h' % ( self.mountpoint, self.kernel_src_basedir )
        assert( os.path.exists( f ) )
        assert( os.path.exists( g ) )
        if os.path.exists( '%s.phezSullied' % f ) and os.path.exists( '%s.kthxSullied' % g ):
            assert( 0 == os.system( 'diff %s.phez%s %s' % ( f, 'Sullied' if self.pheasants else 'Pristine', f ) ) )
            assert( 0 == os.system( 'diff %s.kthx%s %s' % ( g, 'Sullied' if self.kthx else 'Pristine', g ) ) )
        else:
            if diy:
                failed( 'OK, that is messed up! I downloaded AND modified AND built the sources, but they appear not to have been modified.' )
            else:
                failed( 'OK, that is messed up! My PKGBUILDs.tgz tarball includes unmodified sources, but that tarball was allegedly created AFTER I had modified the sources. WTF?' )
        if mounted:
            chroot_this( '/', 'cd %s%s && tar -cz PKGBUILDs > %s' % ( self.mountpoint, self.ryo_tempdir, fname ),
                                                    status_lst = self.status_lst, title_str = self.title_str )
            system_or_die( 'sync;sync;sync;umount /tmp/posterity' )
        self.install_kernel_and_mkfs()

    def download_kernel_and_mkfs_sources( self ):
        logme( 'download_kernel_and_mkfs_sources() --- starting' )
        self.status_lst.append( [ "Setting up build environment" ] )
        system_or_die( "rm -Rf %s" % ( self.mountpoint + self.ryo_tempdir ) )
        system_or_die( "mkdir -p %s" % ( self.mountpoint + self.ryo_tempdir ) )
        self.status_lst[-1] += '...Downloading kernel'
        self.download_kernel_source()  # Must be done before mkfs. Otherwise, 'git' complains & quits.
        if self.use_latest_kernel:
            self.download_latest_kernel_src()
            system_or_die( 'cp -f %s%s/config %s%s/linux-latest/.config' % ( self.mountpoint, self.kernel_src_basedir, self.mountpoint, self.sources_basedir ) )
        self.status_lst[-1] += '...Downloading mk*fs'
        self.download_mkfs_sources()
        self.status_lst[-1] += '...downloaded.'

    def download_latest_kernel_src( self ):
        logme( 'Downloading latest kernel source from kernel.org' )
        system_or_die( '''curl https://www.kernel.org/`curl https://www.kernel.org -o - | fgrep tar.xz | grep -v testing | head -n1 | tr '"' '\n' | fgrep tar.xz` -o %s%s/latest-kernel.tar.xz''' % ( self.mountpoint, self.sources_basedir ),
                             title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( '''cd %s%s && mkdir -p abq && cd abq && tar -Jxf ../latest-kernel.tar.xz && mv linux-* linux-latest && mv linux-latest .. && cd .. && rmdir abq''' % ( self.mountpoint, self.sources_basedir ),
                                    title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'rm -f %s%s/latest-kernel.tar.xz''' % ( self.mountpoint, self.sources_basedir ) )

    def build_kernel_and_mkfs( self ):
        self.build_mkfs()
        self.build_kernel()  # also makes sara lee initramfs

    def install_timezone( self ):
#        print( "Installing timezone" )
        utc_hour_str = call_binary( ['date', '-u', '+%H'] )[1].decode( 'utf-8' )
        loc_hour_str = call_binary( ['date', '+%H'] )[1].decode( 'utf-8' )
#        print( 'utc_hour_str =', utc_hour_str )
#        print( 'loc_hour_str =', loc_hour_str )
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
        system_or_die( 'echo -en "\n%%wheel ALL=(ALL) ALL\nALL ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff,/usr/bin/systemctl halt,/usr/bin/systemctl reboot,/usr/local/bin/tweak_lxdm_and_reboot,/usr/local/bin/tweak_lxdm_and_shutdown,/usr/local/bin/run_as_guest.sh,/usr/local/bin/chrubix.sh\n" >> %s/etc/sudoers' % ( self.mountpoint ) )
        for group_to_add_me_to in ( '%s' % ( 'debian-tor' if self.name == 'debian' else 'tor' ), 'freenet', 'audio', 'pulse-access' ):
            logme( 'Adding guest to %s' % ( group_to_add_me_to ) )
            if group_to_add_me_to != 'pulse-access' and 0 != chroot_this( 
                                        self.mountpoint, 'usermod -a -G %s guest' % ( group_to_add_me_to ),
                                        title_str = self.title_str, status_lst = self.status_lst ):
                failed( 'Failed to add guest to group %s' % ( group_to_add_me_to ) )

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
            chroot_this( self.mountpoint, 'systemctl disable %s' % ( pkg ) , title_str = self.title_str, status_lst = self.status_lst )
#        if failed_comment != '':
#            self.status_lst.append( ['Failed to handle%s as part of wifi configuration stage' % ( failed_comment )] )
# If the user is online, start the Display Manager. If not, start nmcli (which will let the user choose a wifi connection).
        generate_wifi_manual_script( '%s/usr/local/bin/wifi_manual.sh' % ( self.mountpoint ) )
        generate_wifi_auto_script( '%s/usr/local/bin/wifi_auto.sh' % ( self.mountpoint ) )
        chroot_this( self.mountpoint, 'chmod u+s `which ping`' , title_str = self.title_str, status_lst = self.status_lst )

    def migrate_all_data( self, new_mountpt ):
#        self.status_lst.append( ['Migrating all data to the encrypted partition'] )
        res = 999
        while res != 0:
            print( "" )
            os.system( 'clear' )
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
            res = chroot_this( self.mountpoint, 'cryptsetup open %s %s' % ( self.spare_dev, os.path.basename( self.crypto_rootdev ) ) )
            if res != 0:
                print( 'Cryptsetup returned an error during second call' )
        os.system( 'clear' )
        print( """Rules for the 'boom' password:-
    1. Don't leave it blank.
    2. Don't use 'boom'.
    3. Don't reuse another password.
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
        system_or_die( 'yes 2> /dev/null | mkfs.%s %s %s' % ( self.crypto_filesystem_format, self.crypto_filesystem_formatting_options, self.crypto_rootdev ) , title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'mv %s/etc/fstab %s/etc/fstab.orig' % ( self.mountpoint, self.mountpoint ) )
        system_or_die( 'cat %s/etc/fstab.orig | grep -v " /boot " | grep -v " / " > %s/etc/fstab' % ( self.mountpoint, self.mountpoint ) )
        self.status_lst.append( ['Migrating OS to encrypted volume'] )
        write_oneliner_file( self.boom_pw_hash_fname, '' if self.boom_pw_hash is None else self.boom_pw_hash )  # FIXME: This line might be unnecessary
        system_or_die( 'mkdir -p ' + new_mountpt )
        mount_device( self.crypto_rootdev, new_mountpt )
        for my_dir in ( 'bin', 'boot', 'etc', 'home', 'lib', 'mnt', 'opt', 'root', 'run', 'sbin', 'srv', 'usr', 'var' ):
            self.status_lst[-1] += '..%s' % ( my_dir )
            system_or_die( 'cp -af %s/%s %s' % ( self.mountpoint, my_dir, new_mountpt ), status_lst = self.status_lst, title_str = self.title_str )
        self.status_lst[-1] += "..OK."

    def generate_tarball_of_my_rootfs( self, output_file ):
        logme( 'generate_tarball_of_my_rootfs() - started - output_file=%s' % ( output_file ) )
        self.status_lst.append( ['Creating tarball %s of my rootfs' % ( output_file )] )
        dirs_to_backup = 'bin boot etc home lib mnt opt root run sbin srv usr var'
        if output_file[-2:] != '_D':
            for dir_name in dirs_to_backup.split( ' ' ):
                dirs_to_backup += ' .bootstrap/%s' % ( dir_name )
        system_or_die( 'cd %s && tar -cJ %s | dd bs=32k > %s/temp.data' % ( self.mountpoint, dirs_to_backup, os.path.dirname( output_file ) ), title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'mv %s/temp.data %s' % ( os.path.dirname( output_file ), output_file ) )
        self.status_lst[-1] += '...created.'
        logme( 'generate_tarball_of_my_rootfs() - leaving' )
        return 0

    def write_my_rootfs_from_tarball( self, fname ):
        self.status_lst.append( ['Restoring rootfs from %s' % ( fname )] )
        if os.path.exists( fname ):
            system_or_die( 'tar -Jxf %s -C %s' % ( fname, self.mountpoint ), title_str = self.title_str, status_lst = self.status_lst )
            self.status_lst[-1] += '...restored.'
            return 0
        else:
            self.status_lst[-1] += '...Nope, sorry. Failed.'
            del self.status_lst[-1]
            return 998

    def install_and_mount_barebones_OS( self ):
        self.status_lst.append( ["Downloading and installing skeleton" ] )
        system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
        self.install_barebones_root_filesystem()
        system_or_die( 'mkdir -p %s/{dev,sys,proc,tmp}' % ( self.mountpoint, ), "Can't make important dirs" )
        backup_the_resolvconf_file( self.mountpoint )
        self.status_lst[-1] += '...installed.'
        system_or_die( 'mkdir -p %s/usr/local/bin' % ( self.mountpoint, ) )
        self.status_lst.append( ["Mounting partitions"] )
        mount_sys_tmp_proc_n_dev( self.mountpoint )
        self.status_lst[-1] += '...mounted.'
#        assert( 0 == chroot_this( self.mountpoint, '' ) )

    def update_barebones_OS( self ):
        self.status_lst.append( ["Updating skeleton"] )
        self.install_package_manager_tweaks()
        self.update_and_upgrade_all()
        self.status_lst[-1] += "...updated."

    def install_all_important_packages_in_OS( self ):
        self.status_lst.append( ['Installing OS' ] )
        mount_sys_tmp_proc_n_dev( self.mountpoint )  # Shouldn't be necessary...
        self.install_important_packages()

    def install_urwid_and_dropbox_uploader( self ):
        self.status_lst.append( ['Installing dropbox uploader, Python easy_install, and urwid' ] )
        chroot_this( self.mountpoint, 'which easy_install3 2>/dev/null && easy_install3 urwid', status_lst = self.status_lst, title_str = self.title_str )
        self.status_lst[-1] += '.'
        chroot_this( self.mountpoint, 'which easy_install  2>/dev/null && easy_install  urwid', status_lst = self.status_lst, title_str = self.title_str )
        self.status_lst[-1] += '.'
        for my_executable in ( 'mkinitcpio', 'dtc' ):
            chroot_this( self.mountpoint, 'which %s &> /dev/null' % ( my_executable ), on_fail = 'Programmer forgot to install %s as part of %s distro' % ( my_executable, self.name ) )
        self.status_lst[-1] += '.'
        wget( url = 'https://raw.github.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh', save_as_file = self.mountpoint + '/usr/local/bin/dropbox_uploader.sh', \
                                            title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'chmod +x %s/usr/local/bin/dropbox_uploader.sh' % ( self.mountpoint ) )
        if not os.path.exists( '%s/etc/mtab' % ( self.mountpoint ) ):
            system_or_die( 'ln -sf /proc/mounts %s/etc/mtab' % ( self.mountpoint ) )
        self.status_lst[-1] += '...word.'

    def install_panic_button( self ):
        install_panicbutton( self.mountpoint , self.boomfname )

    def configure_hostname( self ):
        write_oneliner_file( '%s/etc/hostname' % ( self.mountpoint ), self.name )

    def configure_xwindow_for_chromebook( self ):
        tweak_xwindow_for_cbook( self.mountpoint )
        setup_timer_to_keep_dpms_switched_off ( self.mountpoint )

    def configure_lxdm_login_manager( self ):
        configure_lxdm_onetime_changes( self.mountpoint )
        configure_lxdm_behavior( self.mountpoint, self.lxdm_settings )
        configure_lxdm_service( self.mountpoint )

    def tweak_resolv_conf_file( self ):
        system_or_die( 'echo -en "search localhost\nnameserver 8.8.8.8\n" >> %s/etc/resolv.conf' % ( self.mountpoint ) )

    def install_gpg_applet( self ):
        install_gpg_applet( self.mountpoint )

    def configure_privacy_tools( self ):
        configure_privoxy( self.mountpoint )
        append_proxy_details_to_environment_file( '%s/etc/environment' % ( self.mountpoint ) )

    def configure_chrome_or_iceweasel( self ):
        install_chrome_or_iceweasel_privoxy_wrapper( self.mountpoint )
        install_insecure_browser ( self.mountpoint )
        install_guest_browser_script( self.mountpoint )  # TODO: I'm not sure... Is this script still necessary?

    def configure_speech_synthesis_and_font_cache( self ):
        add_speech_synthesis_script( self.mountpoint )
        chroot_this( self.mountpoint, 'fc-cache' )

    def add_reboot_user( self ):
        self.add_user_SUB( 'reboot' )

    def add_shutdown_user( self ):
        self.add_user_SUB( 'shutdown' )

    def add_user_SUB( self, username ):
        cmd = username if username != 'shutdown' else 'poweroff'
        userhome = '/etc/.%s' % ( username )
        chroot_this( self.mountpoint, "mkdir -p %s" % ( userhome ), attempts = 1, on_fail = 'Failed to mkdir for %s' % ( username ) )
        chroot_this( self.mountpoint, "useradd %s -d %s" % ( username, userhome ), attempts = 1, on_fail = 'Failed to add user %s' % ( username ) )
        chroot_this( self.mountpoint, "chmod 700 %s" % ( userhome ), attempts = 1, on_fail = 'Failed to chmod for user %s' % ( username ) )
        do_a_sed( '%s/etc/shadow' % ( self.mountpoint ), r'%s:!:' % ( username ), r'%s::' % ( username ) )
        do_a_sed( '%s/etc/passwd' % ( self.mountpoint ), r'%s:!:' % ( username ), r'%s::' % ( username ) )

#        chroot_this( self.mountpoint, "cat %s | sed s/%s':.:'/%s'::'/ > /etc/shadow" % ( tmpfile, username, username ) )
        profile_fname = '%s%s/.profile' % ( self.mountpoint, userhome )
        write_oneliner_file( profile_fname, '''#!/bin/sh
sudo tweak_lxdm_and_%s
''' % ( username ) )
        system_or_die( 'chmod +x %s' % ( profile_fname ) )
        chroot_this( self.mountpoint, "chown -R %s.%s %s" % ( username, username, userhome ), attempts = 1, on_fail = 'Failed to modify permissions of %s config file' % ( username ) )
        write_oneliner_file( '%s/usr/local/bin/tweak_lxdm_and_%s' % ( self.mountpoint, username ), '''#!/bin/sh
sync;sync;sync
systemctl %s
exit 0
    ''' % ( cmd ) )
        system_or_die( 'chmod +x %s/usr/local/bin/tweak_lxdm_and_%s' % ( self.mountpoint, username ) )

    def add_guest_user( self ):
        passwd_file = '%s/etc/passwd' % ( self.mountpoint )
        chroot_this( self.mountpoint, 'mkdir -p %s' % ( self.guest_homedir ), on_fail = 'Failed to mkdir for guest' )
        chroot_this( self.mountpoint, 'chmod 777 %s' % ( self.guest_homedir ), on_fail = 'Failed to chmod guest' )
        chroot_this( self.mountpoint, 'useradd guest -d %s' % ( self.guest_homedir ) , on_fail = "Failed to add user guest" )
        chroot_this( self.mountpoint, 'chmod 700 %s' % ( self.guest_homedir ), on_fail = 'Failed to chmod guest' )
        do_a_sed( passwd_file, r'guest:x:', r'guest::' )

    def remove_all_junk( self ):
        # Tidy up the actual OS
        if not os.path.exists( '%s%s' % ( self.mountpoint, self.kernel_src_basedir ) ):
            failed( 'For some reason, the linux-chromebook folder is missing from the bootstrap OS. That is not good!' )
        self.status_lst.append( ['Removing superfluous files and diretories from OS'] )
        remove_junk( self.mountpoint, self.kernel_src_basedir )
        if not os.path.exists( '%s%s' % ( self.mountpoint, self.kernel_src_basedir ) ):
            failed( 'remove_junk() deletes the linux-chromebook folder from the bootstrap OS. That is not good!' )
        # Tidy up Alarpy, the (bootstrap) mini-OS
        # FYI, these next three lines MAY SEEM utterly pointless if we delete the bootstrap & use the new, 'native' bootstrap distro.
        # However, we need to make room for squashfs.sqfs, just in case we need to make it.
        try:
            system_or_die( '''cd /usr/share/locale; mv locale.alias ..; mkdir -p _; mv [a-d,f-z]* _; mv e[a-m,o-z]* _; rm -Rf _; mv ../locale.alias .''' )
        except RuntimeError:
            logme( 'Failed to slim down the locale folder. IDGAF.' )
        os.system( 'rm -Rf /usr/include /usr/lib/gcc /usr/lib/python2.7' )
        os.system( 'rm -Rf /usr/share/perl5 /usr/share/xml' )
        self.status_lst[-1] += '...removed.'

    def reinstall_chrubix_for_mosO( self ):
        system_or_die( 'mv %s/usr/local/bin/Chrubix* %s/usr/local/bin/Chrubix' % ( self.mountpoint, self.mountpoint ) )
        system_or_die( 'cp -f /usr/local/bin/Chrubix/bash/chrubix.sh %s/usr/local/bin/Chrubix/bash/chrubix.sh' % ( self.mountpoint ) )  # FIXME: This line is probably redundant. Remove it & see what happens.
        system_or_die( 'cp /usr/local/bin/Chrubix/bash/chrubix.sh %s/usr/local/bin/Chrubix/bash/chrubix.sh' % ( self.mountpoint ) )
        system_or_die( 'ln -sf Chrubix/bash/chrubix.sh %s/usr/local/bin/chrubix.sh' % ( self.mountpoint ) )
        system_or_die( 'ln -sf Chrubix/bash/ersatz_lxdm.sh %s/usr/local/bin/ersatz_lxdm.sh' % ( self.mountpoint ) )
        try:
            wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz',
              decompression_flag = 'J', extract_to_path = '%s/usr/local/bin/Chrubix' % ( self.mountpoint ), quiet = True )
        except SystemError:
            self.status_lst.append( ['Failed to install new version via wget. That sucks. Let us continue anyway...'] )
        os.system( 'clear; sleep 1; sync;sync;sync; clear' )
        chroot_this( self.mountpoint, 'chmod +x /usr/local/bin/*' )

    def migrate_or_squash_OS( self ):  # FYI, the Alarmist distro (subclass) redefines this subroutine to disable root pw and squash the OS
#        if not os.path.exists( '%s/usr/local/bin/Chrubix' % ( self.mountpoint ) ) :
#            self.status_lst.append( ['Someone deleted Chrubix from bootstrapped OS. Fine. I shall reinstall it.'] )
        if 0 != wget( url = 'https://github.com/ReubenAbrams/Chrubix/archive/master.tar.gz',
                            extract_to_path = '%s/usr/local/bin' % ( self.mountpoint ), decompression_flag = 'z',
                            quiet = True, status_lst = self.status_lst, title_str = self.title_str ):
            failed( 'Failed to install Chrubix in bootstrap OS' )
        self.reinstall_chrubix_for_mosO()
        self.status_lst.append( ['Migrating/squashing OS'] )
        assert( os.path.exists( '%s/usr/local/bin/chrubix.sh' % ( self.mountpoint ) ) )
        assert( os.path.exists( '%s/usr/local/bin/ersatz_lxdm.sh' % ( self.mountpoint ) ) )
        write_lxdm_service_file( '%s/usr/lib/systemd/system/lxdm.service' % ( self.mountpoint ) )  # TODO: Remove after 7/1/2014
        system_or_die( 'rm -f %s/.squashfs.sqfs /.squashfs.sqfs' % ( self.mountpoint ) )
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

MEH: No encryption. No duress password. Changes are permanent. Guest Mode is still the default.

''' )
            res = 999
            while res != 'T' and res != 'P' and res != 'M':
                res = input( "(T)emporary, (P)ermanent, or (M)eh ? " ).strip( '\r\n\r\n\r' ).replace( 't', 'T' ).replace( 'p', 'P' ).replace( 'm', 'M' )
            if res == 'T':
                write_oneliner_file( '%s/.temp_or_perm.txt' % ( self.mountpoint ), 'temp' )
            elif res == 'P':
                write_oneliner_file( '%s/.temp_or_perm.txt' % ( self.mountpoint ), 'perm' )
            else:
                write_oneliner_file( '%s/.temp_or_perm.txt' % ( self.mountpoint ), 'meh' )
        if res == 'T':
            self.squash_OS()
        if res == 'P' or res == 'M':
            if running_on_a_test_rig():
                self.status_lst.append( ['I would like to regenerate the squashfs file, but that code has been disabled temporarily for test porpoises.'] )
#                self.status_lst.append( ['Because this is a test rig, I am regenerating the squashfs file.'] )
#                self.generate_squashfs_of_my_OS()
#                self.status_lst[-1] += ' ...regenerated.'
            self.set_root_password()
            system_or_die( 'rm -f /.squashfs.sqfs %s/.squashfs.sqfs' % ( self.mountpoint ) )
            if res == 'P':
                self.migrate_OS()
            else:
                chrubix.save_distro_record( distro_rec = self, mountpoint = self.mountpoint )
                self.redo_mbr_for_plain_root( self.mountpoint )

    def squash_OS( self ):
        self.lxdm_settings['use greeter gui'] = True
        chrubix.save_distro_record( distro_rec = self, mountpoint = self.mountpoint )
#        self.generate_squashfs_of_my_OS()
#        system_or_die( 'mkdir -p /tmp/ro /tmp/squashfs_dir' )
#        system_or_die( 'mount -o loop,squashfs %s/.squashfs.sqfs /tmp/squashfs_dir' % ( self.mountpoint ) )  # /tmp/ro
#        system_or_die( 'mount -t unionfs -o dirs=/tmp/ro=rw unionfs /tmp/squashfs_dir' )
        self.redo_mbr_for_plain_root( self.mountpoint )  # '/tmp/squashfs_dir' )
#        system_or_die( 'umount /tmp/squashfs_dir' )
#        system_or_die( 'umount /tmp/ro' )
        self.generate_squashfs_of_my_OS()
        system_or_die( 'rm -Rf %s/bin %s/boot %s/etc %s/home %s/lib %s/mnt %s/opt %s/root %s/run %s/sbin %s/srv %s/usr %s/var' %
                      ( self.mountpoint, self.mountpoint, self.mountpoint, self.mountpoint, self.mountpoint, self.mountpoint,
                       self.mountpoint, self.mountpoint, self.mountpoint, self.mountpoint, self.mountpoint, self.mountpoint,
                       self.mountpoint ) )

    def migrate_OS( self ):  # ....unless you're the Alarmist subclass, which redefines this as SQUASH MY OS!  :-)
        self.kernel_rebuild_required = True  # ...because the initramfs needs our boom pw, which means we'll have to rebuild initramfs.... which means rebuilding kernel!
        system_or_die( 'cd /' )
        new_mtpt = '/tmp/_enc_root'
        os.system( 'mkdir -p %s' % ( new_mtpt ) )  # errtxt = 'Failed to create new mountpoint %s ' % ( new_mtpt ) )
        self.migrate_all_data( new_mtpt )  # also mounts new_mtpt and rejigs kernel
        mount_sys_tmp_proc_n_dev( new_mtpt )
#        os.system( 'mkdir -p %s/dev' % ( new_mtpt ) )
#        os.system( 'mkdir -p %s/proc' % ( new_mtpt ) )
#        os.system( 'mkdir -p %s/tmp' % ( new_mtpt ) )
#        os.system( 'mkdir -p %s/sys' % ( new_mtpt ) )
#        for ( my_type, my_dir ) in ( ( 'devtmpfs', 'dev' ),
#                                ( 'proc', 'proc' ),
#                                ( 'sysfs', 'sys' ),
#                                ( 'tmpfs', 'tmp' ) ):
#            assert( os.path.exists( '%s/%s' % ( new_mtpt, my_dir ) ) )
#            chroot_this( new_mtpt, 'mount %s %s/%s -t %s' % ( my_type, new_mtpt, my_dir, my_type ), attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
        self.redo_mbr_for_encrypted_root( new_mtpt )
        chrubix.save_distro_record( distro_rec = self, mountpoint = new_mtpt )  # save distro record to new disk (not old mountpoint)
        try:
            unmount_sys_tmp_proc_n_dev( new_mtpt )
            os.system( 'umount %s/%s' % ( self.mountpoint, new_mtpt ) )
            unmount_sys_tmp_proc_n_dev( self.mountpoint )
        except ( SystemError, SyntaxError ):
            pass

    def unmount_and_clean_up( self ):
        self.status_lst[-1] += '...Bonzer.'
        unmount_sys_tmp_proc_n_dev( self.mountpoint )
        logme( 'leaving phase 6 of 6. FYI, total number of lines = %d' % ( chrubix.utils.get_total_lines_so_far() ) )
        chrubix.utils.set_total_lines_so_far( chrubix.utils.get_expected_duration_of_install() )

    def build_and_install_software_from_archlinux_git( self, package_name, yes_download = True, yes_build = True, yes_install = True, quiet = False ):
    #    pkgbuild_url_template = 'https://projects.archlinux.org/svntogit/packages.git/plain/trunk/%s?h=packages/%s'
        what_im_doing = ''
        what_im_doing += 'Downloading/' if yes_download else ''
        what_im_doing += 'Building/'    if yes_build    else ''
        what_im_doing += 'Installing/'  if yes_install  else ''
        if what_im_doing != '':
            what_im_doing = what_im_doing[:-1]
        if self.status_lst is not None and not quiet:
            self.status_lst.append( ["%s ArchLinux's %s, from git, into your OS" % ( what_im_doing, package_name )] )
        for mytool in ( 'patch', 'git' ):
            if os.system( 'which %s &>/dev/null' % ( mytool ) ) != 0:
                system_or_die( 'yes "" 2> /dev/null | pacman -S %s' % ( mytool ), title_str = self.title_str, status_lst = self.status_lst )
        if not os.path.isdir( '%s/%s' % ( self.mountpoint, self.kernel_src_basedir ) ):
            chroot_this( self.mountpoint, 'cd %s && git clone git://github.com/archlinuxarm/PKGBUILDs.git' % ( self.ryo_tempdir ), \
                             on_fail = "Failed to git clone kernel source", title_str = self.title_str, status_lst = self.status_lst )
#            failed( "Seriously, by this point, we should have the whole git repo in %s, either from the precompiled tarball or from our locally built code in %s" % ( self.kernel_src_basedir, self.sources_basedir ) )
#            self.download_kernel_source()     # NO!!! This would create recursion. No, no, no.
#            system_or_die( 'cd %s/%s && tar -cz * > ../temp.tgz 2> /dev/null && rm -Rf *' % ( self.mountpoint , self.ryo_tempdir ) )
#            system_or_die( 'rm -Rf %s/%s' % ( self.mountpoint, self.ryo_tempdir ) )
#            system_or_die( 'mkdir -p %s/%s' % ( self.mountpoint, self.ryo_tempdir ) )
#            system_or_die( 'cd %s/%s && git clone git://github.com/archlinuxarm/PKGBUILDs.git' % ( self.mountpoint, self.ryo_tempdir ),
#                                                        title_str = self.title_str, status_lst = self.status_lst,
#                                                        errtxt = "Unable to use git to download all PKGBUILDs" )
#            system_or_die( 'cd %s/%s && tar -zxf ../temp.tgz 2> /dev/null' % ( self.mountpoint , self.ryo_tempdir ) )
    #    system_or_die( 'rm -Rf %s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
    #    system_or_die( 'mkdir -p %s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        tmpfile = generate_temporary_filename( '/tmp' )
        cmd = 'find %s/%s -name PKGBUILD -type f | fgrep /%s/ | head -n1 > %s' % ( self.mountpoint, os.path.dirname( self.sources_basedir ), package_name, tmpfile )
    #    self.status_lst.append( ['cmd = %s' % ( cmd )] )
    #    print( 'cmd=%s' % ( cmd ) )
        res = os.system( cmd )
    #    from chrubix.utils import logme
    #    logme( 'cmd = %s' % ( cmd ) )
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
                system_or_die( r'cd %s/%s/%s && makepkg --skipchecksums --asroot --nobuild' % ( self.mountpoint, self.sources_basedir, package_name ), \
                                                errtxt = 'Failed to download %s into Alarpy' % ( package_name ), \
                                                title_str = self.title_str, status_lst = self.status_lst )
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
            self.status_lst[-1] += '...Easy.'

    def build_and_install_package_into_alarpy_from_source( self, pkg_name, quiet = False ):
        logme( 'DebianDistro - build_and_install_package_into_alarpy_from_source() - starting' )
        if not quiet:
            self.status_lst[-1] += 'Installing %s from source' % ( pkg_name )
        system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
        if 0 != wget( url = 'https://aur.archlinux.org/packages/%s/%s/%s.tar.gz'
                                    % ( pkg_name[:2], pkg_name, pkg_name ),
                                    extract_to_path = self.sources_basedir, decompression_flag = 'z',
                                    title_str = self.title_str,
                                    status_lst = self.status_lst ):
            failed( "Failed to download tarball of %s source code" % ( pkg_name ) )
        self.status_lst[-1] += '.'
        system_or_die( 'cd %s/%s && makepkg --skipchecksums --asroot -f'
                                % ( self.sources_basedir, pkg_name ),
                                title_str = self.title_str,
                                status_lst = self.status_lst )
        self.status_lst[-1] += '.'
        system_or_die( 'yes "" | pacman -U `ls %s/%s/%s*pkg.tar.xz`'
                                % ( self.sources_basedir, pkg_name, pkg_name ),
                                title_str = self.title_str,
                                status_lst = self.status_lst )
        self.status_lst[-1] += 'Yep.'

    def build_and_install_software_from_archlinux_source( self, package_name, only_download = False, quiet = False ):
    #    pkgbuild_url_template = 'https://projects.archlinux.org/svntogit/packages.git/plain/trunk/%s?h=packages/%s'
        if not quiet and self.status_lst is not None:
            self.status_lst.append( ["%s ArchLinux's %s, from source, into your OS" % ( 'Downloading' if only_download else 'Installing' , package_name )] )
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
        system_or_die( 'cd %s/%s/%s && makepkg --skipchecksums --asroot --nobuild' % ( self.mountpoint, self.sources_basedir, package_name ),
                                        errtxt = 'Failed to download %s into new distro' % ( package_name ) ,
                                        title_str = self.title_str, status_lst = self.status_lst )
        if not only_download:
            if package_name == 'ssss':
                do_a_sed( '%s/%s/%s/PKGBUILD' % ( self.mountpoint, self.sources_basedir, package_name ),
                          'url=.*',
                          'url="http://ftp.riken.jp/Linux/ubuntu/pool/universe/s/ssss/ssss_0.5.orig.tar.gz"' )
            if self.name == 'archlinux':
                # i2p comes w/ broken hyperlinks (/tmp/_root/... instead of ../...). Fix 'em.
                if package_name in ( 'i2p', 'freenet', 'gtk-theme-adwaita-x', 'java-service-wrapper' ):
                    fix_broken_hyperlinks( '%s%s/%s/src' % ( self.mountpoint, self.sources_basedir, package_name ) )
                chroot_this( self.mountpoint, 'cd %s/%s && makepkg --skipchecksums --asroot %s && yes "" | pacman -U %s*pkg.tar.xz' %
                                        ( self.sources_basedir, package_name, '-f' if package_name == 'java-service-wrapper' else '--noextract', package_name ),
                                        on_fail = 'Failed to build&install %s within new %s distro' % ( package_name, self.name ) ,
                                        title_str = self.title_str, status_lst = self.status_lst )
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
            self.status_lst[-1] += '...OK.'

    def do_generic_locale_configuring( self ):
        write_oneliner_file( '%s/etc/locale.conf' % ( self.mountpoint ), '''LANG="en_US.UTF-8"
''' )
        write_oneliner_file( '%s/etc/locale.gen' % ( self.mountpoint ), '''en_US.UTF-8 UTF-8
''' )
        write_oneliner_file( '%s/etc/vconsole.conf' % ( self.mountpoint ), '''KEYMAP="us"
''' )
        chroot_this( self.mountpoint, 'locale-gen' , title_str = self.title_str, status_lst = self.status_lst,
                     on_fail = 'Failed to run locale-gen to initialize the new locale' )

    def install_chrubix( self ):
        if not os.path.exists( '%s%s' % ( self.mountpoint, self.kernel_src_basedir ) ):
            failed( 'Where is the linux-chromebook folder in the bootstrap OS? I am scared. Hold me.' )
        self.status_lst.append( ['Installing Chrubix in bootstrapped OS'] )
        # Save the old-but-grooby chrubix.sh; it was modified (its vars resolved) by chrubix_stage1.sh
        groovy_chrubix_sh_file = generate_temporary_filename( '/tmp' )
        # Delete old copy of Chrubix from mountpoint.
        system_or_die( 'rm -Rf %s/usr/local/bin/Chrubix*' % ( self.mountpoint ) )
        # Download and install latest copy from the GitHub website.
        if 0 != wget( url = 'https://github.com/ReubenAbrams/Chrubix/archive/master.tar.gz',
                                extract_to_path = '%s/usr/local/bin' % ( self.mountpoint ), decompression_flag = 'z',
                                quiet = True, status_lst = self.status_lst, title_str = self.title_str ):
            failed( 'Failed to install Chrubix in bootstrap OS' )
        system_or_die( 'mv %s/usr/local/bin/Chrubix* %s/usr/local/bin/Chrubix' % ( self.mountpoint, self.mountpoint ) )
        # Try to install latest-latest version (on top of GitHub version) from Dropbox.
        try:
            wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/_chrubix.tar.xz',
                  decompression_flag = 'J', extract_to_path = '%s/usr/local/bin/Chrubix' % ( self.mountpoint ), quiet = True )
        except SystemError:
            self.status_lst.append( ['Failed to install new version via wget. That sucks. Let us continue anyway...'] )
        system_or_die( 'cp /usr/local/bin/Chrubix/bash/chrubix.sh %s/usr/local/bin/Chrubix/bash/chrubix.sh' % ( self.mountpoint ) )
        system_or_die( 'ln -sf Chrubix/bash/chrubix.sh %s/usr/local/bin/chrubix.sh' % ( self.mountpoint ) )
        assert( os.path.islink( '%s/usr/local/bin/chrubix.sh' % ( self.mountpoint ) ) )
        system_or_die( 'chmod +x %s/usr/local/bin/Chrubix/bash/*' % ( self.mountpoint ) )
        for f in ( 'chrubix.sh', 'CHRUBIX', 'greeter.sh', 'preboot_configurer.sh', 'modify_sources.sh', 'redo_mbr.sh' ):
            system_or_die( 'ln -sf Chrubix/bash/%s %s/usr/local/bin/%s' % ( f, self.mountpoint, f ) )
            system_or_die( 'chmod +x %s/usr/local/bin/Chrubix/bash/%s' % ( self.mountpoint, f ) )
        mytitle = ( self.name + ( '' if self.branch is None else ' ' + self.branch ) ).title()
        do_a_sed( '%s/usr/local/bin/Chrubix/src/ui/AlarmistGreeter.ui' % ( self.mountpoint ), 'W E L C O M E', 'Welcome to %s' % ( mytitle ) )
        os.system( 'rm -f %s/usr/local/bin/redo_mbr' % ( self.mountpoint ) )
        system_or_die( 'chmod +x %s/usr/local/bin/*' % ( self.mountpoint ) )
#        chroot_this( self.mountpoint, 'chmod +x /usr/local/bin/*' )
#        system_or_die( 'cp -af /tmp %s/usr/local/bin/Chrubix/bash/chrubix.sh' % ( self.mountpoint ) )
        for f in 'blobs/apps/freenet.tar.xz src/chrubix/distros/alarmist.py blobs/settings/x_alarm_chrubuntu.zip bash/chrubix.sh bash/greeter.sh bash/modify_sources.sh bash/redo_mbr.sh src/main.py src/greeter.py src/tinker.py'.split( ' ' ):
            g = '%s/usr/local/bin/Chrubix/%s' % ( self.mountpoint, f )
            if os.path.exists( g ):
                logme( '%s exists' % ( g ) )
            else:
                failed( '%s does not exist' % ( g ) )
        if os.path.exists( '%s/usr/bin/python3' % ( self.mountpoint ) ) and not os.path.exists( '%s/usr/local/bin/python3' % ( self.mountpoint ) ):
            system_or_die( 'ln -sf ../../bin/python3 %s/usr/local/bin/python3' % ( self.mountpoint ) )
            if os.path.exists( '%s/usr/bin/python3' % ( self.mountpoint ) ) and not os.path.exists( '%s/usr/local/bin/python3' % ( self.mountpoint ) ):
                failed( 'Well, that escalated rather quickly.' )
        self.status_lst[-1] += '...installed.'

    def check_sanity_of_distro( self ):
        flaws = 0
        self.status_lst.append( ['Checking sanity of distro'] )
        system_or_die( 'chmod +x %s/usr/local/*' % ( self.mountpoint ) )  # Shouldn't be necessary... but it is. For some reason, greeter.sh and CHRUBIX aren't executable. Grr.
        for executable_to_find in ( 
                                    'startlxde', 'lxdm', 'wifi_auto.sh', 'wifi_manual.sh', \
                                    'chrubix.sh', 'mkinitcpio', 'dtc', 'wmsystemtray', 'florence', \
                                    'pidgin', 'gpgApplet', 'macchanger', 'gpg', 'chrubix.sh', 'greeter.sh', \
                                    'run_browser_as_guest.sh', 'dropbox_uploader.sh', 'power_button_pushed.sh', \
                                    'sayit.sh', 'vidalia', 'i2prouter', 'claws-mail', \
                                    'CHRUBIX', 'libreoffice', 'ssss-combine', 'ssss-split', 'dillo'
                                  ):
            self.status_lst[-1] += '.'
            if chroot_this( self.mountpoint, 'which %s' % ( executable_to_find ), title_str = self.title_str, status_lst = self.status_lst, pauses_len = .5 ):
                self.status_lst.append( ['%s is missing from final distro' % ( executable_to_find )] )
                flaws += 1
        if flaws > 0:
            self.status_lst.append( ['%d flaw%s found; please rectify' % ( flaws, '' if flaws == 1 else 's' )] )
        else:
            self.status_lst[-1] += 'distro is not insane. (How nice)'
        logme( "This sanity-checker is incomplete. Please improve it." )

    def generate_squashfs_of_my_OS( self ):
        logme( 'qqq generate_squashfs_of_my_OS() --- hi' )
        assert( os.path.isdir( '%s/usr/local/bin/Chrubix' % ( self.mountpoint ) ) )

        system_or_die( 'mkdir -p /tmp/posterity' )  # FIXME: remove? If I remove this, does everything (M, T, P) still work?
        system_or_die( 'rm -f %s/.squashfs.sqfs /.squashfs.sqfs' % ( self.mountpoint ) )
        if running_on_a_test_rig() or ( True is True ):
            logme( 'I am running on a test rig. Is there a backup of sqfs available?' )
            system_or_die( 'mkdir -p /tmp/posterity' )
            if 0 == os.system( 'mount /dev/sda4 /tmp/posterity &> /dev/null' ) \
            or 0 == os.system( 'mount /dev/sdb4 /tmp/posterity &> /dev/null' ) \
            or 0 == os.system( 'mount | grep /tmp/posterity &> /dev/null' ):
                logme( 'Perhaps.' )
                if os.path.exists( '/tmp/posterity/%s.sqfs' % ( self.name + ( '' if self.branch is None else self.branch ) ) ):
                    self.status_lst.append( ['Restoring squashfs from backup'] )
                    system_or_die( 'cp -f /tmp/posterity/%s.sqfs /.squashfs.sqfs' % ( self.name + ( '' if self.branch is None else self.branch ) ) )
                    self.status_lst[-1] += '...restored.'
                    logme( 'Yes.' )
                else:
                    logme( 'No.' )
        if not os.path.exists( '%s/.squashfs.sqfs' % ( self.mountpoint ) ):
            self.status_lst.append( ['Generating squashfs of this OS'] )
            system_or_die( 'mkdir -p %s/_to_add_to_squashfs/{dev,proc,sys,tmp}' % ( self.mountpoint ) )
            chroot_this( self.mountpoint, \
'mksquashfs /bin /boot /etc /home /lib /mnt /opt /root /run /sbin /usr /srv /var /_to_add_to_squashfs/* /.squashfs.sqfs',  # -comp xz',
                                                         status_lst = self.status_lst, title_str = self.title_str,
                                                         attempts = 1, on_fail = 'Failed to generate squashfs' )
            self.status_lst[-1] += '...generated.'
        logme( 'qqq delta' )
        system_or_die( 'mkdir -p /tmp/posterity' )
        if running_on_a_test_rig():
            if 0 == os.system( 'mount /dev/sda4 /tmp/posterity &> /dev/null' ) \
            or 0 == os.system( 'mount /dev/sdb4 /tmp/posterity &> /dev/null' ) \
            or 0 == os.system( 'mount | grep /tmp/posterity &> /dev/null' ):
                self.status_lst.append( 'Backing up the squashed fs' )
                logme( 'qqq backing up squashs' )
                system_or_die( 'cp -f %s/.squashfs.sqfs /tmp/posterity/%s.sqfs' % ( self.mountpoint, self.name + ( '' if self.branch is None else self.branch ) ) )
                os.system( 'sync;sync;sync' )
                self.status_lst[-1] += '...backed up.'
                system_or_die( 'umount /tmp/posterity &> /dev/null' )
        assert( os.path.exists( '%s/.squashfs.sqfs' % ( self.mountpoint ) ) )

    def download_kernel_source( self ):  # This also downloads all the other PKGBUILDs (for btrfs-progs, jfsutils, etc.)
        # TODO: Consider using ArchlinuxDistro.download_package_source()
        for attempt in range( 3 ):
            try:
                system_or_die( 'cd %s && rm -Rf PKGBUILDs && git clone git://github.com/archlinuxarm/PKGBUILDs.git' % ( self.mountpoint + self.ryo_tempdir ), \
                                                        title_str = self.title_str, status_lst = self.status_lst )
                system_or_die( 'cd %s && makepkg --skipchecksums --asroot --nobuild -f' % ( self.mountpoint + self.kernel_src_basedir ),
                                                        title_str = self.title_str, status_lst = self.status_lst )
                return 0
            except RuntimeError:
                self.status_lst[-1] += ' git or makepkg failed. Retrying...'
        failed( 'Failed to download kernel source' )
#        self.download_package_source( os.path.basename( self.kernel_src_basedir ), ( 'PKGBUILD', ) )

#    def download_kernel_source( self ):
#        self.build_and_install_software_from_archlinux_git( package_name = os.path.basename( self.kernel_src_basedir ),
#                                                       yes_download = True, yes_build = False, yes_install = False )
# # git clone --depth 1 http://chromium.googlesource.com/chromiumos/third_party/kernel.git \
# # -b chromeos-3.4 ${basedir}/kernel # NO NEED. It gives us nothing that PKGBUILD(s) doesn't give us.

    def configure_winxp_camo_and_guest_default_files( self ):
        install_windows_xp_theme_stuff( self.mountpoint )
#        if os.path.exists( '%s/usr/share/icons/GnomeXP' % ( self.mountpoint ) ):
#            raise RuntimeError( 'I have already installed the groovy XP stuff, FYI.' )
        system_or_die( 'rm -f %s/etc/lxdm/PreLogin' % ( self.mountpoint ) )
        append_lxdm_pre_login_script( '%s/etc/lxdm/PreLogin' % ( self.mountpoint ) )
        install_mp3_files( self.mountpoint )
        assert( os.path.exists( '%s/etc/.mp3/winxp.mp3' % ( self.mountpoint ) ) )

    def install_leap_bitmask( self ):
        logme( 'Installing leap bitmask' )
        self.status_lst.append( 'Installing leap bitmask' )
        f = open( '%s/tmp/install_leap_bitmask.sh' % ( self.mountpoint ), 'w' )
        f.write( '''#!/bin/bash
failed() {
    echo "$1" >> /dev/stderr
    exit 1
}

#export http_proxy=
#export ftp_proxy=

which pip2 || ln -sf pip-2.7 /usr/bin/pip2
pip2 install keyring pyOpenSSL pysqlcipher    || failed "Failed to install keyring/pyopenssl/pysqlcipher"
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
pip2 install --no-dependencies leap.bitmask || failed "Failed to install leap.bitmask"
exit 0
''' % ( self.sources_basedir ) )
        f.close()
        os.system( 'chmod +x %s/tmp/install_leap_bitmask.sh' % ( self.mountpoint ) )
        if 0 != chroot_this( self.mountpoint, 'bash /tmp/install_leap_bitmask.sh',
                                        status_lst = self.status_lst, title_str = self.title_str,
                                        attempts = 3 ):
            self.status_lst[-1] += '...shucks. Failed to install leap.bitmask :-('
        else:
            self.status_lst[-1] += '...yay! Succeeded :-)'

    def install_freenet( self ):
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
        write_oneliner_file( '%s/.install_freenet_like_this.sh' % ( self.mountpoint ), '''#!/bin/sh
rm -Rf /opt/freenet/.[a-z]*
rm -Rf /opt/freenet/*
echo -en "/opt/freenet\n1\n1\n1\n" | java -jar /.new_installer_offline.jar -console
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
        wget( url = 'https://freenetproject.org/jnlp/freenet_installer.jar', save_as_file = '%s/.new_installer_offline.jar' % ( self.mountpoint ),
                                                        status_lst = self.status_lst, title_str = self.title_str )
        chroot_this( self.mountpoint, 'su -l freenet /.install_freenet_like_this.sh', attempts = 1,
                          status_lst = self.status_lst, title_str = self.title_str )
        system_or_die( 'rm -f %s/.new_installer_offline.jar' % ( self.mountpoint ) )
        system_or_die( 'rm -f %s/.install_freenet_like_this.sh' % ( self.mountpoint ) )
        if os.path.exists( '%s/opt/freenet/bin/wrapper' % ( self.mountpoint ) ) and os.path.exists( '%s/opt/freenet/run.sh' % ( self.mountpoint ) ):
            system_or_die( 'ln -sf wrapper-linux-armhf-32 %s/opt/freenet/bin/wrapper' % ( self.mountpoint ) )
        else:
            logme( 'OK. Traditional install of freenet failed. I shall do it from tarball instead.' )
            chroot_this( self.mountpoint, 'tar -Jxf /usr/local/bin/Chrubix/blobs/apps/freenet.tar.xz -C /' )

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
        if not running_on_a_test_rig():
            logme( 'I am not running on a test rig. Therefore, I shall not save %s' % ( tailend ) )
            return 0
        else:
            res = self.load_or_save_posterity_file( tailend, self.generate_tarball_of_my_rootfs )
            if 0 != res:
                self.status_lst.append( ['Unable to save %s progress for posterity' % ( tailend )] )
                logme( 'Failed to save for posterity' )
            else:
                logme( 'Saved for posterity. Yay.' )
            return res

    def load_or_save_posterity_file( self, tailend, func_to_call ):
        logme( 'load_or_save_posterity_file() --- entering' )
        system_or_die( 'mkdir -p /tmp/posterity' )
        if os.system( 'mount /dev/sda4 /tmp/posterity &> /dev/null' ) == 0 \
        or os.system( 'mount /dev/sdb4 /tmp/posterity &> /dev/null' ) == 0 \
        or os.system( 'mount | grep /tmp/posterity &> /dev/null' ) == 0:
            fname = '/tmp/posterity/%s%s_%s.xz' % ( self.name, '' if self.branch is None else self.branch, tailend )
            res = func_to_call( fname )
            system_or_die( 'sync;sync;sync;umount /tmp/posterity' )
            logme( 'load_or_save_posterity_file() --- leaving' )
            return res
        else:
            logme( 'qqq Failed to backup/restore' )
            logme( 'load_or_save_posterity_file() --- leaving' )
            return 0

    def nop( self ):
        pass

    def able_to_restore_from_posterity( self, tailend ):
        if not running_on_a_test_rig():
            logme( 'I am not running on a test rig. Therefore, I shall not restore %s' % ( tailend ) )
            return 0
        else:
            res = self.load_or_save_posterity_file( tailend, self.write_my_rootfs_from_tarball )
            if 0 == res:
                system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
                system_or_die( 'mkdir -p %s/{dev,sys,proc,tmp}' % ( self.mountpoint, ), "Can't make important dirs" )
                system_or_die( 'mkdir -p %s/usr/local/bin' % ( self.mountpoint, ) )
                mount_sys_tmp_proc_n_dev( self.mountpoint )
                self.status_lst.append( ['Successfully restored %s progress from posterity' % ( tailend )] )
                self.update_and_upgrade_all()
            return res

    def install_mkinitcpio_ramwipe_hooks( self ):  # See https://bbs.archlinux.org/viewtopic.php?id=136283
        install_initcpio_wiperamonshutdown_files( self.mountpoint )

    def forcibly_rebuild_initramfs_and_vmlinux( self ):
        self.status_lst.append( ['Forcibly rebuilding kernel and vmlinux'] )
        self.kernel_rebuild_required = True
        self.redo_mbr( root_partition_device = self.root_dev, chroot_here = self.mountpoint )
        self.status_lst[-1] += '...rebuilt.'

    def quit( self ):
        failed( 'NEFARIOUS PORPOISES' )

    def install( self ):
        '''
        At this point, I am chroot()'d to self.root_dev, my /proc, /sys, /tmp, and /dev are mounted,
        and I am ready to install my OS at either self.spare_dev (which I may reformat/assign to crypto
        if I like) or self.root_dev (no formatting allowed, because I 'live' there in .bootstrap).
        Kernel will go in self.kernel_dev of course.
        '''
        logme( 'install() - starting' )
        self.mountpoint = '/tmp/_root'
        system_or_die( 'mkdir -p ' + self.mountpoint, 'Failed to create self.mountpoint ' + self.mountpoint )
        mount_device( self.root_dev, self.mountpoint )
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
                                self.save_for_posterity_if_possible_B )
        third_stage = ( 
                                self.install_urwid_and_dropbox_uploader,
                                self.install_vbutils_from_cbook,
                                self.install_mkinitcpio_ramwipe_hooks,
                                self.install_timezone,
                                self.download_modify_and_build_kernel_and_mkfs,
                                self.save_for_posterity_if_possible_C )  # self.nop
        fourth_stage = ( 
                                self.install_chrubix,
                                self.install_leap_bitmask,
                                self.install_gpg_applet,
                                self.install_panic_button,
                                self.install_freenet,
                                self.install_final_push_of_packages,  # Chrubix, wmsystemtray, boom scripts, GUI, networking, ...
                                # From this point on, assume Internet access is gone.
                                self.configure_dbus_sudo_and_groups,
                                self.configure_lxdm_login_manager,
                                self.configure_privacy_tools,
                                self.configure_chrome_or_iceweasel,
                                self.configure_networking,
                                self.configure_speech_synthesis_and_font_cache,
                                self.configure_winxp_camo_and_guest_default_files,
                                self.configure_xwindow_for_chromebook,
                                self.configure_distrospecific_tweaks,
                                self.remove_all_junk,
                                self.forcibly_rebuild_initramfs_and_vmlinux,
                                self.check_sanity_of_distro,
                                self.save_for_posterity_if_possible_D )
        fifth_stage = ( 
#                                self.forcibly_rebuild_initramfs_and_vmlinux,
                                self.install_vbutils_from_cbook,  # just in case the new user's tools differ from the original builder's tools
                                self.migrate_or_squash_OS,  # Every class but Alarmist will use migrate_or_squash. Alarmist uses squash.
                                self.unmount_and_clean_up
                                )
        all_my_funcs = first_stage + second_stage + third_stage + fourth_stage + fifth_stage
        if os.path.exists( '%s/.checkpoint.txt' % ( self.mountpoint ) ):
            checkpoint_number = int( read_oneliner_file( '%s/.checkpoint.txt' % ( self.mountpoint ) ) )
            if checkpoint_number == 9999:
                url_or_fname = read_oneliner_file( '%s/.url_or_fname.txt' % ( self.mountpoint ) )
                self.status_lst.append( ['I was restored by the stage 1 bash script from %s; cool.' % ( url_or_fname )] )
                mount_sys_tmp_proc_n_dev( self.mountpoint )  # FIXME: This line is unnecessary, probably
                if url_or_fname.find( '_D' ) >= 0:
                    checkpoint_number = len( first_stage ) + len( second_stage ) + len( third_stage ) + len( fourth_stage )
                elif url_or_fname.find( '_C' ) >= 0:
                    checkpoint_number = len( first_stage ) + len( second_stage ) + len( third_stage )
                elif url_or_fname.find( '_B' ) >= 0:
                    checkpoint_number = len( first_stage ) + len( second_stage )
                elif url_or_fname.find( '_A' ) >= 0:
                    checkpoint_number = len( first_stage )
                else:
                    failed( 'Incomprehensible posterity restore - %s' % ( url_or_fname ) )
            else:
                self.status_lst.append( ['Cool -- resuming from checkpoint#%d' % ( checkpoint_number )] )
        else:
            checkpoint_number = 0
        logme( 'Starting at checkpoint#%d' % ( checkpoint_number ) )
        for myfunc in all_my_funcs[checkpoint_number:]:
            logme( 'Running %s' % ( myfunc.__name__ ) )
            myfunc()
            checkpoint_number += 1
            write_oneliner_file( '%s/.checkpoint.txt' % ( self.mountpoint ), str( checkpoint_number ) )
#             if chrubix.utils.get_expected_duration_of_install() / chrubix.utils.get_total_lines_so_far() < 1.1:
#                 chrubix.utils.set_expected_duration_of_install( chrubix.utils.get_total_lines_so_far() * 1.1 )
#                 logme( 'Adjusting the numbers. Expected duration is now %d' % ( chrubix.utils.get_expected_duration_of_install() ) )
#                 self.status_lst.append( ['Amending total expected lines; now, it is %d' % ( chrubix.utils.get_expected_duration_of_install() )] )

