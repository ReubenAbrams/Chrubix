#!/usr/local/bin/python3
#
# alarmist.py
#


from chrubix.distros.debian import WheezyDebianDistro
from chrubix.utils import disable_root_password


class AlarmistDistro( WheezyDebianDistro ):
    important_packages = WheezyDebianDistro.important_packages
    final_push_packages = WheezyDebianDistro.final_push_packages
    def __init__( self , *args, **kwargs ):
        super( AlarmistDistro, self ).__init__( *args, **kwargs )
        self.name = 'alarmist'
        # self.name remains 'wheezy' because... well, it's all so much simpler that way
        self.typical_install_duration = 18888

    def migrate_or_squash_OS( self ):
        disable_root_password( self.mountpoint )
        self.squash_OS()


