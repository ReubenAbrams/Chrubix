#!/usr/local/bin/python3
#
# battstat.py
# Show battery/mains status on taskbar (in tray)
#

import sys
import os
# import hashlib
from chrubix.utils import call_binary, process_power_status_info

try:
    from PyQt4.QtCore import QString
except ImportError:
    QString = str


TIME_BETWEEN_CHECKS = 1000

from PyQt4.QtCore import pyqtSignature, Qt, QTimer
# from PyQt4.Qt import QLineEdit, QPixmap, QSystemTrayIcon
from PyQt4 import QtGui
# from PyQt4 import QtCore#
# import resources_rc
from ui.ui_BatteryStatus import Ui_BatteryStatusWidget

# from testvol import VolumeControlWidget

class BatteryStatusWidget( QtGui.QDialog, Ui_BatteryStatusWidget ):
    def __init__( self ):
        u_power_e = call_binary( ['upower', '-e'] )[1].decode( 'utf-8' ).split( '\n' )
        self.battery_path = [ r for r in u_power_e if r.find( 'battery' ) >= 0][0]
        self.mains_path = [ r for r in u_power_e if r.find( 'charger' ) >= 0][0]

        super( BatteryStatusWidget, self ).__init__()
        self.setupUi( self )
        self.last_message = ''
        self.setWindowFlags( self.windowFlags() | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint )
        self.hide()
        self.setAttribute( Qt.WA_ShowWithoutActivating )
        QTimer.singleShot( TIME_BETWEEN_CHECKS, self.monitor )

    def monitor( self ):
        self.hide()
        battery_result = call_binary( ['upower', '-i', self.battery_path] )[1].decode( 'utf-8' )
        charger_result = call_binary( ['upower', '-i', self.mains_path] )[1].decode( 'utf-8' )
        power_status_dct = process_power_status_info( battery_result, charger_result )
        msg = power_status_dct['summary']
        if msg != self.last_message:
            self.show()
            self.raise_()
            os.system( 'notify-send "Battery %s" "%s"' % ( power_status_dct['status'], msg ) )
            QtGui.QStatusBar.showMessage( msg )
            self.textBrowserBatty.setText( battery_result )
            self.textBrowserMains.setText( charger_result )
        QTimer.singleShot( TIME_BETWEEN_CHECKS, self.monitor )

    @pyqtSignature( "" )
    def closeEvent( self, event ):
        event.accept()
        sys.exit()


if __name__ == "__main__":
    app = QtGui.QApplication( sys.argv )
    window = BatteryStatusWidget()
#    screen = QtGui.QDesktopWidget().screenGeometry()
#    window.setGeometry( screen.width() - window.width() - 1, screen.height() - 1, window.width(), window.height() )
    sys.exit( app.exec_() )


