
`timescale 1ns/1ps

module test_fpgaminer_top ();
	reg clk = 1'b0;
	reg RxD = 1'b0;
	wire TxD;

	fpgaminer_top uut (clk, RxD, TxD);

	reg [31:0] cycle = 32'd0;

	initial begin
		clk = 0;
		#100

		// Test data
        // Request: {"method": "getwork", "params": [], "id":0}
        // Response: {"id":0,"error":null,"result":{"midstate":"7b4320166e8dc015684dab6321d775d7a05b94c1af16b4a43208e02c1ff75e63","target":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000","data":"0000000199c61d80e579e1c0ad76c808fddd6dc4e6eb6307be56d546000001cf00000000475a049ff4e4b6166c3c2b3220f5b6d780ade3043ac84e8a8400f4ed138d8d1e4e37a4e91a08e1e500000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000080020000","hash1":"00000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000010000"}}
		uut.midstate = 256'h635ef71f2ce00832a4b416afc1945ba0d775d72163ab4d6815c08d6e1620437b;
		uut.data = 96'he5e1081ae9a4374e1e8d8d13;
		uut.nonce = 32'h195a2c52;
		
        //Midstate: 90f741afb3ab06f1a582c5c85ee7a561912b25a7cd09c060a89b3c2a73a48e22
        //Data: 000000014cc2c57c7905fd399965282c87fe259e7da366e035dc087a0000141f000000006427b6492f2b052578fb4bc23655ca4e8b9e2b9b69c88041b2ac8c771571d1be4de695931a2694217a33330e000000800000000000000000000000000000000000000000000000000000000000000000000000000000000080020000
        //NONCE: 32'h0e33337a == 238,236,538
		//uut.midstate_buf = 256'h228ea4732a3c9ba860c009cda7252b9161a5e75ec8c582a5f106abb3af41f790;		
		//uut.data_buf[95:0] = 96'h2194261a9395e64dbed17115;
		//uut.nonce = 32'h0e33337a - 2;

        // No golden ticket? Is the input format the same for this (Icarus) serial code?
		//uut.midstate_buf <= 256'h2b3f81261b3cfd001db436cfd4c8f3f9c7450c9a0d049bee71cba0ea2619c0b5;
	    //uut.data_buf[95:0] <= 96'h39f3001b6b7b8d4dc14bfc31;
		//uut.nonce <= 30411740 - 2; // 32'h01d00bdc

		while(cycle<131)
		begin
			#5 clk = 1; #5 clk = 0;
		end
	end

	always @ (posedge clk)
	begin
		cycle <= cycle + 32'd1;
	end

endmodule
