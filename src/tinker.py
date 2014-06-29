#!/usr/local/bin/python3
#
# tinker.py
# Test subroutine of the CHRUBIX project
# ...for me to tinker with things :)
#

import sys
import os
from chrubix import generate_distro_record_from_name
from chrubix.utils import fix_broken_hyperlinks, system_or_die, chroot_this
from chrubix.distros.debian import generate_mickeymouse_lxdm_patch
from chrubix.utils.postinst import remove_junk, ask_the_user__guest_mode_or_user_mode__and_create_one_if_necessary


try:
    a = FileNotFoundError
except:
    FileNotFoundError = RuntimeError

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
if argv[2] == 'build-a-bunch':
    dct = {'git':( 'cpuburn', 'advancemenu' ),
           'src':( 'star', 'salt' ),
           'debian':( 'afio', ),
           'ubuntu':( 'lzop', )}
                                                # cgpt? lxdm? chromium?
    distro = generate_distro_record_from_name( 'wheezy' )
    distro.mountpoint = '/tmp/_root' if os.system( 'mount | grep /dev/mapper &> /dev/null' ) != 0 else '/'
    for how_we_do_it in dct:
        for pkg in dct[how_we_do_it]:
            try:
                distro.install_expatriate_software_into_a_debianish_OS( 
                                                            package_name = pkg,
                                                            method = how_we_do_it )
                good_list.append( pkg )
            except ( FileNotFoundError, SyntaxError, RuntimeError ):
                bad_list.append( pkg )
    print( "good:", good_list )
    print( "bad :", bad_list )
elif argv[2] == 'build-from-debian':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    pkg = argv[4]
#    sys.exit( 0 )
    print( "Building %s from Deb-ish => Wheezy" % ( pkg ) )
    distro.build_and_install_package_from_debian_source( pkg )
elif argv[2] == 'build-from-ubuntu':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    pkg = argv[4]
#    sys.exit( 0 )
    print( "Building %s from Ubu-ish => Wheezy" % ( pkg ) )
    distro.build_and_install_package_from_ubuntu_source( pkg )
elif argv[2] == 'build-from-src':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    pkg = argv[4]
    distro.build_and_install_software_from_archlinux_source( pkg )
elif argv[2] == 'fix-hyperlinks':
    fix_broken_hyperlinks( argv[3] )
elif argv[2] == 'build-from-git':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    pkg = argv[4]
    sources_basedir = '/root/.rmo/PKGBUILDs/core'
    mountpoint = '/tmp/_root'
    distro.build_and_install_software_from_archlinux_git( pkg )
elif argv[2] == 'fire-everything':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    pkg = argv[4]
    distro.install_expatriate_software_into_a_debianish_OS( package_name = pkg, method = None )
elif argv[2] == 'remove-junk':
    remove_junk( '/tmp/_root', '/root/.rmo/PKGBUILDs/core/linux-chromebook' )
elif argv[2] == 'postinst':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/'
    distro.install_tweaks_for_lxdm_chrome_iceweasel_and_distrospecific_stuff()
elif argv[2] == 'initramfs':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.redo_kernel( argv[4], distro.root_dev, distro.mountpoint )
elif argv[2] == 'redo-kernel':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.modify_build_and_install_mkfs_and_kernel_for_OS( apply_kali_patch = False )
elif argv[2] == 'install-freenet':
    distro = generate_distro_record_from_name( argv[3] )
    assert( os.path.isdir( argv[4] ) is True )
    distro.mountpoint = argv[4]
    distro.install_freenet()
elif argv[2] == 'clone-guest':
    outfile = '/tmp/default_guest_files.tar.xz'
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
    system_or_die( 'cd /tmp/.guest; tar -cJ %s > %s' % ( files_to_save, outfile ) )
    print( 'Saved /tmp/.guest/.* goodies to %s' % ( outfile ) )
elif argv[2] == 'stage-three':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
#    distro.download_kernel_and_mkfs_sources()
    distro.modify_build_and_install_mkfs_and_kernel_for_OS()
elif argv[2] == 'sign-and-write':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
#    if root_partition_device.find( '/dev/mapper' ) >= 0:
#                param_A = 'cryptdevice=%s:%s' % ( self.spare_dev, os.path.basename( root_partition_device ) )
#            else:
    res = distro.sign_and_write_custom_kernel( distro.device, distro.root_dev, '' )
elif argv[2] == 'tarball-me':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    distro.generate_tarball_of_my_rootfs( '/tmp/out.tgz' )
    os.system( 'rm -f /tmp/out.tgz' )
elif argv[2] == 'new-user':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    ask_the_user__guest_mode_or_user_mode__and_create_one_if_necessary( argv[3], distro.mountpoint )
elif argv[2] == 'udev':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    os.system( 'python3 /usr/local/bin/Chrubix/src/poweroff_if_disk_removed.py' )
elif argv[2] == 'tweak-lxdm-source':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    p = '%s/%s' % ( distro.sources_basedir, 'lxdm' )
    generate_mickeymouse_lxdm_patch( distro.mountpoint, p, '%s/debian/patches/99_mickeymouse.patch' % ( p ) )
elif argv[2] == 'chromium':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    chroot_this( distro.mountpoint, 'yes "" 2>/dev/null | apt-get build-dep chromium' )
    distro.build_and_install_package_from_deb_or_ubu_source( 'chromium-browser', 'https://packages.debian.org/' + argv[3] )
elif argv[2] == 'install-bitmask':
    distro = generate_distro_record_from_name( argv[3] )
    distro.mountpoint = '/tmp/_root'
    distro.device = '/dev/mmcblk1'
    distro.root_dev = '/dev/mmcblk1p3'
    distro.spare_dev = '/dev/mmcblk1p2'
    distro.install_leap_bitmask()
else:
    raise RuntimeError ( 'I do not understand %s' % ( argv[2] ) )
os.system( 'sleep 5' )
print( "Exiting w/ retval=%d" % ( res ) )
sys.exit( res )

