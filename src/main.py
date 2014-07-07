#!/usr/local/bin/python3
#
# main.py
# Main subroutine of the CHRUBIX project
#

import sys
import os
import hashlib
from chrubix.utils import logme
from chrubix import save_distro_record, load_distro_record


try:
    from PyQt4.QtCore import QString
except ImportError:
    QString = str


# os.system( 'rm -f /tmp/chrubix.log' )
logme( '**************************** WELCOME TO CHRUBIX ****************************' )
if os.system( 'cat /proc/cmdline 2>/dev/null | fgrep root=/dev/dm-0 > /dev/null' ) == 0:
    from chrubix import exec_cli
    sys.exit( exec_cli( sys.argv ) )


if os.system( 'mount | grep /dev/mapper/encstateful &> /dev/null' ) == 0 \
or os.system( 'mount | grep hfs &> /dev/null' ) == 0:
    # compile Qt Creator UI files into Python bindings
    os.system( "rm -f ui_AlarmistGreeter.py ui/ui_AlarmistGreeter.py qrc_resources.py" )
    os.system( 'export PATH=/opt/local/bin:$PATH' )
    for fname in [f for f in os.listdir( "ui" ) if f[-3:] == ".ui" and f[0] != "." ]:
        os.system( "PATH=/opt/local/bin:$PATH pyuic4 -o ui/ui_" + fname[:-3] + ".py ui/" + fname[:-3] + ".ui" )
        print ( "Processing " + fname )
    os.system( "PATH=/opt/local/bin:$PATH pyrcc4 -py3 -o resources_rc.py ui/resources.qrc" )


from PyQt4.QtCore import SIGNAL, SLOT, pyqtSignature
from PyQt4.Qt import QLineEdit
from PyQt4 import QtGui, uic
# try:
#    from PyQt4.QtCore import QString
# except ImportError:
#    # we are using Python3 so QString is not defined
#    QString = str
# import resources_rc
from ui.ui_MainWindow import Ui_mnwMain
from ui.ui_ReconfigureorexitForm import Ui_dlgReconfigureorexit
from ui.ui_ChangePasswordDialog import Ui_dlgChangepassword


class ChangePasswordDialog( QtGui.QDialog, Ui_dlgChangepassword ):
    @property
    def password( self ):
        return self._password

    @password.setter
    def password( self, value ):
        self._password = value

    def __init__( self, title = "New Password", cksum = None ):
        self.__cksum = cksum.encode( 'utf-8' )
        self.__title = title
        self._password = None
        super( ChangePasswordDialog, self ).__init__()
        uic.loadUi( "ui/ChangePasswordDialog.ui", self )
        # Enter? => Click OK
        # Escape => Click Cancel
        # Click OK? => Verify password. Then clear fields & quit.
        # Click cancel? Clear fields & quit.
        self.setupUi( self )
        self.setWindowTitle( self.__title )
        self.edlOldpass.setEchoMode( QLineEdit.Password )
        self.edlNewpass1.setEchoMode( QLineEdit.Password )
        self.edlNewpass2.setEchoMode( QLineEdit.Password )
        self.edlOldpass.setFocus()
        self.exec_()

    def accept( self ):
        alleged_old_cksum = hashlib.sha512( str( self.edlOldpass.text() ).encode( 'utf-8' ) ).hexdigest().encode( 'utf-8' )
        print ( "alleged old cksum = " + alleged_old_cksum )
        print ( "real old cksum    = " + self.__old_password_cksum )
        if alleged_old_cksum != self.__cksum:
            QtGui.QMessageBox.question( self, "Bad Password", "Please enter the correct (old) password first.", QtGui.QMessageBox.Ok )
        else:
            if str( self.edlNewpass1.text() ) != str( self.edlNewpass2.text() ):
                QtGui.QMessageBox.question( self, "Bad Password", "Please enter the same (new) password twice.", QtGui.QMessageBox.Ok )
            else:
                print( "password is " + self._password )
                self._password = str( self.edlNewpass1.text() )
                self.__cksum = hashlib.sha512( self._password.encode( 'utf-8' ) ).hexdigest().encode( 'utf-8' )
                super( ChangePasswordDialog, self ).accept()

    def reject( self ):
        self.__cksum = None
        super( ChangePasswordDialog, self ).reject()

    def showDialog( self ):
        text, ok = QtGui.QInputDialog.getText( self, 'Input Dialog',
            'Enter your name:' )
        if ok:
            self.le.setText( str( text ) )

    def cksum( self ):
        return self.__cksum


