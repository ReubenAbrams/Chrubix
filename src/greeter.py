#!/usr/local/bin/python3
#
# greeter.py
# Replacement for LXDM (?) within Alarmist
#



import sys
import os
from chrubix.utils import logme, save_distro_record, load_distro_record, write_oneliner_file, \
                    system_or_die, configure_paranoidguestmode_before_calling_lxdm, failed
from chrubix.utils.postinst import configure_lxdm_behavior
from chrubix import generate_distro_record_from_name
import hashlib


GUEST_HOMEDIR = '/tmp/.guest'
LXDM_CONF = '/etc/lxdm/lxdm.conf'


def set_up_guest_homedir():
    logme( 'greeter.py --- set_up_guest_homedir() --- entering' )
    for cmd in ( 
                'mkdir -p %s' % ( GUEST_HOMEDIR ),
                'chmod 700 %s' % ( GUEST_HOMEDIR ),
                'tar -Jxf /usr/local/bin/Chrubix/blobs/settings/default_guest_files.tar.xz -C %s' % ( GUEST_HOMEDIR ),
                'chown -R guest.guest %s' % ( GUEST_HOMEDIR ),
                'chmod 755 %s' % ( LXDM_CONF ),
                ):
        if 0 != os.system( cmd ):
            logme( '%s ==> failed' % ( cmd ) )
    logme( 'greeter.py --- set_up_guest_homedir() --- leaving' )


def do_audio_and_network_stuff():
    logme( 'greeter.py --- do_audio_and_network_stuff() --- entering' )
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
    logme( 'greeter.py --- do_audio_and_network_stuff() --- leaving' )


def actually_call_the_greeter_gui( distro ):
    logme( 'greeter.py --- running greeter gui' )
    os.system( 'xset s off' )
    os.system( 'xset -dpms' )
    if os.system( 'mount | grep /dev/mapper/encstateful &> /dev/null' ) == 0 \
    or os.system( 'mount | grep hfs &> /dev/null' ) == 0:
        # compile Qt Creator UI files into Python bindings
        os.system( "rm -f ui_AlarmistGreeter.py ui/ui_AlarmistGreeter.py qrc_resources.py" )
        os.system( 'export PATH=/opt/local/bin:$PATH' )
        for fname in [f for f in os.listdir( "ui" ) if f[-3:] == ".ui" and f[0] != "." ]:
            os.system( "PATH=/opt/local/bin:$PATH pyuic4 -o ui/ui_" + fname[:-3] + ".py ui/" + fname[:-3] + ".ui" )
            print ( "Processing " + fname )
        os.system( "PATH=/opt/local/bin:$PATH pyrcc4 -py3 -o resources_rc.py ui/resources.qrc" )
    app = QtGui.QApplication( sys.argv )
    window = AlarmistGreeter()
    window.show()
    window.raise_()
    res = app.exec_()
    logme( 'greeter.py --- back from greeter gui' )
    return res


# ---------------------------------------------------------------------------








from PyQt4.QtCore import SIGNAL, SLOT, pyqtSignature
from PyQt4 import QtGui, uic
# try:
#    from PyQt4.QtCore import QString
# except ImportError:
#    # we are using Python3 so QString is not defined
#    QString = str
# import resources_rc
from ui.ui_AlarmistGreeter import Ui_dlgAlarmistGreeter








class AlarmistGreeter( QtGui.QDialog, Ui_dlgAlarmistGreeter ):
#     @property
#     def password( self ):
#         return self._password
#     @password.setter
#     def password( self, value ):
#         self._password = value
    def __init__( self ):  # title = "New Password", cksum = None ):
        super( AlarmistGreeter, self ).__init__()
        uic.loadUi( "ui/AlarmistGreeter.ui", self )
        self.more_options = False
        self.password = False
        self.use_pw = self.chkAllowrootpassword.isChecked()
        self.direct = self.radDirectYes.isChecked()
        self.spoof = self.radSpoofYes.isChecked()
        self.camouflage = self.radCamouflageYes.isChecked()
        self.previous_height = None

        self.lblEyes.lower()
        self.connect( self.btnMoreoptions, SIGNAL( "clicked()" ), self.enableMoreOptions )
        self.connect( self.btnContinue, SIGNAL( "clicked()" ), SLOT( "close()" ) )
#        self.connect( self.btnBigcontinue, SIGNAL( "clicked()" ), SLOT( "close()" ) )
        self.connect( self.radCamouflageYes, SIGNAL( "clicked()" ), self.clickedCamouflageYes )
        self.connect( self.radCamouflageNo, SIGNAL( "clicked()" ), self.clickedCamouflageNo )
        self.connect( self.radSpoofYes, SIGNAL( "clicked()" ), self.clickedSpoofYes )
        self.connect( self.radSpoofNo, SIGNAL( "clicked()" ), self.clickedSpoofNo )
        self.connect( self.radDirectYes, SIGNAL( "clicked()" ), self.clickedDirectYes )
        self.connect( self.radDirectNo, SIGNAL( "clicked()" ), self.clickedDirectNo )
        self.connect( self.chkAllowrootpassword, SIGNAL( "clicked(bool)" ), self.clickedAllowrootpassword )
        self.connect( self.ledPassword1, SIGNAL( "textChanged(QString)" ), self.editedPasswordField1 )
        self.connect( self.ledPassword2, SIGNAL( "textChanged(QString)" ), self.editedPasswordField2 )
        self.raise_()
