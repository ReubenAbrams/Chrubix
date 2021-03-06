#!/usr/local/bin/python3

import sys
import os
import pickle
import binascii
import time
import subprocess
import getopt
import hashlib
import base64
from chrubix.utils import call_binary, read_oneliner_file, write_oneliner_file, call_binary_and_show_progress, \
                          wget, failed, logme
from chrubix.utils.postinst import configure_lxdm_behavior
from chrubix import distros
from chrubix.distros.archlinux import ArchlinuxDistro
from chrubix.distros.debian import WheezyDebianDistro, JessieDebianDistro, StretchDebianDistro, TailsWheezyDebianDistro
from chrubix.distros.kali import KaliDistro
from chrubix.distros.fedora import NineteenFedoraDistro
from chrubix.distros.ubuntu import VividUbuntuDistro
from chrubix.distros.suse import SuseDistro
from _sqlite3 import InternalError


def list_command_line_options():
    print( """
    chrubix [options]

    -h            get help
    -D<distro>    install <distro>
    -d<dev>       destination storage device
    -r<dev>       root/bootstrap device; you may not reformat, but you may install an OS here
    -s<dev>       spare device; you may mount, reformat, etc. this partition
    -k<dev>       where the kernel is to be written (with dd)
    -m<mountpt>   where is the root fs mounted
    -E            evil maid mode :)
    """ )


def generate_distro_record_from_name( name_str ):
    distro_options = {
                  'archlinux'     :ArchlinuxDistro,
                  'fedora19'      :NineteenFedoraDistro,
                  'debianjessie'  :JessieDebianDistro,
                  'kali'          :KaliDistro,
                  'ubuntuvivid'   :VividUbuntuDistro,
                  'suse'          :SuseDistro,
                  'debianstretch' :StretchDebianDistro,
                  'debianwheezy'  :WheezyDebianDistro,
                  'debiantails'   :TailsWheezyDebianDistro,
                  }
    os.system( 'cd /' )
    print( "Creating distro record for %s" % ( name_str ) )
    assert( name_str in distro_options.keys() )
    rec = distro_options[name_str]()  # rec itself handles the naming (......self.name)        #    rec.name = name_str
    assert( None not in ( rec.name, rec.architecture ) )
    assert( rec.branch is not None or rec.name in ( 'archlinux', 'kali', 'fedora' ) )
    return rec



def load_distro_record( mountpoint = '/' ):
    dct_to_load = pickle.load( open( '%s/etc/.distro.rec' % ( mountpoint ), "rb" ) )
    distro_record = generate_distro_record_from_name( dct_to_load['name'] + ( '' if dct_to_load['branch'] is None else dct_to_load['branch'] ) )
    for k in dct_to_load['dct'].keys():
        if k in distro_record.__dict__.keys():
            distro_record.__dict__[k] = dct_to_load['dct'][k]
        else:
            print( 'Warning - %s is not in the distro rec. Therefore, I shall not set its value to %s.' % ( k, dct_to_load['dct'][k] ) )
    return distro_record


def save_distro_record( distro_rec = None, mountpoint = '/' ):
    assert( distro_rec is not None )
    original_status_lst = distro_rec.status_lst
    try:
        distro_rec.status_lst = original_status_lst[-5:]
    except ( IndexError, SyntaxError ):
        logme( 'Unable to truncate status_lst. Bummer, man...' )
    dct_to_save = {'name':distro_rec.name, 'branch':distro_rec.branch, 'dct':distro_rec.__dict__}
    pickle.dump( dct_to_save, open( '%s/etc/.distro.rec' % ( mountpoint ), "wb" ) )
    if os.path.exists( '%s/etc/lxdm/lxdm.conf' % ( mountpoint ) ):
        configure_lxdm_behavior( mountpoint, distro_rec.lxdm_settings )


def process_command_line( argv ):
    do_distro = None
    do_device = None
    do_root_dev = None
    do_kernel_dev = None
    do_spare_dev = None
    do_evil_maid = False
    do_latest_kernel = False
    install_to_plain_p3 = False
    print( "Running chrubix from command line." )
    if len( sys.argv ) <= 1:
        list_command_line_options()
        raise getopt.GetoptError( "In command line, please specify name of distro" )
    optlist, args = getopt.getopt( argv[1:], 'hEZK:P:D:d:r:s:k:m:' )
    args = args  # hide Eclipse warning
    for ( opt, param ) in optlist:
        if opt == '-h':
            list_command_line_options()
            sys.exit( 1 )
        elif opt == '-D':
            do_distro = param
#            print( 'Distro = %s' % ( do_distro ) )
        elif opt == '-d':
            do_device = param
        elif opt == '-r':
            do_root_dev = param
        elif opt == '-s':
            do_spare_dev = param
        elif opt == '-k':
            do_kernel_dev = param
        elif opt == '-m':
            do_mountpoint = param
        elif opt == '-K':
            do_latest_kernel = True if param == 'yes' else False
        elif opt == '-E':
            do_evil_maid = True
        elif opt == '-Z':
            install_to_plain_p3 = True
        else:
            raise getopt.GetoptError( str( opt ) + " is an unrecognized command-line parameter" )
    distro = generate_distro_record_from_name( do_distro )
    distro.device = do_device
    distro.root_dev = do_root_dev
    distro.kernel_dev = do_kernel_dev
    distro.spare_dev = do_spare_dev
    distro.mountpoint = do_mountpoint
    distro.install_to_plain_p3 = install_to_plain_p3
    distro.use_latest_kernel = do_latest_kernel
    if do_evil_maid:
        distro.reboot_into_stage_two = True
        distro.kernel_rebuild_required = True
        distro.kthx = True
        distro.pheasants = True
        logme( 'Configuring for Evil Maid Protection Mode' )
    return distro


def exec_cli( argv ):
    '''
    If main.py detects that Chrubix was called from within ChromeOS, program execution goes HERE.
    This function's job is to install a GNU/Linux variant on the partitions that are already mounted.
    - Process commnad line w/ process_command_line(), returning a distro struct (for ppropriate distro)
    - distro.install() -- i.e. install Linux on MMC w/ the appropriate distro subclass.
    '''
    res = 0
    if os.path.isdir( '/Users' ) or not os.path.isfile( '/proc/cmdline' ):
        failed( 'testbed() disabled' )
#        res = testbed( argv )
#        raise EnvironmentError( 'Do not call me if you are running under an OS other than Linux, please.' )
    elif read_oneliner_file( '/proc/cmdline' ).find( 'cros_secure' ) < 0:
        raise EnvironmentError( 'Boot into ChromeOS if you want to run me, please.' )
    elif os.system( 'mount | grep /dev/mapper/encstateful &> /dev/null' ) == 0 and len( argv ) == 0:
        raise EnvironmentError( 'OK, you are in ChromeOS; now, chroot into the bootstrap and run me again, please.' )
    else:
#        os.system( 'clear' )
        distro = process_command_line( argv, )  # returns a record (instance) of the appropriate Linux distro subclass
        res = distro.install()
        if res is None:
            res = 0
    if res != 0:
        print( 'exec_cli() returning w/ res=%d' % ( res ) )
    return res

