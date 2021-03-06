#!/usr/local/bin/python3
#
# tinker.py
# Test subroutine of the CHRUBIX project
# ...for me to tinker with things :)


import sys
import os
from chrubix import generate_distro_record_from_name, load_distro_record
from chrubix.utils import fix_broken_hyperlinks, system_or_die, call_makepkg_or_die, remaining_megabytes_free_on_device, \
                          chroot_this, patch_org_freedesktop_networkmanager_conf_file, failed, migrate_to_obfuscated_filesystem
from chrubix.distros.debian import generate_mickeymouse_lxdm_patch
from chrubix.utils.postinst import remove_junk, \
                                    GUEST_HOMEDIR


MYDISK_MTPT = '/.mydisk'

try:
    import urwid
except ImportError:
    os.system( 'easy_install urwid' )
    import urwid

testval = urwid  # stop silly warning in Eclipse
argv = sys.argv
res = 0
if argv[1] != 'tinker':
    raise RuntimeError( 'first param must be tinker' )
good_list = []
bad_list = []  # ubuntu failed to build afio

if argv[2] == 'secretsquirrel':
    if 0 == os.system( 'mount | fgrep "cryptroot on /"' ):
        failed( 'No! You are already in Secret Squirrel Mode.' )
    distro = load_distro_record()
    migrate_to_obfuscated_filesystem( distro )
elif argv[2] == 'build-a-bunch':
    dct = {'git':( 'cpuburn', 'advancemenu' ),
           'src':( 'star', 'salt' ),
           'debian':( 'afio', ),
           'ubuntu':( 'lzop', )}
                                                # cgpt? lxdm? chromium?
    distro = generate_distro_record_from_name( 'debianwheezy' )
    distro.mountpoint = MYDISK_MTPT if os.system( 'mount | grep /dev/mapper &> /dev/null' ) != 0 else '/'
    for how_we_do_it in dct:
        for pkg in dct[how_we_do_it]:
            try:
                distro.install_expatriate_software_into_a_debianish_OS( 
                                                            package_name = pkg,
                                                            method = how_we_do_it )
                good_list.append( pkg )
            except ( IOError, SyntaxError, RuntimeError ):
                bad_list.append( pkg )
    print( "good:", good_list )
    print( "bad :", bad_list )
elif argv[2] == 'logmein':
    distro = load_distro_record( '/' if os.system( 'cat /proc/cmdline 2>/dev/null | fgrep root=/dev/dm-0 > /dev/null' ) != 0 else MYDISK_MTPT )
    for cmd in ( 
                'mkdir -p /tmp/.sda2',
                'mount /dev/sda2 /tmp/.sda2',
                '/usr/local/bin/redo_mbr.sh > /tmp/.sda2/log_me_in.sh'
                ):
        system_or_die( cmd )
    os.system( 'sync;sync;sync;sync' )
    system_or_die( 'umount /tmp/.sda2' )
elif argv[2] == 'build-from-debian':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    pkg = argv[4]
    distro.build_and_install_package_from_debian_source( pkg, 'jessie' )
elif argv[2] == 'build-from-jessie-for-stretch':
    distro = generate_distro_record_from_name( 'debianstretch' )
    distro.mountpoint = '/'
    distro.build_and_install_package_from_debian_source( argv[3], 'jessie' )
#    sys.exit( 0 )
    print( "Building %s from Deb-ish => %s" % ( pkg, argv[3] ) )
    distro.build_and_install_package_from_debian_source( pkg, 'wheezy' if argv[3] == 'debianwheezy' else 'jessie' )
elif argv[2] == 'build-from-ubuntu':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    pkg = argv[4]
#    sys.exit( 0 )
    print( "Building %s from Ubu-ish => Wheezy" % ( pkg ) )
    distro.build_and_install_package_from_ubuntu_source( pkg )
elif argv[2] == 'build-from-src':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    pkg = argv[4]
    distro.build_and_install_software_from_archlinux_source( pkg )
elif argv[2] == 'fix-hyperlinks':
    fix_broken_hyperlinks( argv[3] )
elif argv[2] == 'build-from-git':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    pkg = argv[4]
    sources_basedir = '/root/.rmo/PKGBUILDs/core'
    mountpoint = MYDISK_MTPT
    distro.build_and_install_software_from_archlinux_git( pkg )