class MainWindow( QtGui.QMainWindow, Ui_mnwMain ):
#    from chrubix.distros import Distro
    distro = None
    def __init__( self ):
        self.changes_made = False
        super( MainWindow, self ).__init__()
        uic.loadUi( "ui/MainWindow.ui", self )
        self.distro = load_distro_record()
        # populate
        self.connect( self.pteLxdmSettings, SIGNAL( "textChanged()" ), self.pteLxdmSettingsChanged )
        self.connect( self.chkPanicButton, SIGNAL( 'clicked(bool)' ), self.chkPanicButtonClicked )
        self.connect( self.btnApplyAppChanges, SIGNAL( 'clicked()' ), self.btnApplyAppChangesClicked )
        self.connect( self.btnResetAll, SIGNAL( 'clicked()' ), self.btnResetAllClicked )
        self.connect( self.btnResetLxdmSettings, SIGNAL( 'clicked()' ), self.btnResetLxdmSettingsClicked )
        self.connect( self.btnExitWithoutSaving, SIGNAL( "clicked()" ), SLOT( "close()" ) )
        self.connect( self.spiNoofPanicPushesRequired, SIGNAL( 'changed(int)' ), self.spiNoofPanicPushesRequiredChanged )
        self.connect_all_checkboxes_to_setChangesMadeTrue()
        self.populateMainTabWidget()
        self.setChangesMadeFalse()
        self.show()

    @pyqtSignature( "" )
    def setChangesMadeTrue( self ):
        self.changes_made = True
        self.configurePushButtons()

    @pyqtSignature( "" )
    def setChangesMadeFalse( self ):
        self.changes_made = False
        self.configurePushButtons()

    @pyqtSignature( "" )
    def connect_all_checkboxes_to_setChangesMadeTrue( self ):
        for item in ( self.chkEncryptedRootPartition, self.btnChangeRootPassword, self.chkRootKeyTD, \
                     self.btnChooseRootKeyTD, self.chkKernelSignedInTriplicate, self.chkHardwareIsWhitelisted, \
                     self.btnRegenerateWhitelist, self.chkObfuscateFilesystemMarkers, self.chkUseDuressPassword, \
                     self.btnChangeDuressPassword, self.chkEncryptedHomePartition, self.btnChangeHomePassword, \
                     self.chkHomeKeyTD, self.btnChooseHomeKeyTD, self.chkUseDropboxWhenEncryptingHome, \
                     self.chkStoreFreenetAndI2pOnHome, self.chkPanicButton, ):
            self.connect( item, SIGNAL( "clicked()" ), self.setChangesMadeTrue )

    @pyqtSignature( "int" )
    def spiNoofPanicPushesRequiredChanged( self, new_val ):
        self.distro.panic_button = new_val
        self.setChangesMadeTrue()

    @pyqtSignature( "" )
    def populateMainTabWidget( self ):
        self.blockSignals( True )
        self.configurePushButtons()
        self.configureCheckBoxes()
        self.populateLxdmPlaintextEditor()
        self.blockSignals( False )

    @pyqtSignature( "" )
    def configurePushButtons( self ):
        self.btnApplyAppChanges.setEnabled( self.changes_made )
#        self.btnExitWithoutSaving.setEnabled( self.changes_made )
        self.btnExitWithoutSaving.setText( "Lose Changes && Exit" if self.changes_made else 'Exit Program' )
        self.btnResetAll.setEnabled( self.changes_made )
        self.btnChooseRootKeyTD.setEnabled( self.chkRootKeyTD.isChecked() )
        self.btnChooseHomeKeyTD.setEnabled( self.chkHomeKeyTD.isChecked() )
        self.btnRegenerateWhitelist.setEnabled( self.chkHardwareIsWhitelisted.isChecked() )
        self.btnChangeDuressPassword.setEnabled( self.chkUseDuressPassword.isChecked() )
        self.btnChangeHomePassword.setEnabled( self.chkEncryptedHomePartition.isChecked() )
        self.btnChangeRootPassword.setEnabled( self.chkEncryptedRootPartition.isChecked() )
        self.btnChooseHomeKeyTD.setEnabled( self.chkHomeKeyTD.isChecked() )
        self.spiNoofPanicPushesRequired.setEnabled( self.chkPanicButton.isChecked() )
        self.spiNoofPanicPushesRequired.setValue( self.distro.panic_button )

    @pyqtSignature( "" )
    def configureCheckBoxes( self ):
        self.chkEncryptedRootPartition.setChecked( self.distro.root_is_encrypted )
        self.chkEncryptedHomePartition.setChecked( self.distro.home_is_encrypted )
        self.chkRootKeyTD.setChecked( self.distro.root_key_partly_on_TD )
        self.chkHomeKeyTD.setChecked( self.distro.home_key_partly_on_TD )
        self.chkUseDuressPassword.setChecked( self.distro.boom_pw_hash is not None )
        self.btnChangeRootPassword.setEnabled( self.distro.root_key_partly_on_TD )
        self.btnChangeHomePassword.setEnabled( self.distro.home_key_partly_on_TD )
        self.btnChangeDuressPassword.setEnabled( self.distro.boom_pw_hash is not None )
        self.chkUseDropboxWhenEncryptingHome.setChecked( self.distro.use_dropbox )
        self.chkStoreFreenetAndI2pOnHome.setChecked( self.distro.freenet_and_i2p_in_home )
        self.chkPanicButtonClicked( True if self.distro.panic_button > 0 else False )
        self.chkKernelSignedInTriplicate.setChecked( self.distro.kernel_triple_signed )

    @pyqtSignature( "bool" )
    def chkPanicButtonClicked( self, checked ):
        self.spiNoofPanicPushesRequired.setVisible( True if checked else False )
        if checked:
            self.spiNoofPanicPushesRequired.setValue( self.distro.panic_button )

    @pyqtSignature( "" )
    def btnApplyAppChangesClicked( self ):
