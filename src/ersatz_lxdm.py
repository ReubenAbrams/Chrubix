#!/usr/local/bin/python3
#
# ersatz_lxdm.py
# - replaces / wraps around lxdm and greeter.py
# - is called by ersatz_lxdm.sh
###########################################################


import sys
import os
from chrubix.utils import logme, write_oneliner_file
from chrubix.utils.postinst import configure_lxdm_behavior
from chrubix import load_distro_record




def do_audio_and_network_stuff():
    logme( 'ersatz_lxdm.py --- do_audio_and_network_stuff() --- entering' )
    for cmd in ( 
                'systemctl start NetworkManager',
                'systemctl enable privoxy',
                'amixer sset Speaker unmute',
                'amixer sset Speaker 30%',
                '''for q in `amixer | grep Speaker | cut -d"'" -f2 | tr ' ' '/'`; do g=`echo "$q" | tr '/' ' '`; amixer sset "$g" unmute; done''',
                'which alsactl &> /dev/null && alsactl store &> /dev/null'
                ):
        if 0 != os.system( cmd ):
            logme( '%s ==> failed' % ( cmd ) )
    logme( 'ersatz_lxdm.py --- do_audio_and_network_stuff() --- leaving' )



# ------------------------------------------------------------------------------------------------------------------



if __name__ == "__main__":
    logme( 'ersatz_lxdm.py --- starting w/ params %s' % ( str( sys.argv ) ) )
    logme( 'ersatz_lxdm.py --- loaded distro record (yay)' )
#    set_up_guest_homedir()
#    set_up_guest_homedir( homedir = '/tmp/.guest' )
    logme( 'ersatz_lxdm.py --- guest homedir set up OK' )
    os.system( 'rm -f /tmp/.yes_greeter_is_running' )
    if load_distro_record().lxdm_settings['use greeter gui']:
        os.system( 'touch /tmp/.yes_greeter_is_running' )
        logme( 'ersatz_lxdm.py --- using ersatz_lxdm gui' )
        if len( sys.argv ) <= 1 or sys.argv[1] != 'X':
            logme( 'ersatz_lxdm.py --- starting XWindow and asking it to run the ersatz_lxdm gui' )
            write_oneliner_file( '/usr/local/bin/ersatz_lxdm.rc', 'exec python3 ersatz_lxdm.py X' )
            res = os.system( 'startx /usr/local/bin/ersatz_lxdm.rc' )
            os.system( 'rm -f /usr/local/bin/ersatz_lxdm.rc' )
            logme( 'ersatz_lxdm.py --- back from calling XWindow to run ersatz_lxdm gui; res=%d' % ( res ) )
        else:
            logme( 'ersatz_lxdm.py --- actually running ersatz_lxdm gui' )
            res = os.system( '/usr/local/bin/greeter.sh' )
            logme( 'ersatz_lxdm.py --- back from actually running ersatz_lxdm gui; res=%d' % ( res ) )
        if res != 0:
            logme( 'ersatz_lxdm.py --- ending sorta prematurely; res=%d' % ( res ) )
            sys.exit( res )
    if not os.path.exists( '/tmp/.already.initialized.network.stuff' ):
        do_audio_and_network_stuff()
        os.system( 'touch /tmp/.already.initialized.network.stuff' )
    logme( 'ersatz_lxdm.py --- MAIN LOOP' )
#    while 'english' != 'british':
    logme( 'ersatz_lxdm.py --- configuring lxdm behavior' )
    configure_lxdm_behavior( '/', load_distro_record().lxdm_settings )  # This is silly. Modify record, save record, then make me reload record? (See next line.)
    distro = load_distro_record()
    logme( 'ersatz_lxdm.py --- calling lxdm; FYI, wm=%s' % ( load_distro_record().lxdm_settings['window manager'] ) )
    res = os.system( 'lxdm' )
    logme( 'ersatz_lxdm.py --- back from lxdm' )
    sys.exit( res )

