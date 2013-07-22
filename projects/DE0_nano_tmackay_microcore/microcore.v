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
  wire [31:0] r7, r15, s0_w, s1_w;
  // Core regs
  reg [31:0] a, b, c, e, f, g, l, m1, m2;
  reg [31:0] k, ak;

  // Expander
  reg [31:0] oo, ot;
  shifter_32b #(.LENGTH(5)) r3_7 (clk, r1, r7);
  s1 s1_blk (r1, s1_w);

  shifter_32b #(.LENGTH(8)) r8_15 (clk, r7, r15);
  
  s0 s0_blk (r15, s0_w);

  always @ (posedge clk) begin
    oo <= s0_w + s1_w;
	ot <= r16 + r7;
    if (cnt>15) r1 <= oo + ot;

	else if ((pass==0) && (cnt==3)) r1 <= r1_in + N; // add nonce offset for core N
	else if ((pass==1) && (cnt==0)) r1 <= a + m7;
	else if ((pass==1) && (cnt<8)) r1 <= w[cnt-1];
    else r1 <= r1_in;

    r16 <= r15;
  end

  // SHA-2 Core
  wire [31:0] b_w, g_w, ch_o, maj_o, e0_o, e1_o;
  assign b_w = (cnt>2)? a : (cnt==0)? midstate[`IDX(3)] : (cnt==1)? midstate[`IDX(2)] : midstate[`IDX(1)];
  assign g_w = (cnt==1)? midstate[`IDX(7)] : g;
  
  e0 e0_blk (a, e0_o);
  e1 e1_blk (e, e1_o);
  
  ch ch_blk (e, f, g, ch_o);
  maj maj_blk (a, b, c, maj_o);

  always @ (posedge clk) begin
	if (cnt<64) begin
	  k <= k_in;
	  ak <= b_w + k_in;
    end

	m1 <= r1 + ak + g_w;
	m2 <= r1 + k + g_w;

	if (cnt==1) begin
	  e <= midstate[`IDX(4)];
	  f <= midstate[`IDX(5)];
	  g <= midstate[`IDX(6)];
	end else begin
	  e <= m1 + ch_o + e1_o;
	  f <= e;
      g <= f;
    end
	
	if (cnt==2) begin
	  a <= midstate[`IDX(0)];
	  b <= midstate[`IDX(1)];
	  c <= midstate[`IDX(2)];
	end else begin
	  a <= l + maj_o + e0_o;
	  b <= a;
      c <= b;
    end

	l <= m2 + ch_o + e1_o;

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