#        self.btnBigcontinue.setVisible( False )
        self.ledPassword1.setEnabled( False )
        self.ledPassword2.setEnabled( False )
#        self.exec_()

    @pyqtSignature( "" )
    def clickedCamouflageYes( self ):
        self.camouflage = True

    @pyqtSignature( "" )
    def clickedCamouflageNo( self ):
        self.camouflage = False

    @pyqtSignature( "" )
    def clickedSpoofYes( self ):
        self.spoof = True

    @pyqtSignature( "" )
    def clickedSpoofNo( self ):
        self.spoof = False

    @pyqtSignature( "" )
    def clickedDirectYes( self ):
        self.direct = True

    @pyqtSignature( "" )
    def clickedDirectNo( self ):
        self.direct = False

    @pyqtSignature( "" )
    def editedPasswordField1( self, new_pw ):
        if new_pw != self.ledPassword2.text():
            self.frame3.setStyleSheet( "background-color: pink" )
            self.password = None
        else:
            self.frame3.setStyleSheet( "background-color: lightgreen" )
            self.password = new_pw

    @pyqtSignature( "" )
    def editedPasswordField2( self, new_pw ):
        if self.ledPassword1.text() != new_pw:
            self.frame3.setStyleSheet( "background-color: pink" )
            self.password = None
        else:
            self.frame3.setStyleSheet( "background-color: lightgreen" )
            self.password = new_pw

    @pyqtSignature( "" )
    def clickedAllowrootpassword( self, on_or_off ):
        self.ledPassword1.setEnabled( on_or_off )
        self.ledPassword2.setEnabled( on_or_off )
        if on_or_off is True:
            self.ledPassword1.setFocus()
            self.use_pw = True
        else:
            self.ledPassword1.setText( '' )
            self.ledPassword2.setText( '' )
            self.frame3.setStyleSheet( None )
            self.use_pw = False

    @pyqtSignature( "" )
    def enableMoreOptions( self ):
        if self.more_options:
            os.system( 'shutdown -h now' )
            sys.exit( 0 )
            return
#        self.btnMoreoptions.setEnabled( False )
#        self.btnMoreoptions.setVisible( False )
#        self.btnContinue.setEnabled( False )
#        self.btnContinue.setVisible( False )
#        self.btnBigcontinue.setVisible( True )
#        self.btnBigcontinue.raise_()
#        self.btnBigcontinue.raise_()
#        self.btnBigcontinue.raise_()
# #        self.btnContinue.set
        self.more_options = True
        self.btnMoreoptions.setText( 'Abort' )
        self.adjustSize()

    @pyqtSignature( "" )
    def closeEvent( self, event ):
        if self.more_options and self.use_pw and not self.password:
            QtGui.QMessageBox.question( self, "", "Either uncheck the 'password' checkbox\nor enter a good pasword twice.", QtGui.QMessageBox.Ok )
            event.ignore()
        else:
            event.accept()
            if not self.use_pw:
                self.password = None
            configure_paranoidguestmode_before_calling_lxdm( 
                                        password = self.password,
                                        direct = self.direct,
                                        spoof = self.spoof,
                                        camouflage = self.camouflage )
            sys.exit( 0 )  # I assume the program that called me will now call lxdm, which will log in as guest & so on.


if __name__ == "__main__":
    logme( 'greeter.py --- starting w/ params %s' % ( str( sys.argv ) ) )
    distro = load_distro_record()
    logme( 'greeter.py --- loaded distro record (yay)' )
    set_up_guest_homedir()
    logme( 'greeter.py --- guest homedir set up OK' )
    if distro.lxdm_settings['use greeter gui']:
        logme( 'greeter.py --- using greeter gui' )
        if len( sys.argv ) <= 1 or sys.argv[1] != 'X':
            logme( 'greeter.py --- starting XWindow and asking it to run the greeter gui' )
            write_oneliner_file( '/usr/local/bin/greeter.rc', 'exec python3 greeter.py X' )
            res = os.system( 'startx /usr/local/bin/greeter.rc' )
            logme( 'greeter.py --- back from calling XWindow to run greeter gui; res=%d' % ( res ) )
        else:
            logme( 'greeter.py --- actually running greeter gui' )
            res = actually_call_the_greeter_gui( distro )
            logme( 'greeter.py --- back from actually running greeter gui; res=%d' % ( res ) )
        if res != 0:
            logme( 'greeter.py --- ending sorta prematurely; res=%d' % ( res ) )
            sys.exit( res )
    if os.path.exists( '/etc/.first_time_ever' ):
        do_audio_and_network_stuff()
        os.unlink( '/etc/.first_time_ever' )
    logme( 'greeter.py --- configuring lxdm behavior' )
    configure_lxdm_behavior( '/', distro.lxdm_settings )
    logme( 'greeter.py --- saving distro record' )
    save_distro_record( distro )
    logme( 'greeter.py --- calling lxdm' )
    res = os.system( 'lxdm' )
    logme( 'greeter.py --- back from lxdm; exiting now; res=%d' % ( res ) )
    sys.exit( res )




