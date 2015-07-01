Cross-platform NES emulator.

This is a work in progress; see the issues page for known issues.


Installation
------------

To build, you'll need to install the Retrio core library:

    git clone https://github.com/retrio/core
    haxelib dev retrio-core core

Other dependencies:

* OpenFL
* systools

Once retrio-core is installed, run `openfl test flash` to start the emulator.


Tests
-----

Retrio emulators include automated unit tests utilizing special testing ROMs. 
These can be executed with `./runtests`. Each test will run a specific test ROM, 
comparing a hash of the screen contents with what the screen should look like on 
success, until the screen stops changing or the success state is reached.

To add new tests, add the ROM to the assets/roms/test directory and add an entry 
in tests.xml. Run the test suite; because your new test doesn't have a success 
hash yet, its status will be inconclusive. Check the image that is generated in 
test_results for that test and, if it was successful, copy and paste the hash 
for your test from stdout into tests.xml.


Copyright
---------

Copyright 2015 Ben Morris.

This program is free software: you can redistribute it and/or modify it under 
the terms of the GNU General Public License as published by the Free Software 
Foundation, either version 3 of the License, or (at your option) any later 
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY 
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with 
this program.  If not, see <http://www.gnu.org/licenses/>.
