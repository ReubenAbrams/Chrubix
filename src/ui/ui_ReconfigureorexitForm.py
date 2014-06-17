# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/ReconfigureorexitForm.ui'
#
# Created: Tue Jun 17 04:39:07 2014
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

class Ui_dlgReconfigureorexit(object):
    def setupUi(self, dlgReconfigureorexit):
        dlgReconfigureorexit.setObjectName(_fromUtf8("dlgReconfigureorexit"))
        dlgReconfigureorexit.setWindowModality(QtCore.Qt.WindowModal)
        dlgReconfigureorexit.resize(160, 219)
        self.gridLayoutWidget = QtGui.QWidget(dlgReconfigureorexit)
        self.gridLayoutWidget.setGeometry(QtCore.QRect(0, 0, 161, 220))
        self.gridLayoutWidget.setObjectName(_fromUtf8("gridLayoutWidget"))
        self.gridLayout = QtGui.QGridLayout(self.gridLayoutWidget)
        self.gridLayout.setSizeConstraint(QtGui.QLayout.SetDefaultConstraint)
        self.gridLayout.setMargin(0)
        self.gridLayout.setObjectName(_fromUtf8("gridLayout"))
        self.label = QtGui.QLabel(self.gridLayoutWidget)
        self.label.setMaximumSize(QtCore.QSize(140, 140))
        self.label.setText(_fromUtf8(""))
        self.label.setPixmap(QtGui.QPixmap(_fromUtf8(":/chrubix1.png")))
        self.label.setScaledContents(True)
        self.label.setAlignment(QtCore.Qt.AlignCenter)
        self.label.setObjectName(_fromUtf8("label"))
        self.gridLayout.addWidget(self.label, 1, 0, 1, 1)
        self.btnExit = QtGui.QPushButton(self.gridLayoutWidget)
        self.btnExit.setDefault(True)
        self.btnExit.setObjectName(_fromUtf8("btnExit"))
        self.gridLayout.addWidget(self.btnExit, 3, 0, 1, 1)
        self.btnReconfigure = QtGui.QPushButton(self.gridLayoutWidget)
        self.btnReconfigure.setObjectName(_fromUtf8("btnReconfigure"))
        self.gridLayout.addWidget(self.btnReconfigure, 0, 0, 1, 1)

        self.retranslateUi(dlgReconfigureorexit)
        QtCore.QMetaObject.connectSlotsByName(dlgReconfigureorexit)

    def retranslateUi(self, dlgReconfigureorexit):
        dlgReconfigureorexit.setWindowTitle(_translate("dlgReconfigureorexit", "Chrubix", None))
        self.btnExit.setText(_translate("dlgReconfigureorexit", "Exit", None))
        self.btnReconfigure.setText(_translate("dlgReconfigureorexit", "Reconfigure", None))

import resources_rc
