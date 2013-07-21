/*
*
* Copyright (c) 2011 fpgaminer@bitcoin-mining.com
*
*
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
* 
*/

`timescale 1ns/1ps

`define IDX(x) (((x)+1)*(32)-1):((x)*(32))

//`define SIM

// Extra registers to marginally reduce critical path, but increase area
`define EXTRAREGS

module fpgaminer_top (osc_clk, RxD, TxD, LEDS_out);
`ifdef SERIAL_CLK
  parameter comm_clk_frequency = `SERIAL_CLK;
`else
  parameter comm_clk_frequency = 50_000_000;
`endif
  parameter CORES = 1;

  input osc_clk;
  output [7:0] LEDS_out;
  
  //// PLL
  wire hash_clk;
`ifndef SIM
  main_pll pll_blk (osc_clk, hash_clk);
`else
  assign hash_clk = osc_clk;
`endif

  //// Hashers
  reg [7:0] cnt = 8'd0;
  reg pass = 1'd0;
  reg [255:0] midstate = 256'h0;
  reg [95:0] data = 96'h0;
  reg [31:0] nonce = 32'h0;
  wire [CORES-1:0] gnon;

  assign LEDS_out = nonce[31:24];
  
  localparam h0 = {32'h5be0cd19, 32'h1f83d9ab, 32'h9b05688c, 32'h510e527f, 32'ha54ff53a, 32'h3c6ef372, 32'hbb67ae85, 32'h6a09e667};
  
  localparam Ks = {
		32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5,
		32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
		32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3,
		32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
		32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc,
		32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
		32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7,
		32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
		32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13,
		32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
		32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3,
		32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
		32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5,
		32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
		32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208,
		32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2};

  wire [31:0] k_in, r1_in[0:1], r1_in0[0:15], r1_in1[0:7];
`ifdef EXTRAREGS
  assign k_in = Ks[32*(63-cnt) +: 32]; // send k 1-cycle early
`else
  assign k_in = Ks[32*(64-cnt) +: 32];
`endif

// To pack or not to pack? Certainly makes referring to them easier
  assign r1_in0[0] = data[`IDX(0)];
  assign r1_in0[1] = data[`IDX(1)];
  assign r1_in0[2] = data[`IDX(2)];
  assign r1_in0[3] = nonce;
  assign r1_in0[4] = 32'h80000000;
  assign r1_in0[5] = 32'h0;
  assign r1_in0[6] = 32'h0;
  assign r1_in0[7] = 32'h0;
  assign r1_in0[8] = 32'h0;
  assign r1_in0[9] = 32'h0;
  assign r1_in0[10] = 32'h0;
  assign r1_in0[11] = 32'h0;
  assign r1_in0[12] = 32'h0;
  assign r1_in0[13] = 32'h0;
  assign r1_in0[14] = 32'h0;
  assign r1_in0[15] = 32'h00000280;

  assign r1_in1[0] = 32'h80000000;
  assign r1_in1[1] = 32'h0;
  assign r1_in1[2] = 32'h0;
  assign r1_in1[3] = 32'h0;
  assign r1_in1[4] = 32'h0;
  assign r1_in1[5] = 32'h0;
  assign r1_in1[6] = 32'h0;
  assign r1_in1[7] = 32'h00000100;
  
  assign r1_in[0] = r1_in0[cnt[3:0]]; // for cnt = 0:15
  assign r1_in[1] = r1_in1[cnt[2:0]]; // for cnt = 8:15
  
  wire [255:0] midstate_w[1:0];
  assign midstate_w[0]=midstate;
  assign midstate_w[1]=h0;
  
  genvar i;
  generate
  for (i=0; i<CORES; i=i+1) begin : cores
    microcore #(.N(i)) uut (
      .clk(hash_clk),
      .cnt(cnt),
	  .pass(pass),
      .midstate(midstate_w[pass]),
	  .m7(midstate[`IDX(0)]), // a few extra wires to save 1 cycle and extra regs
	  .k_in(k_in),
	  .r1_in(r1_in[pass]),
      .gnon(gnon[i])
    );
  end
  endgenerate

  //// Virtual Wire Control
  reg [255:0] midstate_buf = 0, data_buf = 0;
  wire [255:0] midstate_vw, data2_vw;
   
  input RxD;
  wire rx_done;

  //// Virtual Wire Output
  reg [31:0] golden_nonce = 0;
  reg serial_send;
  wire serial_busy;
  output TxD;

  //// Control Unit
  wire [31:0] nonce_next;
`ifndef SIM
  wire reset;
  assign reset = rx_done;
`else
  reg reset = 1'b0;
`endif

  integer j;
  
  // Microcore Control  
  always @ (posedge hash_clk) begin
    if (pass==0) begin
	  if (cnt<66) cnt <= cnt + 1;
	  else begin
	    cnt <= 0;
	    pass <= 1;
      end
	  if (cnt==1) begin
	    // Check to see if the last hash generated is valid.
	    // priority encoder - only return one of possible (unlikely) simultaneous results
	    if ((gnon!=0) & !serial_busy) begin
	      for (j=0; j<CORES; j=j+1) begin: encoder
		    if (gnon[j]) begin
		      golden_nonce <= nonce + (j - CORES);
`ifdef SIM
              $display ("GOLDEN TICKET %08x from core: %08x", nonce - CORES + j, j);
`endif  
		      disable encoder;
		    end
	      end
  		  serial_send <= 1;
        end // if (is_golden_ticket)
        // Nonce space exhausted with no results, need more work
        else if (&nonce & !serial_busy) begin
          golden_nonce <= 32'd0;
          serial_send <= 1;
        end else serial_send <= 0;
	  end
    end
    else begin // (pass==1)
      if (cnt<61) cnt <= cnt + 1; // was 63, dropped 2 cycles
	  else begin
	    cnt <= 0;
        pass <= 0;
`ifndef SIM
        midstate <= midstate_buf;
        data <= data_buf[95:0];
`endif
	  end 
    end
	
	nonce <= nonce_next;

`ifndef SIM
    midstate_buf <= midstate_vw;
    data_buf <= data2_vw;
`endif
  end

  serial_receive #(.comm_clk_frequency(comm_clk_frequency)) serrx (.clk(hash_clk), .RxD(RxD), .midstate(midstate_vw), .data2(data2_vw), .rx_done(rx_done));

  serial_transmit #(.comm_clk_frequency(comm_clk_frequency)) sertx (.clk(hash_clk), .TxD(TxD), .send(serial_send), .busy(serial_busy), .word(golden_nonce));

  assign nonce_next = reset ? 32'd0 : ((pass==1) && (cnt==61)) ? (nonce + CORES) : nonce;

endmodule
