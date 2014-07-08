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
from chrubix.distros.debian import WheezyDebianDistro, JessieDebianDistro
from chrubix.distros.kali import KaliDistro
from chrubix.distros.alarmist import AlarmistDistro
from chrubix.distros.fedora import FedoraDistro
from chrubix.distros.ubuntu import PangolinUbuntuDistro
from chrubix.distros.suse import SuseDistro


def list_command_line_options():
    print( """
    chrubix [options]

    -h            get help
    -K<on/off>    kthx on/off
    -P<on/off>    pheasants on/off
    -D<distro>    install <distro>
    -d<dev>       destination storage device
    -r<dev>       root/bootstrap device; you may not reformat, but you may install an OS here
    -s<dev>       spare device; you may mount, reformat, etc. this partition
    -k<dev>       where the kernel is to be written (with dd)
    """ )


def generate_distro_record_from_name( name_str ):
    distro_options = {
                  'alarmistwheezy':AlarmistDistro,
                  'archlinux'     :ArchlinuxDistro,
                  'fedora'        :FedoraDistro,
                  'debianjessie'  :JessieDebianDistro,
                  'kali'          :KaliDistro,
                  'ubuntupangolin':PangolinUbuntuDistro,
                  'suse'          :SuseDistro,
                  'debianwheezy'  :WheezyDebianDistro,
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
    dct_to_save = {'name':distro_rec.name, 'branch':distro_rec.branch, 'dct':distro_rec.__dict__}
    pickle.dump( dct_to_save, open( '%s/etc/.distro.rec' % ( mountpoint ), "wb" ) )
    if os.path.exists( '%s/etc/lxdm/lxdm.conf' % ( mountpoint ) ):
        configure_lxdm_behavior( mountpoint, distro_rec.lxdm_settings )


def process_command_line( argv ):
    do_pheasants = True
    do_kthx = True
    do_distro = None
    do_device = None
    do_root_dev = None
    do_kernel_dev = None
    do_spare_dev = None
    print( "Running chrubix from command line." )
    if len( sys.argv ) <= 1:
        list_command_line_options()
        raise getopt.GetoptError( "In command line, please specify name of distro" )
    optlist, args = getopt.getopt( argv[1:], 'hK:P:D:d:r:s:k:' )
    args = args  # hide Eclipse warning
    for ( opt, param ) in optlist:
        if opt == '-h':
            list_command_line_options()
            sys.exit( 1 )
        elif opt == '-P':
            if param == 'off':
                do_pheasants = False
            elif param == 'on':
                do_pheasants = True
            else:
                raise getopt.GetoptError( "-P takes either on or off; you specified " + str( param ) )
        elif opt == '-K':
            if param == 'off':
                do_kthx = False
            elif param == 'on':
                do_kthx = True
            else:
                raise getopt.GetoptError( "-K takes either on or off; you specified " + str( param ) )
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
        else:
            raise getopt.GetoptError( str( opt ) + " is an unrecognized command-line parameter" )
    distro = generate_distro_record_from_name( do_distro )
    distro.kthx = do_kthx
    distro.pheasants = do_pheasants
    distro.device = do_device
    distro.root_dev = do_root_dev
    distro.kernel_dev = do_kernel_dev
    distro.spare_dev = do_spare_dev
    return distro


def exec_cli( argv ):
    '''
    If main.py detects that Chrubix was called from within ChromeOS, program execution goes HERE.
    This function's job is to install a GNU/Linux variant on the partitions that are already mounted.
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

