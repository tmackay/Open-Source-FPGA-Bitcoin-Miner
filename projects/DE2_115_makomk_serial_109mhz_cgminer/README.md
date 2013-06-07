DE2-115 Bitcoin miner for cgminer
---------------------------------

by teknohog

This is a version of ../DE2_115_makomk_serial that works with
cgminer. It is already configured at the full 109 MHz, so unless you
like fried FPGAs for breakfast, USE A HEATSINK!

Bitstreams for two different pinouts are included here:

de2_115_cgminer.rs232.sof -- regular serial port

de2_115_cgminer.ttlserial.sof -- TTL level serial at pins 3 and 5 in
the small ribbon connector


Mining
------

In cgminer, this device is detected as an Icarus (since Icarus was
based on my serial cluster code). I have it working with cgminer 3.1.1
with these options:

--icarus-options 115200:1:1 --icarus-timing 9.1743 -S /dev/ttyUSB0

In fact, this project is not limited to cgminer. It implements the
Icarus v3 protocol, so presumably any compatible mining software could
be used with the appropriate settings (timing and work division).

http://en.qi-hardware.com/wiki/Icarus#Communication_protocol_V3
