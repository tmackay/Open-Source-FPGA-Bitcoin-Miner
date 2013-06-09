FPGA mining cluster, DE2-115 version for cgminer
------------------------------------------------

by teknohog

This is a version of my serial mining cluster for Altera devices like
the DE2-115 board. The clustering idea is explained in

../DE2_115_cluster

and the cgminer compatibility hack in

../DE2_115_makomk_serial_109mhz_cgminer

Note that the cgminer/Icarus timing is the time taken for one hash in
nanoseconds. For example 12.5 for 80 Mhash/s.

The UART code is from fpgaminer's KC705_experimental project, so there
are no external files to fetch.