elif argv[2] == 'fire-everything':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    pkg = argv[4]
    distro.install_expatriate_software_into_a_debianish_OS( package_name = pkg, method = None )
elif argv[2] == 'remove-junk':
    remove_junk( MYDISK_MTPT, '/root/.rmo/PKGBUILDs/core/linux-chromebook' )
elif argv[2] == 'modify-sources':
    system_or_die( 'bash /usr/local/bin/modify_sources.sh /dev/mmcblk1 /.mydisk no yes' )
elif argv[2] == 'postinst':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/'
    distro.install_tweaks_for_lxdm_chrome_iceweasel_and_distrospecific_stuff()
elif argv[2] == 'initramfs':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.redo_kernel( argv[4], distro.root_dev, distro.mountpoint )
elif argv[2] == 'redo-kernel':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.modify_build_and_install_mkfs_and_kernel_for_OS( apply_kali_patch = False )
elif argv[2] == 'tails':
    distro = generate_distro_record_from_name( 'debiantails' )
    distro.mountpoint = '/' if os.system( 'cat /proc/cmdline 2>/dev/null | fgrep root=/dev/dm-0 > /dev/null' ) != 0 else MYDISK_MTPT
    distro.grab_all_tails_packages()
elif argv[2] == 'install-freenet':
    distro = generate_distro_record_from_name( argv[3] )
    assert( os.path.isdir( argv[4] ) is True )
    distro.mountpoint = argv[4]
    distro.install_freenet()
elif argv[2] == 'clone-guest':
    outfile = '/tmp/default_guest_settings.tar.xz'
    files_to_save = '\
.config/gtk-3.0/settings.ini \
.config/dconf/user \
.config/mate/backgrounds.xml \
.config/keepassx/config.ini \
.xscreensaver \
.themes \
.gtkrc-2.0 \
.config/chromium'
    distro = generate_distro_record_from_name( argv[3] )
    system_or_die( 'cd %s; tar -cJ %s > %s' % ( GUEST_HOMEDIR, files_to_save, outfile ) )
    print( 'Saved %s/.* goodies to %s' % ( GUEST_HOMEDIR, outfile ) )
elif argv[2] == 'do-kernel':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT if os.system( 'mount | grep /dev/mapper &> /dev/null' ) != 0 else '/'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.download_modify_build_and_install_kernel_and_mkfs()
elif argv[2] == 'kooky':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT if os.system( 'mount | grep /dev/mapper &> /dev/null' ) != 0 else '/'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.build_kooky_filesystem_modules_for_chromeos( really = True )
elif argv[2] == 'modify-kernel-sources':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT if os.system( 'mount | grep /dev/mapper &> /dev/null' ) != 0 else '/'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.call_bash_script_that_modifies_kernel_n_mkfs_sources()
    assert( 0 == os.system( 'cat %s%s/config | grep UNION_FS' % ( distro.mountpoint, distro.kernel_src_basedir ) ) )
#    distro.download_kernel_and_mkfs_sources()
#    distro.modify_build_and_install_mkfs_and_kernel_for_OS()
elif argv[2] == 'sign-and-write':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
#    if root_partition_device.find( '/dev/mapper' ) >= 0:
#                param_A = 'cryptdevice=%s:%s' % ( self.spare_dev, os.path.basename( root_partition_device ) )
#            else:
    res = distro.sign_and_write_custom_kernel( distro.device, distro.root_dev, '' )
elif argv[2] == 'tarball-me':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    distro.generate_tarball_of_my_rootfs( '/tmp/out.tgz' )
    os.system( 'rm -f /tmp/out.tgz' )
elif argv[2] == 'posterity':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    if 0 != distro.save_for_posterity_if_possible_D():
        failed( 'Failed to create sample distro posterity file' )
elif argv[2] == 'udev':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    os.system( 'python3 /usr/local/bin/Chrubix/src/poweroff_if_disk_removed.py' )
elif argv[2] == 'tweak-lxdm-source':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    p = '%s/%s' % ( distro.sources_basedir, 'lxdm' )
    generate_mickeymouse_lxdm_patch( distro.mountpoint, p, '%s/debian/patches/99_mickeymouse.patch' % ( p ) )
elif argv[2] == 'chromium':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    chroot_this( distro.mountpoint, 'yes "" 2>/dev/null | apt-get build-dep chromium' )
    distro.build_and_install_package_from_deb_or_ubu_source( 'chromium-browser', 'https://packages.debian.org/' + argv[3] )
