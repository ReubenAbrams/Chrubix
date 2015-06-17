#!/usr/local/bin/python3
#
# alarmist.py
#


from chrubix.distros.debian import WheezyDebianDistro
from chrubix.utils import failed


class AlarmistDistro( WheezyDebianDistro ):
    def __init__( self , *args, **kwargs ):
        super( AlarmistDistro, self ).__init__( *args, **kwargs )
        self.name = 'alarmist'
        failed( 'WE NO LONGER USE ALARMIST DISTRO' )
        # self.name remains 'wheezy' because... well, it's all so much simpler that way

