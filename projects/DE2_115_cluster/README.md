FPGA mining cluster
-------------------

by teknohog

An experiment to build a cluster of FPGA miners, using my serial-port
version of the miner. It uses a single serial port at the computer.


Design
------

* Each miner is basically like one of my serial miners, communicating
  through a serial port (possibly low voltage levels, instead of
  RS232). (You can even use the miner as such to test a hub.)

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

* Hubs can be daisy chained for big clusters. The serial port can
  handle about 2880 results/s, corresponding to a limit of about 12
  Thash/s for one cluster. Even with tight bursts of results, the
  caching in hubs should help avoid lost results (though only one
  result per input port is cached). Nevertheless, real-world scaling
  remains to be seen.

* A hub does not care how many miners there are. The mux/cache code is
  only about the available ports.

* However, each miner must know the total number, as it equals the
  nonce stride. Each miner also needs a distinct nonce start. This
  means building a new .sof/.bit for each node, unless nonce_start
  could be set with a switch, for example.


Caveats
-------

* The number of miners should be a power of two. Otherwise, when the
  nonce overflows, it will start from a different initial value. Over
  time, as different miners drift in frequency, and have different
  start times, the nonce ranges start to overlap. So this is not a
  problem for single-chip clusters, they could use any number.

* Miners should probably run at roughly the same hashrate, to cover
  the nonce space evenly. But if you have very differently sized
  FPGAs, you could put several small miners on a big chip (with a hub)
  to make a collection of similarly powered hashers.


Use cases (besides clustering)
------------------------------

* A huge FPGA that can fit several fully unrolled miners

* A moderately sized FPGA that can fit, say, 1.5 full miners. You
  could then fit 3 half-miners to fully utilize the silicon. However,
  the serial communication has considerable overhead per miner.


Current implementation
----------------------

This has been succesfully tested on a DE2-115, with one hub and two
miners on a single FPGA. The hub code is so small that it generally
makes sense to integrate miners with it, which is how the current code
is designed. (Although you can set LOCAL_MINERS=0.)

This works on Xilinx systems too, by changing the PLL code to a
DCM, see ../Xilinx_cluster for an implementation.

Feel free to mix vendors in a cluster, as long as signal levels match.

To build the code, download and unzip

http://www.fpga4fun.com/files/async.zip

Change the clock frequency in both async_* files to match the hash
clock. Proceed building the project fpgaminer as usual.


Quick and dirty test setup
--------------------------

If you already have an FPGA with my serial miner, you can use it as a
slave for testing the hub. There will overlap in the nonce ranges, but
it saves the time of building new code, until the hub is verified to
work.

This setup has been verified to work with ../DE2_115_makomk_serial as
the vanilla miner, and the hub code on a Xilinx board (Nexys2 500K)
using the ../Xilinx_cluster project. The Nexys2 used real RS232 for
the computer uplink, and general I/O pins for the slave connection.


Planned features
----------------

* A single slave miner. This should be a very light wrapper around
  miner.v, to keep things modular. Vendor/board specific code
  (DCM/PLL, buttons etc.)  would reside in this wrapper. My original
  serial miner would then be a special case of this, with
  nonce_stride=1. -> done for Xilinx.

* A more dynamic scheme for the different nonce ranges. Currently this
  needs different bitfiles for each FPGA, with considerable
  synthesis-time configuration. For example, setting nonce_start and
  nonce_stride with switches would be nicer. This probably needs a
  reset button to re-initialize the register. However, not all boards
  have switches/buttons so the current way must be available.

* The reset button should also clear the input data buffer, thus
  helping restart a miner without reprogramming. Useful if the serial
  cables get disconnected and reconnected, messing up the buffers. ->
  done.


Bugs/issues
-----------

The hub logic is currently not parameterized, it is hardcoded with two
ports. At the heart of it is an if-else construct; even if it could be
generated from parameters, it would probably not scale to high
clockspeeds and larger hubs.

Some alternatives are explored in the fpgaminer_top_alt* files, but
none currently work at the moment; they only return results from the
first port. This may be a subtle bug with timing etc.