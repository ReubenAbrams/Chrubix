# Unit tests for Chrubix/src/chrubix/distros/*.py

import unittest
from chrubix import distros
from chrubix.utils import generate_temporary_filename
from chrubix.distros import Distro

#
# class SrcChrubixDistrosTest( unittest.TestCase ):
#
#     def test( self ):
#         self.assertTrue( True )
#
#
#     def testTheDistroClass( self ):
#         # Create a LinuxDistro instance
#         my_distro = Distro()
#         # Assume that it has no distro name yet
#         self.assertEqual( my_distro.distroname, 'UNKNOWN' )
#         # Try setting the distro name
#         my_distro.distroname = 'Something else'
#         self.assertEqual( my_distro.distroname, 'Something else' )
#         self.assertEqual( 1, 2 )
#         # Try setting & then getting a nonexistent attribute; it should fail, both times
#         s = generate_temporary_filename(); self.distroname = s; self.assertEqual( s, self.distroname )
#         s = generate_temporary_filename(); self.boomfname = s; self.assertEqual( s, self.boomfname )
#         s = generate_temporary_filename(); self.architecture = s; self.assertEqual( s, self.architecture )
#         s = generate_temporary_filename(); self.boot_prompt_string = s; self.assertEqual( s, self.boot_prompt_string )
#         s = generate_temporary_filename(); self.snowball = s; self.assertEqual( s, self.snowball )
#         s = generate_temporary_filename(); self.ryo_tempdir = s; self.assertEqual( s, self.ryo_tempdir )
#         s = generate_temporary_filename(); self.boom_pw_file = s; self.assertEqual( s, self.boom_pw_file )
#         s = generate_temporary_filename(); self.kernel_cksum_fname = s; self.assertEqual( s, self.kernel_cksum_fname )
#         s = generate_temporary_filename(); self.stop_jfs_hangsup = s; self.assertEqual( s, self.stop_jfs_hangsup )
#         s = generate_temporary_filename(); self.loglevel = s; self.assertEqual( s, self.loglevel )
#         s = generate_temporary_filename( '/dev' ); self.device = s; self.assertEqual( s, self.device )
#         s = generate_temporary_filename( '/dev' ); self.spare_dev = s; self.assertEqual( s, self.spare_dev )
#         s = generate_temporary_filename( '/dev' ); self.kernel_dev = s; self.assertEqual( s, self.kernel_dev )
#         s = generate_temporary_filename( '/dev' ); self.root_dev = s; self.assertEqual( s, self.root_dev )
#         s = generate_temporary_filename( '/tmp' ); self.tempdir = s; self.assertEqual( s, self.tempdir )
#         s = generate_temporary_filename( '/dev/mapper' ); self.crypto_rootdev = s; self.assertEqual( s, self.crypto_rootdev )
#         s = generate_temporary_filename( '/dev/mapper' ); self.crypto_homedev = s; self.assertEqual( s, self.crypto_homedev )
#         # Test if self.{device, spare_dev, kernel_dev, root_dev} reject /derp/
#         # Test if self.tmpdir rejects /terp/
#         # Test if self.{crypt*dev} reject /dev/moqqer/
#         s = generate_temporary_filename(); self.randomized_serial_number = s; self.assertEqual( s, self.randomized_serial_number )
#         s = generate_temporary_filename(); self.guest_homedir = s; self.assertEqual( s, self.guest_homedir )
#         self.kernel_rebuild_required = True; self.assertEqual( self.kernel_rebuild_required, True )
#         self.kernel_rebuild_required = False; self.assertEqual( self.kernel_rebuild_required, False )
#         self.pheasants = True; print( 'krr=%s' % ( str( self.kernel_rebuild_required, ) ) )
#         self.assertEqual( self.kernel_rebuild_required, True )
#         self.kernel_rebuild_required = False; self.assertEqual( self.kernel_rebuild_required, False )
#         self.kthx = True; self.kthx = False; self.assertEqual( self.kernel_rebuild_required, True )
#         self.kernel_rebuild_required = False; self.assertEqual( self.kernel_rebuild_required, False )
#         self.kthx = True; self.assertEqual( self.kernel_rebuild_required, True )
#         self.kernel_rebuild_required = False; self.assertEqual( self.kernel_rebuild_required, False )
#         self.pheasants = False; self.assertEqual( self.kernel_rebuild_required, True )
#         self.kernel_rebuild_required = False; self.assertEqual( self.kernel_rebuild_required, False )
#         self.kthx = False; self.assertEqual( self.kernel_rebuild_required, True )
#         self.kernel_rebuild_required = False; self.assertEqual( self.kernel_rebuild_required, False )
#         self.pheasants = True; self.assertEqual( self.kernel_rebuild_required, True )
#         self.pheasants = True;  self.assertEqual( self.pheasants, True )
#         self.pheasants = False; self.assertEqual( self.pheasants, False )
#         self.kthx = True;       self.assertEqual( self.kthx, True )
#         self.kthx = False;       self.assertEqual( self.kthx, False )
#
#
#
# if __name__ == '__main__':
#     unittest.main()
#
#
#
#
