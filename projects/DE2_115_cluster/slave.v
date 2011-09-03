// Slave miner for a cluster using async links (or a standalone miner
// if you set TOTAL_MINERS = 1 and LOCAL_NONCE_START = 0)

// If you need a cluster node with several hashers, use the full hub
// code with integrated miners.

// by teknohog

module slave (osc_clk, RxD, TxD, reset);

   input osc_clk;
   wire hash_clk;
   main_pll pll_blk (osc_clk, hash_clk);

   // Nonce stride for all miners in the cluster, not just this hub.
   parameter TOTAL_MINERS = 1;

   parameter LOOP_LOG2 = 1;

   // Make sure each miner has a distinct nonce start.
   parameter LOCAL_NONCE_START = 0;

   input RxD;
   output TxD;
   input  reset;
   
   miner #(.nonce_stride(TOTAL_MINERS), .nonce_start(LOCAL_NONCE_START), .LOOP_LOG2(LOOP_LOG2)) M (.hash_clk(hash_clk), .RxD(RxD), .TxD(TxD), .serial_reset(reset));
    
endmodule

