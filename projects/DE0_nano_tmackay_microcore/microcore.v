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

//`define SIM

`timescale 1ns/1ps

// A quick define to help index 32-bit words inside a larger register.
`define IDX(x) (((x)+1)*(32)-1):((x)*(32))

// Extra registers to marginally reduce critical path, but increase area
`define EXTRAREGS

module microcore # (parameter N = 0) (
  input clk,
  input [7:0] cnt,
  input pass,
  input [255:0] midstate,
  input [31:0] m7,
  input [31:0] k_in,
  input [31:0] r1_in,
  output wire gnon
);

  reg [31:0] w[0:6]; // buffer for core loopback. Dual input, single output stack/order reversing buffer. Probably a better way to implement this.
  // Expander regs
  reg [31:0] r1, r16;
  wire [31:0] r7, r15, s0_w, s1_w, csa0_oo, csa0_ot, csa1_oo, csa1_ot;
  // Core regs
  reg [31:0] a, b, c, e, f, g, l, m1, m2;
`ifdef EXTRAREGS
  reg [31:0] k, ak;
`endif

  // Expander
`ifdef EXTRAREGS
  reg [31:0] oo, ot;
  shifter_32b #(.LENGTH(5)) r3_7 (clk, r1, r7);
  s1 s1_blk (r1, s1_w);
`else
  reg [31:0] r2;
  shifter_32b #(.LENGTH(5)) r3_7 (clk, r2, r7);
  s1 s1_blk (r2, s1_w);
`endif

  shifter_32b #(.LENGTH(8)) r8_15 (clk, r7, r15);
  
  s0 s0_blk (r15, s0_w);
  csa csa0 (s0_w, r16, r7, csa0_oo, csa0_ot);
  csa csa1 (s1_w, csa0_oo, csa0_ot, csa1_oo, csa1_ot);

  always @ (posedge clk) begin
`ifdef EXTRAREGS
    oo <= csa1_oo;
	ot <= csa1_ot;
    if (cnt>15) r1 <= oo + ot;
`else
	r2 <= r1;
    if (cnt>15) r1 <= csa1_oo + csa1_ot;
`endif

	else if ((pass==0) && (cnt==3)) r1 <= r1_in + N; // add nonce offset for core N
	else if ((pass==1) && (cnt==0)) r1 <= a + m7;
	else if ((pass==1) && (cnt<8)) r1 <= w[cnt-1];
    else r1 <= r1_in;

    r16 <= r15;
  end

  // SHA-2 Core
  wire [31:0] b_w, g_w, csa_in0_oo, csa_in0_ot, csa_in1_oo, csa_in1_ot, csa_m1_oo, csa_m1_ot, csa_m2_oo, csa_m2_ot, csa_l_oo, csa_l_ot, ch_o, maj_o, e0_o, e1_o;
`ifdef EXTRAREGS
  assign b_w = (cnt>2)? a : (cnt==0)? midstate[`IDX(3)] : (cnt==1)? midstate[`IDX(2)] : midstate[`IDX(1)];
  csa csa_in0 (r1, k, g_w, csa_in0_oo, csa_in0_ot);
  csa csa_in1 (r1, ak, g_w, csa_in1_oo, csa_in1_ot);
`else
  assign b_w = (cnt>2)? b : (cnt==1)? midstate[`IDX(3)] : (cnt==2)? midstate[`IDX(2)] : b;
  csa csa_in0 (r1, k_in, g_w, csa_in0_oo, csa_in0_ot);
  csa csa_in1 (b_w, csa_in0_oo, csa_in0_ot, csa_in1_oo, csa_in1_ot);
`endif
  assign g_w = (cnt==1)? midstate[`IDX(7)] : g;
  
  csa csa_m1 (m1, ch_o, e1_o, csa_m1_oo, csa_m1_ot);
  csa csa_m2 (m2, ch_o, e1_o, csa_m2_oo, csa_m2_ot);
  csa csa_l (l, maj_o, e0_o, csa_l_oo, csa_l_ot);

  e0 e0_blk (a, e0_o);
  e1 e1_blk (e, e1_o);
  
  ch ch_blk (e, f, g, ch_o);
  maj maj_blk (a, b, c, maj_o);

  always @ (posedge clk) begin
`ifdef EXTRAREGS
	if (cnt<64) begin
	  k <= k_in;
	  ak <= b_w + k_in;
    end
`endif
	m1 <= csa_in1_oo + csa_in1_ot;
	m2 <= csa_in0_oo + csa_in0_ot;

	if (cnt==1) begin
	  e <= midstate[`IDX(4)];
	  f <= midstate[`IDX(5)];
	  g <= midstate[`IDX(6)];
	end else begin
	  e <= csa_m1_oo + csa_m1_ot;	
	  f <= e;
      g <= f;
    end
	
	if (cnt==2) begin
	  a <= midstate[`IDX(0)];
	  b <= midstate[`IDX(1)];
	  c <= midstate[`IDX(2)];
	end else begin
	  a <= csa_l_oo + csa_l_ot;
	  b <= a;
      c <= b;
    end

	l <= csa_m2_oo + csa_m2_ot;

`ifdef SIM
	$display ("%02u %08x %08x %08x %08x %08x (%08x)", cnt, a, e, m1, m2, l, r1);
`endif
	
  end

  always @ (posedge clk) begin
    if (pass==0) begin
      if (cnt==63) w[6] <= e + midstate[`IDX(7)];
	  if (cnt==64) w[5] <= e + midstate[`IDX(6)];
	  if (cnt==65) w[4] <= e + midstate[`IDX(5)];
	  if (cnt==66) w[3] <= e + midstate[`IDX(4)];
      if (cnt==64) w[2] <= a + midstate[`IDX(3)];
      if (cnt==65) w[1] <= a + midstate[`IDX(2)];
      if (cnt==66) w[0] <= a + midstate[`IDX(1)];
	end
  end
  assign gnon = (cnt==1) && (e == 32'ha41f32e7);
endmodule

module shifter_32b # (
	parameter LENGTH = 1
) (
	input clk,
	input [31:0] val_in,
	output [31:0] val_out
);

	genvar i;

	generate
`ifndef DONT_USE_ALTSHIFT
		if (LENGTH >= 4)
		begin
			altshift_taps # (.number_of_taps(1), .tap_distance(LENGTH), .width(32)) shifttaps
				(.clken(1'b1), .aclr(1'b0), .clock(clk), .shiftin(val_in), .taps(), .shiftout(val_out) );
		end
		else
`endif
		begin
			for (i = 0; i < LENGTH; i = i + 1) begin : TAPS
				reg [31:0] r;
				wire [31:0] prev;

				if (i == 0)
					assign prev = val_in;
				else
					assign prev = TAPS[i-1].r;

				always @ (posedge clk)
					r <= prev;
			end
			assign val_out = TAPS[LENGTH-1].r;
		end
	endgenerate
endmodule

module csa (a,b,c,oo,ot);
parameter WIDTH = 32;
input [WIDTH-1:0] a,b,c;
output [WIDTH-1:0] oo,ot;
	assign oo[0] = a[0] ^ b[0] ^ c[0];
	assign ot[0] = 0;

	genvar i;
	generate
		for (i=1; i<WIDTH; i=i+1) begin : cmp
			assign oo[i] = a[i] ^ b[i] ^ c[i];
			assign ot[i] = (a[i-1] & b[i-1]) | (a[i-1] & c[i-1]) | (b[i-1] & c[i-1]);			
		end
	endgenerate
endmodule
