FPGA mining cluster
-------------------

by teknohog

An experiment to build a cluster of FPGA miners, using my serial-port
version of the miner. It uses a single serial port at the computer.


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


Scaling
-------

Hubs can be daisy chained for big clusters. The serial port can handle
about 2880 results/s, corresponding to a limit of about 12 Thash/s for
one cluster. Even with tight bursts of results, the caching in hubs
should help avoid lost results (though only one result per input port
is cached). Nevertheless, real-world scaling remains to be seen.


Caveats
-------

* The number of miners should be a power of two. Otherwise, when the
  nonce overflows, it will start from a different initial value. Over
  time, as different miners drift in frequency, and have different
  start times, the nonce ranges start to overlap. So this is not a
  problem for single-chip clusters, they could use any number.

* Miners should probably run at roughly the same hashrate, to cover
  the nonce space evenly.


Use cases (besides clustering)
------------------------------

* A huge FPGA that can fit several fully unrolled miners

* A moderately sized FPGA that can fit, say, 1.5 full miners. You
  could then fit 3 half-miners to fully utilize the silicon. However,
  the serial communication has considerable overhead per miner.


Current implementation
----------------------

This has been succesfully tested on a single DE2-115, with one hub and
two miners. I do not have enough hardware for a proper cluster at the
moment.

This should work on Xilinx systems too, by changing the PLL code to a
DCM, for example from my Verilog Xilinx miner. Feel free to mix
vendors in a cluster, as long as signal levels match.

To build the code, download and unzip

http://www.fpga4fun.com/files/async.zip

Change the clock frequency in both async_* files to match the hash
clock. Proceed building the project fpgaminer as usual.

