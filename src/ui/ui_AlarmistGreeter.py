# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/AlarmistGreeter.ui'
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

class Ui_dlgAlarmistGreeter(object):
    def setupUi(self, dlgAlarmistGreeter):
        dlgAlarmistGreeter.setObjectName(_fromUtf8("dlgAlarmistGreeter"))
        dlgAlarmistGreeter.setWindowModality(QtCore.Qt.WindowModal)
        dlgAlarmistGreeter.resize(313, 268)
        sizePolicy = QtGui.QSizePolicy(QtGui.QSizePolicy.Preferred, QtGui.QSizePolicy.MinimumExpanding)
        sizePolicy.setHorizontalStretch(0)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(dlgAlarmistGreeter.sizePolicy().hasHeightForWidth())
        dlgAlarmistGreeter.setSizePolicy(sizePolicy)
        dlgAlarmistGreeter.setMaximumSize(QtCore.QSize(16777215, 16777215))
        dlgAlarmistGreeter.setWindowOpacity(1.0)
        dlgAlarmistGreeter.setAutoFillBackground(False)
        self.frame1 = QtGui.QFrame(dlgAlarmistGreeter)
        self.frame1.setGeometry(QtCore.QRect(10, 10, 291, 251))
        self.frame1.setFrameShape(QtGui.QFrame.StyledPanel)
        self.frame1.setFrameShadow(QtGui.QFrame.Raised)
        self.frame1.setObjectName(_fromUtf8("frame1"))
        self.label = QtGui.QLabel(self.frame1)
        self.label.setGeometry(QtCore.QRect(0, 10, 291, 111))
        font = QtGui.QFont()
        font.setFamily(_fromUtf8("Garamond"))
        font.setPointSize(24)
        font.setBold(True)
        font.setWeight(75)
        self.label.setFont(font)
        self.label.setAlignment(QtCore.Qt.AlignHCenter|QtCore.Qt.AlignTop)
        self.label.setObjectName(_fromUtf8("label"))
        self.btnMoreoptions = QtGui.QPushButton(self.frame1)
        self.btnMoreoptions.setGeometry(QtCore.QRect(0, 210, 141, 41))
        self.btnMoreoptions.setToolTip(_fromUtf8(""))
        self.btnMoreoptions.setObjectName(_fromUtf8("btnMoreoptions"))
        self.btnContinue = QtGui.QPushButton(self.frame1)
        self.btnContinue.setGeometry(QtCore.QRect(150, 210, 141, 41))
        self.btnContinue.setDefault(True)
        self.btnContinue.setObjectName(_fromUtf8("btnContinue"))
        self.lblEyes = QtGui.QLabel(self.frame1)
        self.lblEyes.setGeometry(QtCore.QRect(0, 0, 301, 251))
        self.lblEyes.setText(_fromUtf8(""))
        self.lblEyes.setPixmap(QtGui.QPixmap(_fromUtf8("scary-eyes-tattoo-on-arm.jpg")))
        self.lblEyes.setScaledContents(True)
        self.lblEyes.setObjectName(_fromUtf8("lblEyes"))
        self.frame2 = QtGui.QFrame(dlgAlarmistGreeter)
        self.frame2.setGeometry(QtCore.QRect(10, 330, 291, 61))
        self.frame2.setFrameShape(QtGui.QFrame.StyledPanel)
        self.frame2.setFrameShadow(QtGui.QFrame.Raised)
        self.frame2.setObjectName(_fromUtf8("frame2"))
        self.radSpoofYes = QtGui.QRadioButton(self.frame2)
        self.radSpoofYes.setGeometry(QtCore.QRect(230, 10, 51, 20))
        self.radSpoofYes.setObjectName(_fromUtf8("radSpoofYes"))
        self.radSpoofNo = QtGui.QRadioButton(self.frame2)
        self.radSpoofNo.setGeometry(QtCore.QRect(230, 30, 51, 20))
        self.radSpoofNo.setChecked(True)
        self.radSpoofNo.setObjectName(_fromUtf8("radSpoofNo"))
        self.label_3 = QtGui.QLabel(self.frame2)
        self.label_3.setGeometry(QtCore.QRect(20, 10, 201, 41))
        self.label_3.setWordWrap(True)
        self.label_3.setObjectName(_fromUtf8("label_3"))
        self.frame3 = QtGui.QFrame(dlgAlarmistGreeter)
        self.frame3.setGeometry(QtCore.QRect(10, 450, 291, 71))
        self.frame3.setFrameShape(QtGui.QFrame.StyledPanel)
        self.frame3.setFrameShadow(QtGui.QFrame.Raised)
        self.frame3.setObjectName(_fromUtf8("frame3"))
        self.chkAllowrootpassword = QtGui.QCheckBox(self.frame3)
        self.chkAllowrootpassword.setGeometry(QtCore.QRect(10, 10, 81, 51))
        self.chkAllowrootpassword.setObjectName(_fromUtf8("chkAllowrootpassword"))
        self.ledPassword1 = QtGui.QLineEdit(self.frame3)
        self.ledPassword1.setGeometry(QtCore.QRect(80, 10, 201, 21))
        self.ledPassword1.setEchoMode(QtGui.QLineEdit.Password)
        self.ledPassword1.setObjectName(_fromUtf8("ledPassword1"))
        self.ledPassword2 = QtGui.QLineEdit(self.frame3)
        self.ledPassword2.setGeometry(QtCore.QRect(80, 40, 201, 21))
        self.ledPassword2.setEchoMode(QtGui.QLineEdit.Password)
        self.ledPassword2.setObjectName(_fromUtf8("ledPassword2"))
        self.frame4 = QtGui.QFrame(dlgAlarmistGreeter)
        self.frame4.setGeometry(QtCore.QRect(10, 270, 291, 61))
        self.frame4.setFrameShape(QtGui.QFrame.StyledPanel)
        self.frame4.setFrameShadow(QtGui.QFrame.Raised)
        self.frame4.setObjectName(_fromUtf8("frame4"))
        self.label_5 = QtGui.QLabel(self.frame4)
        self.label_5.setGeometry(QtCore.QRect(20, 10, 201, 41))
        self.label_5.setWordWrap(True)
        self.label_5.setObjectName(_fromUtf8("label_5"))
        self.radCamouflageNo = QtGui.QRadioButton(self.frame4)
        self.radCamouflageNo.setGeometry(QtCore.QRect(230, 30, 51, 20))
        self.radCamouflageNo.setChecked(True)
        self.radCamouflageNo.setObjectName(_fromUtf8("radCamouflageNo"))
        self.radCamouflageYes = QtGui.QRadioButton(self.frame4)
        self.radCamouflageYes.setGeometry(QtCore.QRect(230, 10, 51, 20))
        self.radCamouflageYes.setObjectName(_fromUtf8("radCamouflageYes"))
        self.frame5 = QtGui.QFrame(dlgAlarmistGreeter)
        self.frame5.setGeometry(QtCore.QRect(10, 390, 291, 61))
        self.frame5.setFrameShape(QtGui.QFrame.StyledPanel)
        self.frame5.setFrameShadow(QtGui.QFrame.Raised)
        self.frame5.setObjectName(_fromUtf8("frame5"))
        self.label_6 = QtGui.QLabel(self.frame5)
        self.label_6.setGeometry(QtCore.QRect(20, 10, 201, 41))
        self.label_6.setWordWrap(True)
        self.label_6.setObjectName(_fromUtf8("label_6"))
        self.radDirectNo = QtGui.QRadioButton(self.frame5)
        self.radDirectNo.setGeometry(QtCore.QRect(230, 30, 51, 20))
        self.radDirectNo.setChecked(False)
        self.radDirectNo.setObjectName(_fromUtf8("radDirectNo"))
        self.radDirectYes = QtGui.QRadioButton(self.frame5)
        self.radDirectYes.setGeometry(QtCore.QRect(230, 10, 51, 20))
        self.radDirectYes.setChecked(True)
        self.radDirectYes.setObjectName(_fromUtf8("radDirectYes"))

        self.retranslateUi(dlgAlarmistGreeter)
        QtCore.QMetaObject.connectSlotsByName(dlgAlarmistGreeter)
        dlgAlarmistGreeter.setTabOrder(self.btnMoreoptions, self.btnContinue)
        dlgAlarmistGreeter.setTabOrder(self.btnContinue, self.radCamouflageYes)
        dlgAlarmistGreeter.setTabOrder(self.radCamouflageYes, self.radCamouflageNo)
        dlgAlarmistGreeter.setTabOrder(self.radCamouflageNo, self.chkAllowrootpassword)
        dlgAlarmistGreeter.setTabOrder(self.chkAllowrootpassword, self.ledPassword1)
        dlgAlarmistGreeter.setTabOrder(self.ledPassword1, self.ledPassword2)
        dlgAlarmistGreeter.setTabOrder(self.ledPassword2, self.radSpoofYes)
        dlgAlarmistGreeter.setTabOrder(self.radSpoofYes, self.radSpoofNo)
        dlgAlarmistGreeter.setTabOrder(self.radSpoofNo, self.radDirectYes)
        dlgAlarmistGreeter.setTabOrder(self.radDirectYes, self.radDirectNo)

    def retranslateUi(self, dlgAlarmistGreeter):
        dlgAlarmistGreeter.setWindowTitle(_translate("dlgAlarmistGreeter", "Greeter", None))
        self.label.setText(_translate("dlgAlarmistGreeter", "W E L C O M E", None))
        self.btnMoreoptions.setText(_translate("dlgAlarmistGreeter", "More Options", None))
        self.btnContinue.setToolTip(_translate("dlgAlarmistGreeter", "Click here to boot", None))
        self.btnContinue.setText(_translate("dlgAlarmistGreeter", "Continue", None))
        self.radSpoofYes.setText(_translate("dlgAlarmistGreeter", "Yes", None))
        self.radSpoofNo.setText(_translate("dlgAlarmistGreeter", "No", None))
        self.label_3.setToolTip(_translate("dlgAlarmistGreeter", "Spoofing MAC addresses hides the serial number of your network cards\n"
"to the local network. This can help you hide your geographical location.\n"
"\n"
"It is generally safer to spoof MAC addresses, but it might\n"
"also raise suspicions or cause network connection problems.", None))
        self.label_3.setText(_translate("dlgAlarmistGreeter", "Spoof your MAC address?", None))
        self.chkAllowrootpassword.setToolTip(_translate("dlgAlarmistGreeter", "You have the option of entering an administration password in case you need to perform\n"
"administrative tasks. If you choose not to, it will be disabled for better security.", None))
        self.chkAllowrootpassword.setText(_translate("dlgAlarmistGreeter", "Allow\n"
"root\n"
"pwd", None))
        self.label_5.setToolTip(_translate("dlgAlarmistGreeter", "This option makes Alarmist look more like Microsoft Windows XP. This\n"
"may be ueful in public places in order to avoid attracting suspicion.", None))
        self.label_5.setText(_translate("dlgAlarmistGreeter", "Camouflage as Windows?", None))
        self.radCamouflageNo.setText(_translate("dlgAlarmistGreeter", "No", None))
        self.radCamouflageYes.setText(_translate("dlgAlarmistGreeter", "Yes", None))
        self.label_6.setToolTip(_translate("dlgAlarmistGreeter", "Is your network connection clear of obstacles? If so, and you would like\n"
"to connect directly to the Tor network, say (Y)es. On the other hand, If\n"
"your computer\'s network connection is censored, filtered, or proxied, say\n"
"(N)o and configure your bridge, firewall, and proxy settings manually.", None))
        self.label_6.setText(_translate("dlgAlarmistGreeter", "Direct connect to Network?", None))
        self.radDirectNo.setText(_translate("dlgAlarmistGreeter", "No", None))
        self.radDirectYes.setText(_translate("dlgAlarmistGreeter", "Yes", None))

