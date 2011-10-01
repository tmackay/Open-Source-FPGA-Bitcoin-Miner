// Hub code for a cluster of miners using async links

// by teknohog

// Xilinx DCM
//`include "main_pll.v"
`include "main_pll_2x.v"
`include "dcm_2thirds_internal.v"

`include "../../src/sha-256-functions.v"
`include "../../src/sha256_transform.v"
`include "../DE2_115_cluster/serial.v"
`include "../DE2_115_cluster/serial_hub.v"
`include "../DE2_115_cluster/hub_core.v"
`include "../DE2_115_cluster/miner.v"

`include "../DE2_115_cluster/pwm_fade.v"

`include "async_receiver.v"
`include "async_transmitter.v"

//module fpgaminer_top (osc_clk, RxD, TxD, extminer_rxd, extminer_txd);
module fpgaminer_top (osc_clk, RxD, TxD, led, extminer_rxd, extminer_txd);
//module fpgaminer_top (osc_clk, RxD, TxD, led);

   input osc_clk;
//   main_pll pll_blk (.CLKIN_IN(osc_clk), .CLK0_OUT(hash_clk));
//   main_pll pll_blk (.CLKIN_IN(osc_clk), .CLK2X_OUT(hash_clk));

   // clk * 2 / 1.5 = 4/3 * clk
   wire clk_2x;
   main_pll pll_blk (.CLKIN_IN(osc_clk), .CLK2X_OUT(clk_2x));
   dcm_2thirds_internal dcm23 (.CLKIN_IN(clk_2x), .CLKDV_OUT(hash_clk));
   
   // Reset input buffers, both the workdata buffers in miners, and
   // the nonce receivers in hubs
   //input  reset;
   reg 	  reset = 0;
   
   // Nonce stride for all miners in the cluster, not just this hub.
`ifdef TOTAL_MINERS
   parameter TOTAL_MINERS = `TOTAL_MINERS;
`else
   parameter TOTAL_MINERS = 5;
`endif

   // For local miners
`ifdef LOOP_LOG2
   parameter LOOP_LOG2 = `LOOP_LOG2;
`else
   parameter LOOP_LOG2 = 5;
`endif

   // Miners on the same FPGA with this hub
`ifdef LOCAL_MINERS
   parameter LOCAL_MINERS = `LOCAL_MINERS;
`else
   parameter LOCAL_MINERS = 5;
`endif

   // Make sure each miner has a distinct nonce start. Local miners'
   // starts will range from this to LOCAL_NONCE_START + LOCAL_MINERS - 1.
`ifdef LOCAL_NONCE_START
   parameter LOCAL_NONCE_START = `LOCAL_NONCE_START;
`else
   parameter LOCAL_NONCE_START = 0;
`endif
   
   // It is OK to make extra/unused ports, but TOTAL_MINERS must be
   // correct for the actual number of hashers.
`ifdef EXT_PORTS
   parameter EXT_PORTS = `EXT_PORTS;
`else
   parameter EXT_PORTS = 0;
`endif

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

   // Common workdata input for local miners
   wire [255:0] 	midstate, data2;
   serial_receive serrx (.clk(hash_clk), .RxD(RxD), .midstate(midstate), .data2(data2), .reset(reset));

   // Local miners now directly connected
   generate
      genvar 	     i;
      for (i = 0; i < LOCAL_MINERS; i = i + 1)
	begin: for_local_miners
	   miner #(.nonce_stride(TOTAL_MINERS), .nonce_start(LOCAL_NONCE_START+i), .LOOP_LOG2(LOOP_LOG2)) M (.hash_clk(hash_clk), .midstate_vw(midstate), .data2_vw(data2), .nonce_out(slave_nonces[i*32+31:i*32]), .is_golden(new_nonces[i]));
	end
   endgenerate

   // External miner ports, results appended to the same
   // slave_nonces/new_nonces as local ones
   output [EXT_PORTS-1:0] extminer_txd;
   input [EXT_PORTS-1:0]  extminer_rxd;
   assign extminer_txd = {EXT_PORTS{RxD}};
      
   generate
      genvar 		  j;
      for (j = LOCAL_MINERS; j < SLAVES; j = j + 1)
	begin: for_ports
   	   slave_receive slrx (.clk(hash_clk), .RxD(extminer_rxd[j-LOCAL_MINERS]), .nonce(slave_nonces[j*32+31:j*32]), .new_nonce(new_nonces[j]), .reset(reset));
	end
   endgenerate

   output [2:0] led;
   //assign led[0] = |golden_nonce;
   assign led[1] = ~RxD;
   assign led[2] = ~TxD;

   // Light up only from locally found nonces, not ext_port results
   pwm_fade #(.LOCAL_MINERS(LOCAL_MINERS), .LOOP_LOG2(LOOP_LOG2)) pf (.clk(hash_clk), .trigger(|new_nonces[LOCAL_MINERS-1:0]), .drive(led[0]));
   
endmodule