elif argv[2] == 'install-bitmask':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    distro.install_leap_bitmask()
# elif argv[2] == 'download-kernel-source':
#     distro = generate_distro_record_from_name( argv[3] )
#     distro.mountpoint = '/' if os.system( 'cat /proc/cmdline 2>/dev/null | fgrep root=/dev/dm-0 > /dev/null' ) != 0 else MYDISK_MTPT
#     distro.device = '/dev/mmcblk1'
#     distro.root_dev = '/dev/mmcblk1p3'
#     distro.spare_dev = '/dev/mmcblk1p2'
#     distro.kernel_rebuild_required = True  # ...because the initramfs needs our boom pw, which means we'll have to rebuild initramfs.... which means rebuilding kernel!
#     distro.root_is_encrypted = False
#     distro.kthx = True  # True
#     distro.use_latest_kernel = False
#     distro.download_kernel_source()
# elif argv[2] == 'build-kernel':
#     distro = generate_distro_record_from_name( 'debianjessie' )
#     distro.mountpoint = '/' if os.system( 'cat /proc/cmdline 2>/dev/null | fgrep root=/dev/dm-0 > /dev/null' ) != 0 else MYDISK_MTPT
#     distro.device = '/dev/mmcblk1'
#     distro.root_dev = '/dev/mmcblk1p3'
#     distro.spare_dev = '/dev/mmcblk1p2'
#     distro.kernel_rebuild_required = True  # ...because the initramfs needs our boom pw, which means we'll have to rebuild initramfs.... which means rebuilding kernel!
#     distro.root_is_encrypted = False
#     distro.kthx = True  # True
#     distro.use_latest_kernel = True
#     distro.build_kernel()
elif argv[2] == 'patch-nm':
    distro = generate_distro_record_from_name( 'debianwheezy' )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    patch_org_freedesktop_networkmanager_conf_file( '%s/etc/dbus-1/system.d/org.freedesktop.NetworkManager.conf' % ( distro.mountpoint ),
                                                        '%s/usr/local/bin/Chrubix/blobs/settings/nmgr-cfg-diff.txt.gz' % ( distro.mountpoint ) )
elif argv[2] == 'makepkg':
    print( 'Assuming archlinux' )
    distro = generate_distro_record_from_name( 'archlinux' )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    pkg = argv[3]
#    sys.exit( 0 )
    print( "Building %s" % ( pkg ) )
    if pkg == 'linux-chromebook':
        call_makepkg_or_die( mountpoint = '/', \
                                package_path = '%s/%s' % ( distro.sources_basedir, pkg ), \
                                cmd = 'cd %s && makepkg --skipchecksums --nobuild -f' % ( distro.mountpoint + distro.kernel_src_basedir ),
                                errtxt = 'Failed to handle %s' % ( pkg ) )
    else:
        call_makepkg_or_die( mountpoint = '/', \
                                package_path = '%s/%s' % ( distro.sources_basedir, pkg ), \
                                cmd = 'cd %s/%s && makepkg --skipchecksums --nobuild -f' % ( distro.sources_basedir, pkg ),
                                errtxt = 'Failed to download %s' % ( pkg ) )
elif argv[2] == 'alarpy-build':
    distro = generate_distro_record_from_name( 'debianwheezy' )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    distro.build_and_install_package_into_alarpy_from_source( argv[3], quiet = True )
elif argv[2] == 'install-i2p':
    distro = generate_distro_record_from_name( argv[3] )
    assert( os.path.isdir( argv[4] ) is True )
    distro.mountpoint = argv[4]
#    distro.mountpoint = MYDISK_MTPT
#    distro.device = '/dev/mmcblk1'
#    distro.root_dev = '/dev/mmcblk1p3'
#    distro.spare_dev = '/dev/mmcblk1p2'
    distro.install_i2p()
elif argv[2] == 'win-xp-theme':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = MYDISK_MTPT
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    distro.install_win_xp_theme()
elif argv[2] == 'free':
    r = remaining_megabytes_free_on_device( argv[3] )
    failed( 'free space on %s is %d MB' % ( argv[3], r ) )
else:
    raise RuntimeError ( 'I do not understand %s' % ( argv[2] ) )
os.system( 'sleep 4' )
print( "Exiting w/ retval=%d" % ( res ) )
sys.exit( res )