#        if not self.changes_made:
#            logme( 'No changes were made. Therefore, I have nothing to do. Cool...' )
#        else:
        reply = QtGui.QMessageBox.question( self, "Make Changes", "This may take me a while to do. Are you sure you want to do this?", QtGui.QMessageBox.Yes, QtGui.QMessageBox.No )
        if reply == QtGui.QMessageBox.Yes:
            self.saveLxdmSettingsToMyDistroRecord()
            save_distro_record( self.distro )
            self.setChangesMadeFalse()
            self.populateMainTabWidget()
#        self.chkEncryptedRootPartition.setChecked(self.distro.)
#        self.btnApply

    @pyqtSignature( "" )
    def btnResetAllClicked( self ):
#        if not self.changes_made:
#            logme( 'No changes were made. Therefore, I have nothing to do. Cool...' )
#        else:
        reply = QtGui.QMessageBox.question( self, "Forget Changes", "Are you sure you want to forget the changes that you have proposed?", QtGui.QMessageBox.Yes, QtGui.QMessageBox.No )
        if reply == QtGui.QMessageBox.Yes:
            self.distro = load_distro_record()
            self.setChangesMadeFalse()
            self.populateMainTabWidget()

    @pyqtSignature( "" )
    def pteLxdmSettingsChanged( self ):
        if not self.signalsBlocked():
            self.btnResetLxdmSettings.setEnabled( True )
            self.setChangesMadeTrue()

    @pyqtSignature( "" )
    def btnResetLxdmSettingsClicked( self ):
        self.blockSignals( True )
        orig_rec = load_distro_record()
        self.distro.lxdm_settings = orig_rec.lxdm_settings
        self.configurePushButtons()
        self.populateLxdmPlaintextEditor()
        self.btnResetLxdmSettings.setEnabled( False )
        self.blockSignals( False )

    @pyqtSignature( "" )
    def populateLxdmPlaintextEditor( self ):
        outstr = ''
        for k in self.distro.lxdm_settings.keys():
            v = self.distro.lxdm_settings[k]
            w = v if type( v ) is str else str( v )
            outstr += '%s=%s\n' % ( k, w )
#        signals_are_already_blocked = self.signalsBlocked()
        self.pteLxdmSettings.setPlainText( outstr )

    @pyqtSignature( "" )
    def saveLxdmSettingsToMyDistroRecord( self ):
        dct = {}
        for this_line in self.pteLxdmSettings.toPlainText().split( '\n' ):
            try:
                lst = this_line.split( '=' )
                k = lst[0]
                v = lst[1]
            except:
                continue
            if v == 'False':
                w = False
            elif v == 'True':
                w = True
            else:
                try:
                    w = int( v )
                except:
                    w = v
            dct[k] = w
        self.distro.lxdm_settings = dct
        self.populateLxdmPlaintextEditor()
        self.btnResetLxdmSettings.setEnabled( False )

    @pyqtSignature( "" )
    def changeWhitelist( self ):
        orig_txt = self.whitelist_menu_text()
        res = self.flip_whitelist_setting()
        self.actionWhitelist.setText( self.whitelist_menu_text() )
        if res != 0:
            QtGui.QMessageBox.question( self, "Failure", orig_txt + " failed.", QtGui.QMessageBox.Ok )
        else:
            QtGui.QMessageBox.question( self, "Success!", orig_txt + " succeeded.", QtGui.QMessageBox.Ok )

    @pyqtSignature( "" )
    def changeBoomPassword( self ):
        old_password_cksum = self.boom_pw_checksum()
        pwd_dlg = ChangePasswordDialog( title = "Boom Password", cksum = old_password_cksum )
        cksum = pwd_dlg.cksum()
        if cksum is not None:
            self.distro.boom_password = pwd_dlg.password  # _password ?
