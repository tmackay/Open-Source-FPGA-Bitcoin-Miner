module slave_receive(clk, RxD, nonce, new_nonce);
   // Serial receive buffer for a 4-byte nonce

   parameter comm_clk_frequency = 100_000_000;
   
   input      clk;
   input      RxD;

   wire       RxD_data_ready;
   wire [7:0] RxD_data;

   uart_receiver #(.comm_clk_frequency(comm_clk_frequency)) deserializer(.clk(clk), .RxD(RxD), .RxD_data_ready(RxD_data_ready), .RxD_data(RxD_data));

   // Tell the main hub code that we have new data
   output reg	 new_nonce = 0;
   
   reg [31:0] input_buffer;
   output reg [31:0] nonce;
   reg [2:0]  demux_state = 3'b0;
   
   always @(posedge clk)
     begin
	case (demux_state)
	  3'b100:
	    begin
	       nonce <= input_buffer;
	       demux_state <= 0;
	       new_nonce <= 1;
	    end
	  
	  default:
	    begin
	       new_nonce <= 0;
	       if(RxD_data_ready)
		 begin
		    input_buffer <= input_buffer << 8;
		    input_buffer[7:0] <= RxD_data;
		    demux_state <= demux_state + 1;
		 end
	    end
	endcase // case (demux_state)
     end // always @ (posedge clk)
endmodule // slave_receive
   
// For transmission, we can use the same serial_transmit as the miners
