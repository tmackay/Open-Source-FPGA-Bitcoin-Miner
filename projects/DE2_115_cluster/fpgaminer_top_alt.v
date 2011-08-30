// Alternative/experimental hub code for an FPGA mining
// cluster. Attempting to parameterize the hub completely with no
// hardcoding.

// by teknohog

module fpgaminer_top (osc_clk, RxD, TxD);

   input osc_clk;
   wire hash_clk;
   main_pll pll_blk (osc_clk, hash_clk);

   // This determines the nonce stride for all miners in the cluster,
   // not just this hub. For an actual cluster of separately clocked
   // FPGAs, this should be a power of two. Otherwise the nonce ranges
   // may overlap.
   parameter TOTAL_MINERS = 8;

   // For local miners only
   parameter LOOP_LOG2 = 5;

   // Miners on the same FPGA with this hub
   parameter LOCAL_MINERS = 8;

   // Make sure each miner has a distinct nonce start. Local miners'
   // starts will range from this to LOCAL_NONCE_START + LOCAL_MINERS - 1.
   parameter LOCAL_NONCE_START = 0;
   
   // It is OK to make extra/unused ports, but TOTAL_MINERS must be
   // correct for the actual number of hashers.
   parameter EXT_PORTS = 0;

   localparam SLAVES = LOCAL_MINERS + EXT_PORTS;

   wire [LOCAL_MINERS-1:0] localminer_rxd;

   // Work distribution is simply copying to all miners, so no logic
   // needed there, simply copy the RxD.
   input 	     RxD;

   output TxD;

   // Results from the input buffers (in serial_hub.v) of each slave
   wire [SLAVES*32-1:0] slave_nonces;
   wire [SLAVES-1:0] 	new_nonces;

   // Remember all nonces, even when they come too close together, and
   // send them whenever the uplink is ready
   reg [SLAVES-1:0] 	new_nonces_flag = 0;

   // Replace the tedious if-else chain for input ports with a
   // continuously running selector. This may seem slow/inefficient
   // for a large hub, but it is still insanely faster than the serial
   // port we are driving. Also, due to simplicity, it should be more
   // robust for big hubs with fast clocks.
   reg [$clog2(SLAVES)+1:0] port_counter = 0;
   reg [SLAVES*32-1:0] slave_nonces_shifted;
   wire [31:0] 	       golden_nonce;
   assign golden_nonce = slave_nonces_shifted[31:0];
   
   // Using the same transmission code as individual miners from serial.v
   reg 			serial_send = 0;
   wire 		serial_busy;
   //reg [31:0] 		golden_nonce = 0;
   serial_transmit sertx (.clk(hash_clk), .TxD(TxD), .send(serial_send), .busy(serial_busy), .word(golden_nonce));

   always @(posedge hash_clk)
     begin
	// Raise flags when new nonces appear
	new_nonces_flag <= new_nonces_flag | new_nonces;

	if (port_counter == SLAVES-1)
	  port_counter <= 0;
	else
	  port_counter <= port_counter + 1;

	// Send results one at a time, lower the respective flag
	if (!serial_busy && new_nonces_flag[port_counter])
	  begin
	     slave_nonces_shifted <= slave_nonces >> port_counter*32;
	     serial_send <= 1;
	     new_nonces_flag[port_counter] <= 0;
	  end
	else serial_send <= 0;
     end

   // Local miners and their input ports
   generate
      genvar 	     i;
      for (i = 0; i < LOCAL_MINERS; i = i + 1)
	begin: for_local_miners
	   miner #(.nonce_stride(TOTAL_MINERS), .nonce_start(LOCAL_NONCE_START+i), .LOOP_LOG2(LOOP_LOG2)) M (.hash_clk(hash_clk), .RxD(RxD), .TxD(localminer_rxd[i]));

   	   slave_receive slrx (.clk(hash_clk), .RxD(localminer_rxd[i]), .nonce(slave_nonces[i*32+31:i*32]), .new_nonce(new_nonces[i]));
	end
   endgenerate

   // External miner ports, results appended to the end of slave_nonces
   /*
   output [EXT_PORTS-1:0] extminer_txd;
   assign extminer_txd = {EXT_PORTS{RxD}};
   input [EXT_PORTS-1:0]  extminer_rxd;
   
   generate
      genvar 		  j;
      for (j = LOCAL_MINERS; j < SLAVES; j = j + 1)
	begin: for_ports
   	   slave_receive slrx (.clk(hash_clk), .RxD(extminer_rxd[j-LOCAL_MINERS]), .nonce(slave_nonces[j*32+31:j*32]), .new_nonce(new_nonces[j]));
	end
   endgenerate
    */
    
endmodule