#            if res != 0:
#                QtGui.QMessageBox.question( self, "Failure", "Boom password remains the same.", QtGui.QMessageBox.Ok )
#            else:
#                QtGui.QMessageBox.question( self, "Success!", "Boom password has been changed.", QtGui.QMessageBox.Ok )

    @pyqtSignature( "" )
    def changeDiskPassword( self ):
        res = self.distro.set_disk_password()  # mountpoint
        if res != 0:
            QtGui.QMessageBox.question( self, "Failure", "Disk password remains the same.", QtGui.QMessageBox.Ok )
        else:
            QtGui.QMessageBox.question( self, "Success!", "Disk password has been changed.", QtGui.QMessageBox.Ok )

    @pyqtSignature( "" )
    def changeRootPassword( self ):
        res = self.distro.set_root_password()  # mountpoint
        if res != 0:
            QtGui.QMessageBox.question( self, "Failure", "Root password remains the same.", QtGui.QMessageBox.Ok )
        else:
            QtGui.QMessageBox.question( self, "Success!", "Root password has been changed.", QtGui.QMessageBox.Ok )

    @pyqtSignature( "" )
    def clearTaskList( self ):
        if self.lstTasks.count() > 0:
            self.lstTasks.clear()

    @pyqtSignature( "" )
    def executeTaskList( self ):
        if self.lstTasks.count() > 0:
            reply = QtGui.QMessageBox.question( self, "Reboot & Run", "Ready to reboot and\nreconfigure me?", QtGui.QMessageBox.Yes, QtGui.QMessageBox.No )
            if reply == QtGui.QMessageBox.Yes:
                os.system( "sudo reboot" )
                sys.exit()

    @pyqtSignature( "" )
    def closeEvent( self, event ):
        if not self.changes_made:
            sys.exit( 0 )
        else:
            reply = QtGui.QMessageBox.question( self, "Quit?", "Are you sure to quit?", QtGui.QMessageBox.Yes, QtGui.QMessageBox.No )
            if reply == QtGui.QMessageBox.Yes:
                save_distro_record( self.distro )
                event.accept()
                sys.exit( 0 )
            else:
                event.ignore()

class ReconfigureorexitDialog( QtGui.QDialog, Ui_dlgReconfigureorexit ):
    def __init__( self ):
        super( ReconfigureorexitDialog, self ).__init__()
        uic.loadUi( "ui/ReconfigureorexitForm.ui", self )
        # btnReconfigure, btnExit
        self.connect( self.btnReconfigure, SIGNAL( "clicked()" ), self.reconfigurePushed )
        self.connect( self.btnExit, SIGNAL( "clicked()" ), SLOT( "close()" ) )
#        self.connect(self, SIGNAL("quit()"), self.exitPushed) # SLOT("close()"))
        self.show()

    @pyqtSignature( "" )
    def closeEvent( self, event ):
        if self.distro.rebuild_required:
            prompt = "I must rebuild the kernel and reboot the computer.\nAre you ready for me to do both those things?"
            reply = QtGui.QMessageBox.question( self, "", prompt, QtGui.QMessageBox.Yes, QtGui.QMessageBox.No )
            if 0 == os.system( 'mount | fgrep %s &>/dev/null' % ( self.crypto_rootdev ) ):
                res = self.distro.redo_kernel_for_encrypted_root( self.root_dev. self.mountpoint )
            else:
                res = self.distro.redo_kernel_for_plain_root( self.root_dev. self.mountpoint )
            if res != 0:
                QtGui.QMessageBox.question( self, "Failure", "I failed to rebuild the kernel.", QtGui.QMessageBox.Ok )
            event.accept()
            sys.exit()
        else:
            prompt = "Are you sure to quit?"
            reply = QtGui.QMessageBox.question( self, "", prompt, QtGui.QMessageBox.Yes, QtGui.QMessageBox.No )
            if reply == QtGui.QMessageBox.Yes:
                event.accept()
                sys.exit()
            else:
                event.ignore()

    @pyqtSignature( "" )
    def reconfigurePushed( self ):
        reply = QtGui.QMessageBox.question( self, "Reconfigure", "Are you sure you want to reboot and reconfigure Chrubix?", QtGui.QMessageBox.Yes, QtGui.QMessageBox.No )
        if reply == QtGui.QMessageBox.Yes:
            os.system( "sudo reboot" )
            sys.exit()


if __name__ == "__main__":
    app = QtGui.QApplication( sys.argv )
    window = MainWindow()
    window.show()
    window.raise_()
#    if os.system("mount | grep -i crypt") == 0:
#        dlg = ReconfigureorexitDialog()
    sys.exit( app.exec_() )


