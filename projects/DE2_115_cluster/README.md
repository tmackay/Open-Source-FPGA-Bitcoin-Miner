FPGA mining cluster
-------------------

by teknohog

An attempt to build a cluster of FPGA miners, using my serial-port
version. It uses a single serial port at the computer.


Design
------

* Each miner is basically like one of my serial miners, communicating
  through a serial port (possibly low voltage levels, instead of
  RS232).

* All miners work on the same data, with different nonce ranges. Two
  miners would start nonces at 0 and 1, and increment by 2.

* The hub relays work data to each miner, and collects results for
  returning to miner.py. If miners return work very close to each
  other, the hub will cache results and send one at a time.
 
* miner.py is exactly the same as for a single miner.


Caveats
-------

* Hubs can be daisy chained, but overall the system may not scale too
  well, because the serial port is rather slow.

* The number of miners should be a power of two. Otherwise, when the
  nonce overflows, it will start from a different initial value. Over
  time, as different miners drift in frequency, and have different
  start times, the nonce ranges start to overlap. So this is not a
  problem for single-chip clusters.

* Miners should probably run at the same hashrate, to cover the nonce
  space evenly.


Current implementation
----------------------

Testing this on a single DE2-115, with one hub and two miners. I do
not have enough hardware for a real cluster, but this could be useful
even on a single huge FPGA.

This should work on Xilinx systems too, by changing the PLL code to a
DCM, for example from my Verilog Xilinx miner.

To build the code, download and unzip

http://www.fpga4fun.com/files/async.zip

Change the clock frequency in both async_* files to match the hash
clock. Proceed building the project fpgaminer as usual.


Current problems
----------------

So far, I am only getting results from one of the two miners,
depending on the kind of mux used for collecting results:

* For the primitive "and" mux (commented out), only odd numbers

* For the properly caching mux, only even numbers

From the schematic view, my mux logic looks symmetric in each case, so
this may be a more subtle error, such as a timing issue...