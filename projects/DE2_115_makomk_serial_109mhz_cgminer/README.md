This is a version of ../DE2_115_makomk_serial that works with
cgminer. It is already configured at the full 109 MHz, so unless you
like fried FPGAs for breakfast, USE A HEATSINK!

To build the code, download and unzip

http://www.fpga4fun.com/files/async.zip

Change the clock frequency in both async_* files to 109 MHz. Proceed
building the project fpgaminer as usual.

The fpgaminer.sof included here uses TTL level serial at pins 3 and 5
in the small ribbon connector. Comment/uncomment pins in fpgaminer.qsf
if you want the real RS232 port instead.

In cgminer, this device is detected as an Icarus (since Icarus was
based on my serial cluster code). I have it working with cgminer 3.1.1
with these options:

--icarus-options 115200:1:1 --icarus-timing 9.1743 -S /dev/ttyUSB0
