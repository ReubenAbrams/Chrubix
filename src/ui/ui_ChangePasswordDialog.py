# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/ChangePasswordDialog.ui'
#
# Created: Thu Jun 18 23:26:05 2015
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

class Ui_dlgChangepassword(object):
    def setupUi(self, dlgChangepassword):
        dlgChangepassword.setObjectName(_fromUtf8("dlgChangepassword"))
        dlgChangepassword.setWindowModality(QtCore.Qt.ApplicationModal)
        dlgChangepassword.resize(289, 166)
        dlgChangepassword.setModal(True)
        self.gridLayoutWidget = QtGui.QWidget(dlgChangepassword)
        self.gridLayoutWidget.setGeometry(QtCore.QRect(10, 0, 271, 158))
        self.gridLayoutWidget.setObjectName(_fromUtf8("gridLayoutWidget"))
        self.gridLayout = QtGui.QGridLayout(self.gridLayoutWidget)
        self.gridLayout.setMargin(0)
        self.gridLayout.setObjectName(_fromUtf8("gridLayout"))
        self.label = QtGui.QLabel(self.gridLayoutWidget)
        self.label.setObjectName(_fromUtf8("label"))
        self.gridLayout.addWidget(self.label, 1, 0, 1, 1)
        self.label_3 = QtGui.QLabel(self.gridLayoutWidget)
        self.label_3.setObjectName(_fromUtf8("label_3"))
        self.gridLayout.addWidget(self.label_3, 3, 0, 1, 1)
        self.label_2 = QtGui.QLabel(self.gridLayoutWidget)
        self.label_2.setObjectName(_fromUtf8("label_2"))
        self.gridLayout.addWidget(self.label_2, 2, 0, 1, 1)
        self.edlOldpass = QtGui.QLineEdit(self.gridLayoutWidget)
        self.edlOldpass.setInputMask(_fromUtf8(""))
        self.edlOldpass.setObjectName(_fromUtf8("edlOldpass"))
        self.gridLayout.addWidget(self.edlOldpass, 1, 1, 1, 1)
        self.edlNewpass2 = QtGui.QLineEdit(self.gridLayoutWidget)
        self.edlNewpass2.setInputMask(_fromUtf8(""))
        self.edlNewpass2.setObjectName(_fromUtf8("edlNewpass2"))
        self.gridLayout.addWidget(self.edlNewpass2, 3, 1, 1, 1)
        self.edlNewpass1 = QtGui.QLineEdit(self.gridLayoutWidget)
        self.edlNewpass1.setInputMask(_fromUtf8(""))
        self.edlNewpass1.setObjectName(_fromUtf8("edlNewpass1"))
        self.gridLayout.addWidget(self.edlNewpass1, 2, 1, 1, 1)
        self.buttonBox = QtGui.QDialogButtonBox(self.gridLayoutWidget)
        self.buttonBox.setOrientation(QtCore.Qt.Horizontal)
        self.buttonBox.setStandardButtons(QtGui.QDialogButtonBox.Cancel|QtGui.QDialogButtonBox.Ok)
        self.buttonBox.setObjectName(_fromUtf8("buttonBox"))
        self.gridLayout.addWidget(self.buttonBox, 6, 0, 1, 2)

        self.retranslateUi(dlgChangepassword)
        QtCore.QObject.connect(self.buttonBox, QtCore.SIGNAL(_fromUtf8("rejected()")), dlgChangepassword.reject)
        QtCore.QObject.connect(self.buttonBox, QtCore.SIGNAL(_fromUtf8("accepted()")), dlgChangepassword.accept)
        QtCore.QMetaObject.connectSlotsByName(dlgChangepassword)
        dlgChangepassword.setTabOrder(self.edlOldpass, self.edlNewpass1)
        dlgChangepassword.setTabOrder(self.edlNewpass1, self.edlNewpass2)
        dlgChangepassword.setTabOrder(self.edlNewpass2, self.buttonBox)

    def retranslateUi(self, dlgChangepassword):
        dlgChangepassword.setWindowTitle(_translate("dlgChangepassword", "Dialog", None))
        self.label.setText(_translate("dlgChangepassword", "Old Password", None))
        self.label_3.setText(_translate("dlgChangepassword", "Enter again", None))
        self.label_2.setText(_translate("dlgChangepassword", "New Password", None))

