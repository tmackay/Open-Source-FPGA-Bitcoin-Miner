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

* Since the links are asynchronous, the hardware can be somewhat
  heterogeneous. For example, the hub FPGA could host one miner, and
  other miners could be external.

Caveats
-------

* Hubs can be daisy chained, but overall the system may not scale too
  well, because the serial port is rather slow.

* The number of miners should be a power of two. Otherwise, when the
  nonce overflows, it will start from a different initial value. Over
  time, as different miners drift in frequency, and have different
  start times, the nonce ranges start to overlap. So this is not a
  problem for single-chip clusters, they could use any number.

* Miners should probably run at roughly the same hashrate, to cover
  the nonce space evenly.


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

So far, I am only getting results from one of the two miners. Which
one it is, seems to very from build to build...
