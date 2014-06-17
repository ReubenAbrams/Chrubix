# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/MainWindow.ui'
#
# Created: Tue Jun 17 04:39:06 2014
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
        self.lstTasks.setGeometry(QtCore.QRect(360, 140, 256, 141))
        self.lstTasks.setObjectName(_fromUtf8("lstTasks"))
        self.btnClear = QtGui.QPushButton(self.centralwidget)
        self.btnClear.setGeometry(QtCore.QRect(360, 310, 114, 32))
        self.btnClear.setObjectName(_fromUtf8("btnClear"))
        self.btnExecute = QtGui.QPushButton(self.centralwidget)
        self.btnExecute.setGeometry(QtCore.QRect(490, 310, 114, 32))
        self.btnExecute.setObjectName(_fromUtf8("btnExecute"))
        self.label = QtGui.QLabel(self.centralwidget)
        self.label.setGeometry(QtCore.QRect(370, 110, 261, 16))
        self.label.setAlignment(QtCore.Qt.AlignCenter)
        self.label.setObjectName(_fromUtf8("label"))
        self.label_2 = QtGui.QLabel(self.centralwidget)
        self.label_2.setGeometry(QtCore.QRect(30, 10, 111, 16))
        self.label_2.setObjectName(_fromUtf8("label_2"))
        self.pteLxdmSettings = QtGui.QPlainTextEdit(self.centralwidget)
        self.pteLxdmSettings.setGeometry(QtCore.QRect(30, 40, 311, 211))
        self.pteLxdmSettings.setObjectName(_fromUtf8("pteLxdmSettings"))
        self.btnSaveLxdmSettings = QtGui.QPushButton(self.centralwidget)
        self.btnSaveLxdmSettings.setEnabled(False)
        self.btnSaveLxdmSettings.setGeometry(QtCore.QRect(30, 260, 171, 32))
        self.btnSaveLxdmSettings.setObjectName(_fromUtf8("btnSaveLxdmSettings"))
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
        self.actionBoot_Settings = QtGui.QAction(mnwMain)
        self.actionBoot_Settings.setObjectName(_fromUtf8("actionBoot_Settings"))
        self.menuFile.addAction(self.actionExit)
        self.menuChange_Password.addAction(self.actionChangePwDisk)
        self.menuChange_Password.addAction(self.actionChangePwRoot)
        self.menuChange_Password.addAction(self.actionChangePwBoom)
        self.menuSettings.addAction(self.actionBoot_Settings)
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
        self.label_2.setText(_translate("mnwMain", "Greeter settings", None))
        self.pteLxdmSettings.setPlainText(_translate("mnwMain", "\n"
"", None))
        self.btnSaveLxdmSettings.setText(_translate("mnwMain", "Save LXDM Settings", None))
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
        self.actionWhitelist.setText(_translate("mnwMain", "Hardware Whitelist", None))
        self.actionObfuscation.setText(_translate("mnwMain", "Obfuscate Filesystem", None))
        self.actionBoot_Settings.setText(_translate("mnwMain", "Boot Settings", None))

import resources_rc
