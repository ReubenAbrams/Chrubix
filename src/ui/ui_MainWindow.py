# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/MainWindow.ui'
#
# Created: Wed May 28 21:42:59 2014
#      by: PyQt4 UI code generator 4.10.4
#
# WARNING! All changes made in this file will be lost!

from PyQt4 import QtCore, QtGui

try:
    _fromUtf8 = QtCore.QString.fromUtf8
except AttributeError:
    def _fromUtf8(s):
        return s

try:
    _encoding = QtGui.QApplication.UnicodeUTF8
    def _translate(context, text, disambig):
        return QtGui.QApplication.translate(context, text, disambig, _encoding)
except AttributeError:
    def _translate(context, text, disambig):
        return QtGui.QApplication.translate(context, text, disambig)

class Ui_mnwMain(object):
    def setupUi(self, mnwMain):
        mnwMain.setObjectName(_fromUtf8("mnwMain"))
        mnwMain.setEnabled(True)
        mnwMain.resize(675, 455)
        mnwMain.setFocusPolicy(QtCore.Qt.NoFocus)
        mnwMain.setUnifiedTitleAndToolBarOnMac(True)
        self.centralwidget = QtGui.QWidget(mnwMain)
        self.centralwidget.setObjectName(_fromUtf8("centralwidget"))
        self.lstTasks = QtGui.QListWidget(self.centralwidget)
        self.lstTasks.setGeometry(QtCore.QRect(10, 61, 256, 141))
        self.lstTasks.setObjectName(_fromUtf8("lstTasks"))
        self.btnClear = QtGui.QPushButton(self.centralwidget)
        self.btnClear.setGeometry(QtCore.QRect(10, 210, 114, 32))
        self.btnClear.setObjectName(_fromUtf8("btnClear"))
        self.btnExecute = QtGui.QPushButton(self.centralwidget)
        self.btnExecute.setGeometry(QtCore.QRect(160, 210, 114, 32))
        self.btnExecute.setObjectName(_fromUtf8("btnExecute"))
        self.label = QtGui.QLabel(self.centralwidget)
        self.label.setGeometry(QtCore.QRect(10, 40, 261, 16))
        self.label.setAlignment(QtCore.Qt.AlignCenter)
        self.label.setObjectName(_fromUtf8("label"))
        mnwMain.setCentralWidget(self.centralwidget)
        self.menubar = QtGui.QMenuBar(mnwMain)
        self.menubar.setEnabled(True)
        self.menubar.setGeometry(QtCore.QRect(0, 0, 675, 22))
        self.menubar.setObjectName(_fromUtf8("menubar"))
        self.menuFile = QtGui.QMenu(self.menubar)
        self.menuFile.setObjectName(_fromUtf8("menuFile"))
        self.menuEdit = QtGui.QMenu(self.menubar)
        self.menuEdit.setObjectName(_fromUtf8("menuEdit"))
        self.menuSettings = QtGui.QMenu(self.menubar)
        self.menuSettings.setObjectName(_fromUtf8("menuSettings"))
        self.menuChange_Password = QtGui.QMenu(self.menuSettings)
        self.menuChange_Password.setEnabled(True)
        self.menuChange_Password.setObjectName(_fromUtf8("menuChange_Password"))
        self.menuHelp = QtGui.QMenu(self.menubar)
        self.menuHelp.setObjectName(_fromUtf8("menuHelp"))
        mnwMain.setMenuBar(self.menubar)
        self.statusbar = QtGui.QStatusBar(mnwMain)
        self.statusbar.setFocusPolicy(QtCore.Qt.WheelFocus)
        self.statusbar.setObjectName(_fromUtf8("statusbar"))
        mnwMain.setStatusBar(self.statusbar)
        self.actionExit = QtGui.QAction(mnwMain)
        self.actionExit.setObjectName(_fromUtf8("actionExit"))
        self.actionChangePwDisk = QtGui.QAction(mnwMain)
        self.actionChangePwDisk.setObjectName(_fromUtf8("actionChangePwDisk"))
        self.actionChangePwRoot = QtGui.QAction(mnwMain)
        self.actionChangePwRoot.setObjectName(_fromUtf8("actionChangePwRoot"))
        self.actionChangePwBoom = QtGui.QAction(mnwMain)
        self.actionChangePwBoom.setObjectName(_fromUtf8("actionChangePwBoom"))
        self.actionDecrypt = QtGui.QAction(mnwMain)
        self.actionDecrypt.setObjectName(_fromUtf8("actionDecrypt"))
        self.actionWhitelist_ON = QtGui.QAction(mnwMain)
        self.actionWhitelist_ON.setObjectName(_fromUtf8("actionWhitelist_ON"))
        self.actionEncryption = QtGui.QAction(mnwMain)
        self.actionEncryption.setObjectName(_fromUtf8("actionEncryption"))
        self.actionWhitelist = QtGui.QAction(mnwMain)
        self.actionWhitelist.setCheckable(False)
        self.actionWhitelist.setObjectName(_fromUtf8("actionWhitelist"))
        self.actionObfuscation = QtGui.QAction(mnwMain)
        self.actionObfuscation.setObjectName(_fromUtf8("actionObfuscation"))
        self.menuFile.addAction(self.actionExit)
        self.menuChange_Password.addAction(self.actionChangePwDisk)
        self.menuChange_Password.addAction(self.actionChangePwRoot)
        self.menuChange_Password.addAction(self.actionChangePwBoom)
        self.menuSettings.addAction(self.menuChange_Password.menuAction())
        self.menuSettings.addAction(self.actionEncryption)
        self.menuSettings.addAction(self.actionWhitelist)
        self.menuSettings.addAction(self.actionObfuscation)
        self.menubar.addAction(self.menuFile.menuAction())
        self.menubar.addAction(self.menuEdit.menuAction())
        self.menubar.addAction(self.menuSettings.menuAction())
        self.menubar.addAction(self.menuHelp.menuAction())

        self.retranslateUi(mnwMain)
        QtCore.QMetaObject.connectSlotsByName(mnwMain)

    def retranslateUi(self, mnwMain):
        mnwMain.setWindowTitle(_translate("mnwMain", "Chrubix", None))
        self.btnClear.setText(_translate("mnwMain", "Clear List", None))
        self.btnExecute.setText(_translate("mnwMain", "Execute", None))
        self.label.setText(_translate("mnwMain", "Changes that require a reboot", None))
        self.menuFile.setTitle(_translate("mnwMain", "&File", None))
        self.menuEdit.setTitle(_translate("mnwMain", "&Edit", None))
        self.menuSettings.setTitle(_translate("mnwMain", "&Settings", None))
        self.menuChange_Password.setTitle(_translate("mnwMain", "Change Passwords", None))
        self.menuHelp.setTitle(_translate("mnwMain", "&Help", None))
        self.actionExit.setText(_translate("mnwMain", "Exit", None))
        self.actionChangePwDisk.setText(_translate("mnwMain", "Disk", None))
        self.actionChangePwRoot.setText(_translate("mnwMain", "Root", None))
        self.actionChangePwBoom.setText(_translate("mnwMain", "Boom", None))
        self.actionDecrypt.setText(_translate("mnwMain", "Decrypt Disk", None))
        self.actionWhitelist_ON.setText(_translate("mnwMain", "Create Whitelist", None))
        self.actionEncryption.setText(_translate("mnwMain", "Decrypt Root Partition", None))
        self.actionWhitelist.setText(_translate("mnwMain", "Whitelist", None))
        self.actionObfuscation.setText(_translate("mnwMain", "Obfuscate Filesystem", None))

import resources_rc
