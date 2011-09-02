// Hub code for a cluster of miners using async links

// by teknohog

// Xilinx DCM
//`include "main_pll.v"
`include "main_pll_2x.v"

`include "../../src/sha-256-functions.v"
`include "../../src/sha256_transform.v"
`include "../DE2_115_cluster/serial.v"
`include "../DE2_115_cluster/serial_hub.v"
`include "../DE2_115_cluster/hub_core.v"
`include "../DE2_115_cluster/miner.v"

`include "async_receiver.v"
`include "async_transmitter.v"

module fpgaminer_top (osc_clk, RxD, TxD, extminer_rxd, extminer_txd, reset);

   input osc_clk;
//   main_pll pll_blk (.CLKIN_IN(osc_clk), .CLK0_OUT(hash_clk));
   main_pll pll_blk (.CLKIN_IN(osc_clk), .CLK2X_OUT(hash_clk));

   // Reset input buffers, both the workdata buffers in miners, and
   // the nonce receivers in hubs
   input  reset;
   
   // Nonce stride for all miners in the cluster, not just this hub.
   parameter TOTAL_MINERS = 2;

   // For local miners only
   parameter LOOP_LOG2 = 5;

   // Miners on the same FPGA with this hub
   parameter LOCAL_MINERS = 1;

   // Make sure each miner has a distinct nonce start. Local miners'
   // starts will range from this to LOCAL_NONCE_START + LOCAL_MINERS - 1.
   parameter LOCAL_NONCE_START = 1;
   
   // It is OK to make extra/unused ports, but TOTAL_MINERS must be
   // correct for the actual number of hashers.
   parameter EXT_PORTS = 1;

   localparam SLAVES = LOCAL_MINERS + EXT_PORTS;

   wire [LOCAL_MINERS-1:0] localminer_rxd;

   // Work distribution is simply copying to all miners, so no logic
   // needed there, simply copy the RxD.
   input 	     RxD;

   output TxD;

   // Results from the input buffers (in serial_hub.v) of each slave
   wire [SLAVES*32-1:0] slave_nonces;
   wire [SLAVES-1:0] 	new_nonces;

   // Using the same transmission code as individual miners from serial.v
   wire 		serial_send;
   wire 		serial_busy;
   wire [31:0] 		golden_nonce;
   serial_transmit sertx (.clk(hash_clk), .TxD(TxD), .send(serial_send), .busy(serial_busy), .word(golden_nonce));

   hub_core #(.SLAVES(SLAVES)) hc (.hash_clk(hash_clk), .new_nonces(new_nonces), .golden_nonce(golden_nonce), .serial_send(serial_send), .serial_busy(serial_busy), .slave_nonces(slave_nonces));

   // Local miners and their input ports
   generate
      genvar 	     i;
      for (i = 0; i < LOCAL_MINERS; i = i + 1)
	begin: for_local_miners
	   miner #(.nonce_stride(TOTAL_MINERS), .nonce_start(LOCAL_NONCE_START+i), .LOOP_LOG2(LOOP_LOG2)) M (.hash_clk(hash_clk), .RxD(RxD), .TxD(localminer_rxd[i]), .serial_reset(reset));

   	   slave_receive slrx (.clk(hash_clk), .RxD(localminer_rxd[i]), .nonce(slave_nonces[i*32+31:i*32]), .new_nonce(new_nonces[i]), .reset(reset));
	end
   endgenerate

   // External miner ports, results appended to the end of slave_nonces
   output [EXT_PORTS-1:0] extminer_txd;
   assign extminer_txd = {EXT_PORTS{RxD}};
   input [EXT_PORTS-1:0]  extminer_rxd;
   
   generate
      genvar 		  j;
      for (j = LOCAL_MINERS; j < SLAVES; j = j + 1)
	begin: for_ports
   	   slave_receive slrx (.clk(hash_clk), .RxD(extminer_rxd[j-LOCAL_MINERS]), .nonce(slave_nonces[j*32+31:j*32]), .new_nonce(new_nonces[j]), .reset(reset));
	end
   endgenerate
    
endmodule

