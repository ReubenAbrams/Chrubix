#!/usr/local/bin/python3
#
# greeter.py
# Replacement for LXDM (?) within Alarmist


import sys
import os
from chrubix.utils import logme, disable_root_password, set_user_password, \
                    system_or_die, write_spoof_script_file, poweroff_now
from chrubix import save_distro_record, load_distro_record


LXDM_CONF = '/etc/lxdm/lxdm.conf'


# ---------------------------------------------------------------------------


from PyQt4.QtCore import SIGNAL, pyqtSignature  # , SLOT
from PyQt4 import QtGui, uic
from ui.ui_AlarmistGreeter import Ui_dlgAlarmistGreeter


def configure_paranoidguestmode_before_calling_lxdm( password, direct, spoof, camouflage ):
    '''
    Greeter calls me before it calls lxdm.
    This is my chance to set up the XP look, enable MAC spoofing, etc.
    '''
    # Set password, if appropriate
    logme( 'configure_para....() - password=%s, direct=%s, spoof=%s, camouflage=%s' % ( str( password ), str( direct ), str( spoof ), str( camouflage ) ) )
    distro = load_distro_record()
    logme( 'At present, windo manager = %s' % ( distro.lxdm_settings['window manager'] ) )
    if password in ( None, '' ):
        disable_root_password( '/' )
    else:
        set_user_password( 'root', password )
    # Enable MAC spoofing, if appropriate
    if spoof:  # https://wiki.archlinux.org/index.php/MAC_Address_Spoofing
        write_spoof_script_file( '/etc/NetworkManager/dispatcher.d/99spoofmymac.sh' )  # NetworkManager will run it, automatically, as soon as network goes up/down
        system_or_die( '''macchanger -r `ifconfig | grep lan0 | cut -d':' -f1 | head -n1`''' )
    else:
        os.system( 'rm -f /etc/NetworkManager/dispatcher.d/99spoofmymac.sh' )
    if camouflage:
        distro.lxdm_settings['window manager'] = '/usr/bin/mate-session'
    else:
        distro.lxdm_settings['window manager'] = distro.lxdm_settings['default wm']
    distro.lxdm_settings['internet directly'] = direct
    save_distro_record( distro )
    os.system( 'echo "configure_paranoid... - part E --- BTW, wm is now %s" >> /tmp/log.txt' % ( distro.lxdm_settings['window manager'] ) )
    assert( camouflage is False or ( camouflage is True and 0 == os.system( 'cat /etc/lxdm/lxdm.conf | fgrep mate-session' ) ) )
    os.system( 'cp /etc/lxdm/lxdm.conf /etc/lxdm/lxdm.conf.doin-the-doo' )
    os.system( 'sync;sync;sync' )


class AlarmistGreeter( QtGui.QDialog, Ui_dlgAlarmistGreeter ):
#     @property
#     def password( self ):
#         return self._password
#     @password.setter
#     def password( self, value ):
#         self._password = value
    def __init__( self ):  # title = "New Password", cksum = None ):
        super( AlarmistGreeter, self ).__init__()
        self.setupUi( self )
        self.more_options = False
        self.password = False
        self.use_pw = self.chkAllowrootpassword.isChecked()
        self.direct = self.radDirectYes.isChecked()
        self.spoof = self.radSpoofYes.isChecked()
        self.camouflage = self.radCamouflageYes.isChecked()
        self.previous_height = None

        self.lblEyes.lower()
        self.connect( self.btnMoreoptions, SIGNAL( "clicked()" ), self.enableMoreOptions )
#        self.connect( self.btnContinue, SIGNAL( "clicked()" ), self.btnContinueClicked )
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
            os.system( 'sync;sync;sync; umount /dev/mmcblk1p* /dev/sda* /dev/mapper/* &> /dev/null' )
            poweroff_now()
            os.system( 'sleep 5' )
#            os.system( 'shutdown -h now' )
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
        self.chkAllowrootpassword.setChecked( True )
        self.clickedAllowrootpassword( True )
        self.adjustSize()

    @pyqtSignature( "" )
    def closeEvent( self, event ):
        if self.more_options and self.use_pw and not self.password:
#            QtGui.QMessageBox.question( self, "", "Either uncheck the 'password' checkbox\nor enter a good pasword twice.", QtGui.QMessageBox.Ok )
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
            d = load_distro_record()
            logme( 'camouflage=%s; window manager=%s; is this kosher?' % ( str( self.camouflge ), d.lxdm_settings['window manager'] ) )
            sys.exit( 0 )  # I assume the program that called me will now call lxdm, which will log in as guest & so on.


#------------------------------------------------------------------------------------------------------------------------------------


if __name__ == "__main__":
    logme( 'greeter.py --- running greeter gui' )
    os.system( 'xset s off' )
    os.system( 'xset -dpms' )
#        os.system( "rm -f ui_AlarmistGreeter.py ui/ui_AlarmistGreeter.py qrc_resources.py" )
    if os.system( 'mount | grep /dev/mapper/encstateful &> /dev/null' ) == 0 \
    or os.system( 'mount | grep hfs &> /dev/null' ) == 0:
        # compile Qt Creator UI files into Python bindings
        os.system( 'export PATH=/opt/local/bin:$PATH' )
        for fname in [f for f in os.listdir( "ui" ) if f[-3:] == ".ui" and f[0] != "." ]:
            if not os.path.exists( 'ui/ui_%s.py' % ( fname[:-3] ) ):
                os.system( "PATH=/opt/local/bin:$PATH pyuic4 -o ui/ui_" + fname[:-3] + ".py ui/" + fname[:-3] + ".ui" )
                print ( "Processing " + fname )
        if not os.path.exists( 'resources_rc.py' ):
            os.system( "PATH=/opt/local/bin:$PATH pyrcc4 -py3 -o resources_rc.py ui/resources.qrc" )
    app = QtGui.QApplication( sys.argv )
    window = AlarmistGreeter()
    window.show()
    window.raise_()
    res = app.exec_()
    logme( 'greeter.py --- back; exiting now; res=%d' % ( res ) )
    sys.exit( res )

