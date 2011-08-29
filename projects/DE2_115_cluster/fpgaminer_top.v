// Hub code for a cluster of miners using async links, on the same
// FPGA for now

// by teknohog

module fpgaminer_top (osc_clk, RxD, TxD);

	//// PLL

   input osc_clk;
   wire hash_clk;
	`ifndef SIM
                main_pll pll_blk (osc_clk, hash_clk);
	`else
		assign hash_clk = osc_clk;
	`endif

   // For an actual cluster of separately clocked FPGAs, this should
   // be a power of two. Otherwise the nonce ranges may overlap.
   parameter MINERS = 2;

   parameter LOOP_LOG2 = 2;

   wire [MINERS-1:0] slave_rxd;
   
   // Work distribution is simply copying to all miners, so no logic
   // needed there, simply copy the RxD.
   input 	     RxD;
   
   output TxD;

   // It is unlikely that two nonces are found so close together, so
   // this is a simple way to get results back. Based on the fact that
   // a serial line is high when idle.
   //assign TxD = &slave_rxd;

   // A more robust logic is needed to return results, when there are
   // more/faster miners. Here there is a separate receive buffer for
   // each miner.
   wire [MINERS*32-1:0] slave_nonces;
   wire [MINERS-1:0] 	new_nonces;

   // Using the same transmission code as individual miners :)
   reg 			serial_send = 0;
   wire 		serial_busy;
   reg [31:0] 		golden_nonce = 0;
   serial_transmit sertx (.clk(hash_clk), .TxD(TxD), .send(serial_send), .busy(serial_busy), .word(golden_nonce));

   // Remember all nonces, even when they come too close together, and
   // send them whenever the uplink is ready
   reg [MINERS-1:0] 	new_nonces_flag = 0;
   
   // TODO: generate for any number of MINERS
   always @(posedge hash_clk)
     begin
	if (new_nonces[0]) new_nonces_flag[0] <= 1;
	if (new_nonces[1]) new_nonces_flag[1] <= 1;

	// Send results one at a time, until all nonce flags are cleared.
	if (!serial_busy && |new_nonces_flag)
	  begin
	     serial_send <= 1;

	     if (new_nonces_flag[0])
	       begin
		  golden_nonce <= slave_nonces[31:0];
		  new_nonces_flag[0] <= 0;
	       end
	     else //if (new_nonces_flag[1])
	       begin
		  golden_nonce <= slave_nonces[31+32:32];
		  new_nonces_flag[1] <= 0;
	       end
	  end
	else serial_send <= 0;
     end
   
   generate
      genvar 	     i;
      for (i = 0; i < MINERS; i = i + 1)
	begin: for_miners
	   miner #(.nonce_stride(MINERS), .nonce_start(i), .LOOP_LOG2(LOOP_LOG2)) M (.hash_clk(hash_clk), .RxD(RxD), .TxD(slave_rxd[i]));

	   slave_receive slrx (.clk(hash_clk), .RxD(slave_rxd[i]), .nonce(slave_nonces[i*32+31:i*32]), .new_nonce(new_nonces[i]));
	end
   endgenerate

endmodule

