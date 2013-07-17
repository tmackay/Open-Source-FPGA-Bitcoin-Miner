// Testbench for fpgaminer_top.v

`timescale 1ns/1ps

`define HSX(x) (((x)+(64/LOOP))%(64/LOOP))

module test_fpgaminer_top ();
	parameter LOOP_LOG2 = 0;
	localparam [5:0] LOOP = (6'd1 << LOOP_LOG2);

	reg clk = 1'b0;
	reg RxD = 1'b0;
	reg disp_switch = 1'b0;
	wire TxD;
	wire [55:0] segment;

	fpgaminer_top # (.LOOP_LOG2(LOOP_LOG2)) uut (clk, RxD, TxD, segment, disp_switch);

	reg [31:0] cycle = 32'd0;

	initial begin
		clk = 0;
		#100

		// Test data
		uut.midstate_buf = 256'h635ef71f2ce00832a4b416afc1945ba0d775d72163ab4d6815c08d6e1620437b;
		uut.data_buf = 96'he5e1081ae9a4374e1e8d8d13;
		uut.nonce = 32'h195a2c52 - 1; // starting with nonce_next
		
		
		while(cycle<140)
		begin
			#5 clk = 1; #5 clk = 0;
		end

	end
	
	always @ (posedge clk)
	begin
		cycle <= cycle + 32'd1;
	end

	genvar i;
	generate
	//HASHERS[i-1].cur_w1
	for (i=0; i < 64/LOOP+5; i = i + 1) begin
		always @ (posedge clk) begin
			if (cycle == (i+1)) $display ("%02u %08x %08x %08x %08x %08x (%08x)", cycle-2, uut.uut.HASHERS[`HSX(i-3)].U.a, uut.uut.HASHERS[`HSX(i-2)].U.e,
																				 uut.uut.HASHERS[`HSX(i-1)].U.m1, uut.uut.HASHERS[`HSX(i-1)].U.m2,
																				 uut.uut.HASHERS[`HSX(i-2)].U.l, uut.uut.HASHERS[`HSX(i-1)].cur_w1);
			if (cycle == (i+69)) $display ("%02u %08x %08x %08x %08x %08x (%08x)", cycle-2, uut.uut2.HASHERS[`HSX(i-3)].U.a, uut.uut2.HASHERS[`HSX(i-2)].U.e,
																				 uut.uut2.HASHERS[`HSX(i-1)].U.m1, uut.uut2.HASHERS[`HSX(i-1)].U.m2,
																				 uut.uut2.HASHERS[`HSX(i-2)].U.l, uut.uut2.HASHERS[`HSX(i-1)].cur_w1);
		end
	end
	endgenerate
	
	always @ (posedge clk) begin
		if (cycle == 69) $display ("%02u %08x", cycle-2, uut.uut.tx_hash);
		if (cycle == 137) $display ("%08x: %064x", uut.nonce, uut.uut2.tx_hash);
	end

endmodule

