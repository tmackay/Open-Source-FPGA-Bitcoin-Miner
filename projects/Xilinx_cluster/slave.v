// Slave miner for a cluster using async links (or a standalone miner
// if you set TOTAL_MINERS = 1)

// If you need a cluster node with several hashers, use the full hub
// code with integrated miners.

// by teknohog

// Xilinx DCM
//`include "main_pll.v"
`include "main_pll_2x.v"

`include "../../src/sha-256-functions.v"
`include "../../src/sha256_transform.v"
`include "../DE2_115_cluster/serial.v"
`include "../DE2_115_cluster/miner.v"

`include "async_receiver.v"
`include "async_transmitter.v"

module slave (osc_clk, RxD, TxD, reset);

   input osc_clk;
   wire hash_clk;
   
//   main_pll pll_blk (.CLKIN_IN(osc_clk), .CLK0_OUT(hash_clk));
   main_pll pll_blk (.CLKIN_IN(osc_clk), .CLK2X_OUT(hash_clk));

   // This determines the nonce stride for all miners in the cluster,
   // not just this hub. For an actual cluster of separately clocked
   // FPGAs, this should be a power of two. Otherwise the nonce ranges
   // may overlap.
   parameter TOTAL_MINERS = 1;

   parameter LOOP_LOG2 = 5;

   // Make sure each miner has a distinct nonce start.
   parameter LOCAL_NONCE_START = 0;

   input RxD;
   output TxD;
   input  reset;
   
   miner #(.nonce_stride(TOTAL_MINERS), .nonce_start(LOCAL_NONCE_START), .LOOP_LOG2(LOOP_LOG2)) M (.hash_clk(hash_clk), .RxD(RxD), .TxD(TxD), .serial_reset(reset));
    
endmodule

