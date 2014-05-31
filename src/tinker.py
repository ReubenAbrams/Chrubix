#!/usr/local/bin/python3
#
# tinker.py
# Test subroutine of the CHRUBIX project
# ...for Hugo to tinker with things :)
#

import sys
import os
from chrubix import generate_distro_record_from_name
from chrubix.utils import fix_broken_hyperlinks, system_or_die
from chrubix.utils.postinst import remove_junk

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
.config/dhromium'
    distro = generate_distro_record_from_name( argv[3] )
    system_or_die( 'cd /tmp/.guest; tar -cJ %s > %s' % ( files_to_save, outfile ) )
    print( 'Saved /tmp/.guest/.* goodies to %s' % ( outfile ) )
else:
    raise RuntimeError ( 'I do not understand %s' % ( argv[2] ) )
os.system( 'sleep 5' )
print( "Exiting w/ retval=%d" % ( res ) )
sys.exit( res )
