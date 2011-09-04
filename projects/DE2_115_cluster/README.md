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

* A hub relays work data to each miner, and collects results for
  returning to miner.py. If miners return work very close to each
  other, the hub will cache results and send one at a time.
 
* miner.py is exactly the same as for a single miner.

* Every FPGA in the cluster now includes a hub. For leaf nodes it acts
  as a serial send buffer. Other nodes are configured with external
  ports, and likely one or more internal ports for local miners.


Scaling
-------

* Hubs can be daisy chained for big clusters. The serial port can
  handle about 2880 results/s, corresponding to a limit of about 12
  Thash/s for one cluster. Even with tight bursts of results, the
  caching in hubs should help avoid lost results (though only one
  result per input port is cached). Nevertheless, real-world scaling
  remains to be seen.

* Each miner must know the total number of miners in the cluster, as
  it equals the nonce stride. Each miner also needs a distinct nonce
  start. This means building a new .sof/.bit for each node, unless
  nonce_start could be set with a switch, for example.


Caveats
-------

* Miners should probably run at roughly the same hashrate, to cover
  the nonce space evenly. But if you have very differently sized
  FPGAs, you could put several small miners on a big chip to balance
  things out.


Use cases besides clustering
----------------------------

* A huge FPGA that can fit several fully unrolled miners

* A moderately sized FPGA that can fit, say, 1.5 full miners. You
  could then fit 3 half-miners to fully utilize the silicon.


Current implementation
----------------------

The code is mostly being tested on a DE2-115, with two or more local
miners configured with the hub, and no external ports.

This works on Xilinx systems too, by changing the PLL code to a DCM,
see ../Xilinx_cluster for an implementation. Tested on a Nexys2 board
with a single miner.

Feel free to mix vendors in a cluster, as long as signal levels
match. A quick and dirty setup (below) has shown this to work.

To build the code, download and unzip

http://www.fpga4fun.com/files/async.zip

Change the clock frequency in both async_* files to match the hash
clock. Proceed building the project fpgaminer as usual.


Quick and dirty test setup
--------------------------

If you already have an FPGA with my serial miner, you can use it as a
leaf node for testing the hub. There will overlap in the nonce ranges,
but it saves the time of building new code, until the hub is verified
to work.

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
  nonce_stride=1. -> done, but now replaced by the hubbed version, as
  extra overheads are removed and it provides useful caching.

* A reset button to clear the input data buffer, thus helping restart
  a miner without reprogramming. Useful if the serial cables get
  disconnected and reconnected, messing up the buffers. -> done.

* Reset the nonce each time it overflows -> no need for the 2^n
  restriction for TOTAL_MINERS. -> done.

* A more dynamic scheme for the different nonce ranges. Currently this
  needs different bitfiles for each FPGA, with considerable
  synthesis-time configuration. For example, setting nonce_start and
  nonce_stride with switches would be nicer. The reset button would
  then initialize the nonce value properly. However, not all boards
  have switches/buttons so the current way must be available.

* Connecting local miners without the serial overhead. This should be
  quite straightforward, as the hub logic already operates at the
  level of 32-bit nonces. For more than one miner, there would be
  further savings in that everyone could read the same workdata
  register. (However, routing the 512-bit data might be problematic,
  especially on Xilinx.) This also makes the separate slave code
  unnecessary. The slight overhead of a single-port hub is actually a
  welcome improvement, as it will cache a result if they come too
  close together for sending. -> done.

