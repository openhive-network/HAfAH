#!/usr/bin/env python3
import pexpect
import sys

def test_example( example_path ):
    print( "Test example {}".format( example_path ) )
    application = pexpect.spawn( example_path )
    application.logfile = sys.stdout.buffer
    application.expect( "Blocks range \(1, 8\)" )
    application.expect( "Blocks range \(2, 8\)" )
    application.expect( "Blocks range \(3, 8\)" )
    application.expect( "Blocks range \(4, 8\)" )
    application.expect( "Blocks range \(5, 8\)" )
    application.expect( "Blocks range \(7, 8\)" )
    application.expect( "Blocks range \(8, 8\)" )
    application.expect( "Blocks range \(None, None\)" )
    application.kill( 0 )

if __name__ == '__main__':
    test_example( sys.argv[ 1 ] + "/hive_non_fork_app.py" )