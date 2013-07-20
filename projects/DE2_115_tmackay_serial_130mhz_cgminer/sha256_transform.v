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

// A quick define to help index 32-bit words inside a larger register.
`define IDX(x) (((x)+1)*(32)-1):((x)*(32))


// Perform a SHA-256 transformation on the given 512-bit data, and 256-bit
// initial state,
// Outputs one 256-bit hash every LOOP cycle(s).
//
// The LOOP parameter determines both the size and speed of this module.
// A value of 1 implies a fully unrolled SHA-256 calculation spanning 64 round
// modules and calculating a full SHA-256 hash every clock cycle. A value of
// 2 implies a half-unrolled loop, with 32 round modules and calculating
// a full hash in 2 clock cycles. And so forth.
module sha256_transform #(
	parameter LOOP = 6'd4,
	parameter PASS = 1'b0
) (
	input clk,
	input feedback,
	input [5:0] cnt,
	input [255:0] rx_state,
	input [511:0] rx_input,
	output reg [255:0] tx_hash
);

	// Constants defined by the SHA-2 standard.
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


	reg [511:0] input_d0 = 0;
	reg [31:0] initial_wk = 0;
	
	wire [191:0] shifted_state_w;
	wire [31:0] first_initial_bin, second_initial_bin, initial_gin;

	genvar i;

	// W0 refers to the oldest word of W, not the most recent. W15 is the
	// W being calculated in the current round.
	generate

		for (i = 0; ((PASS==0) && (i < 64/LOOP)) || ((PASS==1) && (i < 64/LOOP-3)); i = i + 1) begin : HASHERS
			wire [31:0] new_w15;
			wire [191:0] state;
			wire [31:0] cur_w0, cur_w1, cur_w9, cur_w14, cur_wk;
			reg [479:0] new_w14to0;

			if (i == 0)
				assign cur_w14 = input_d0[479:448];
			else if (i == 1)
				shifter_32b #(.LENGTH(1)) shift_w14 (clk, input_d0[511:480], cur_w14);
			else
				assign cur_w14 = HASHERS[i-2].new_w15;


			if (i == 0)
				assign cur_w9 = input_d0[319:288];
			else if (i < 5)
				shifter_32b # (.LENGTH(i)) shift_w9 (clk, input_d0[`IDX(9+i)], cur_w9);
			else
				shifter_32b # (.LENGTH(5)) shift_w9 (clk, HASHERS[i-5].cur_w14, cur_w9);


			if (i == 0)
				assign cur_w1 = input_d0[63:32];
			else if(i < 8)
				shifter_32b #(.LENGTH(i)) shift_w1 (clk, input_d0[`IDX(1+i)], cur_w1);
			else
				shifter_32b #(.LENGTH(8)) shift_w1 (clk, HASHERS[i-8].cur_w9, cur_w1);
			

			if (i == 0)
				assign cur_wk = initial_wk;
			else
				shifter_32b # (.LENGTH(1)) shift_wk (clk, HASHERS[i-1].cur_w1 + Ks[32*(63-LOOP*i-cnt) +: 32], cur_wk);

			if (i == 0)
				assign cur_w0 = input_d0[31:0];
			else
				shifter_32b # (.LENGTH(1)) shift_w0 (clk, HASHERS[i-1].cur_w1, cur_w0);

			// Modelsim can't resolve U in testbench with conditional module U code. Replace with conditional wires.
			wire [191:0] rx_state_w;
			wire [31:0] rx_bin_w, rx_gin_w;
			sha256_digester U (
				.clk(clk),
				.rx_state(rx_state_w),
				.rx_wk(cur_wk),
				.rx_bin(rx_bin_w), // b from 2 hashers back - need to work out what to do for LOOP code
				.rx_gin(rx_gin_w), // g from 1 hasher back - need to work out what to do for LOOP code
				.tx_state(state)
			);

			if (i==0)
				assign rx_state_w = feedback ? state : shifted_state_w;
			else
				assign rx_state_w = HASHERS[i-1].state;

			if (i==0)
				assign rx_gin_w = initial_gin;
			else
				assign rx_gin_w = HASHERS[i-1].rx_state_w[`IDX(5)];

			if (i==0)
				assign rx_bin_w = first_initial_bin;
			else if (i==1)
				assign rx_bin_w = second_initial_bin;
			else
				assign rx_bin_w = HASHERS[i-2].rx_state_w[`IDX(1)];
			

			sha256_update_w upd_w (
				.clk(clk),
				.rx_w0(cur_w0),
				.rx_w1(cur_w1),
				.rx_w9(cur_w9),
				.rx_w14(cur_w14),
				.tx_w15(new_w15)
			);
		end

	endgenerate

	generate
	if (PASS==0) begin // don't need shifters for (nearly) static data, only some invalid data produced during transition
		assign shifted_state_w[191:96] = rx_state[223:128];
		assign shifted_state_w[95:0] = rx_state[95:0];		
		assign second_initial_bin = rx_state[`IDX(2)];
		assign first_initial_bin = rx_state[`IDX(3)];
		assign initial_gin = rx_state[`IDX(7)];
	end else begin
		// delay input state. E, F, G by 1 cycle, A, B, C by 2 cycles while we wait for w0 to work down the pipeline
		shifter_32b #(.LENGTH(3)) shift_a (clk, rx_state[`IDX(0)], shifted_state_w[`IDX(0)]); //A
		shifter_32b #(.LENGTH(3)) shift_b (clk, rx_state[`IDX(1)], shifted_state_w[`IDX(1)]); //B	
		shifter_32b #(.LENGTH(1)) shift_c2 (clk, rx_state[`IDX(2)], second_initial_bin); //C - also need C for 2nd hasher's B_in in 2 cycles
		shifter_32b #(.LENGTH(2)) shift_c (clk, second_initial_bin, shifted_state_w[`IDX(2)]); //C
		assign first_initial_bin = rx_state[`IDX(3)]; //D - need D in 1 cycle for 1st hasher's B_in

		shifter_32b #(.LENGTH(2)) shift_e (clk, rx_state[`IDX(4)], shifted_state_w[`IDX(3)]); //E
		shifter_32b #(.LENGTH(2)) shift_f (clk, rx_state[`IDX(5)], shifted_state_w[`IDX(4)]); //F
		shifter_32b #(.LENGTH(2)) shift_g (clk, rx_state[`IDX(6)], shifted_state_w[`IDX(5)]); //G
		assign initial_gin = rx_state[`IDX(7)]; //H - need H in 1 cycle for 1st hasher's G_in
	end
	endgenerate

	// delay output to resync
	wire [255:0] shifted_output;
	generate
	if (PASS==0) begin
		assign shifted_output[`IDX(0)] = rx_state[`IDX(0)] + HASHERS[64/LOOP-6'd1].state[`IDX(0)]; // A
		assign shifted_output[`IDX(1)] = rx_state[`IDX(1)] + HASHERS[64/LOOP-6'd1].state[`IDX(1)]; // B
		assign shifted_output[`IDX(2)] = rx_state[`IDX(2)] + HASHERS[64/LOOP-6'd1].state[`IDX(2)]; // C
		shifter_32b #(.LENGTH(1)) shift_d_out (clk, rx_state[`IDX(3)] + HASHERS[64/LOOP-6'd2].state[`IDX(2)], shifted_output[`IDX(3)]); // D (previous C shifted)

		shifter_32b #(.LENGTH(1)) shift_e_out (clk, rx_state[`IDX(4)] + HASHERS[64/LOOP-6'd1].state[`IDX(3)], shifted_output[`IDX(4)]); //E
		shifter_32b #(.LENGTH(1)) shift_f_out (clk, rx_state[`IDX(5)] + HASHERS[64/LOOP-6'd1].state[`IDX(4)], shifted_output[`IDX(5)]); //F
		shifter_32b #(.LENGTH(1)) shift_g_out (clk, rx_state[`IDX(6)] + HASHERS[64/LOOP-6'd1].state[`IDX(5)], shifted_output[`IDX(6)]); //G
		shifter_32b #(.LENGTH(2)) shift_h_out (clk, rx_state[`IDX(7)] + HASHERS[64/LOOP-6'd2].state[`IDX(5)], shifted_output[`IDX(7)]); //H (previous G shifted)
	end else begin
		//only check 3rd last hasher E - change for LOOP code
		assign shifted_output[`IDX(7)] = HASHERS[64/LOOP-6'd4].state[`IDX(3)]; // + rx_state[`IDX(7)] //E - don't even need the addition really
	end
	endgenerate

	always @ (posedge clk)
	begin
		input_d0 <= rx_input; // does this need its own reg?
		initial_wk <= rx_input[31:0] + Ks[32*(63) +: 32]; // To save regs and shifters, need this ASAP to get started with state regs

		if (!feedback) // no longer in sync with feedback due to extra delays/quasi pipeline. LOOP code needs rethink
			tx_hash <= shifted_output;
	end


endmodule


// Calculate W.
module sha256_update_w (clk, rx_w0, rx_w1, rx_w9, rx_w14, tx_w15);

	input clk;
	input [31:0] rx_w0, rx_w1, rx_w9, rx_w14;
	output reg [31:0] tx_w15;

	reg [31:0] t;

	wire [31:0] s0_w, s1_w, w0_w;
	
	shifter_32b # (.LENGTH(1)) shift_w0 (clk, rx_w0, w0_w);
	s0	s0_blk	(rx_w1, s0_w);
	s1	s1_blk	(rx_w14, s1_w);

	wire [31:0] new_t = s1_w + rx_w9 + s0_w;
	wire [31:0] new_w = w0_w + t;
	always @ (posedge clk) begin
		t <= new_t;
		tx_w15 <= new_w;
	end

endmodule


// These hashers no longer represent a single time step, but are spread over 4 time partitions
// bounded by the partial calculations and interleaved in the pipeline
module sha256_digester (clk, rx_state, rx_wk, rx_bin, rx_gin, tx_state);

	input clk;
	input [31:0] rx_wk, rx_bin, rx_gin;
	input [191:0] rx_state;

	output reg [191:0] tx_state;

	reg [31:0] m1_partial, m2_partial, l_partial;

	wire [31:0] e0_w, e1_w, ch_w, maj_w;


	e0	e0_blk	(rx_state[`IDX(0)], e0_w);
	e1	e1_blk	(rx_state[`IDX(3)], e1_w);
	ch	ch_blk	(rx_state[`IDX(3)], rx_state[`IDX(4)], rx_state[`IDX(5)], ch_w);
	maj	maj_blk	(rx_state[`IDX(0)], rx_state[`IDX(1)], rx_state[`IDX(2)], maj_w);
	
	wire [31:0] m1 = rx_wk + rx_bin + rx_gin;
	wire [31:0] m2 = rx_wk + rx_gin;
	wire [31:0] l = m2_partial + e1_w + ch_w;
	wire [31:0] e = m1_partial + e1_w + ch_w;
	wire [31:0] a = l_partial + e0_w + maj_w;

	always @ (posedge clk)
	begin
		m1_partial <= m1;
		m2_partial <= m2;
		l_partial <= l;

		tx_state[`IDX(5)] <= rx_state[`IDX(4)]; // G
		tx_state[`IDX(4)] <= rx_state[`IDX(3)]; // F
		tx_state[`IDX(3)] <= e;
		tx_state[`IDX(2)] <= rx_state[`IDX(1)]; // C
		tx_state[`IDX(1)] <= rx_state[`IDX(0)]; // B
		tx_state[`IDX(0)] <= a;
	end

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
		if (LENGTH >= 4)
		begin
			altshift_taps # (.number_of_taps(1), .tap_distance(LENGTH), .width(32)) shifttaps
				(.clken(1'b1), .aclr(1'b0), .clock(clk), .shiftin(val_in), .taps(), .shiftout(val_out) );
		end
		else
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



