module slave_receive(clk, RxD, nonce, new_nonce, reset);
   // Serial receive buffer for a 4-byte nonce

   input      clk;
   input      RxD;

   wire       RxD_data_ready;
   wire [7:0] RxD_data;

   async_receiver deserializer(.clk(clk), .RxD(RxD), .RxD_data_ready(RxD_data_ready), .RxD_data(RxD_data));

   output [31:0] nonce;

   // Tell the main hub code that we have new data
   output 	 new_nonce;
   reg 		 data_ready = 0;
   assign new_nonce = data_ready;
   
   reg [31:0] input_buffer;
   reg [31:0] input_copy;
   reg [2:0]  demux_state = 3'b0;

   assign nonce = input_copy;

   // As in serial.v
   input      reset;
   
   always @(posedge clk)
     begin
	if (reset) demux_state <= 0;
     
	case (demux_state)
	  3'b100:
	    begin
	       input_copy <= input_buffer;
	       demux_state <= 0;
	       data_ready <= 1;
	    end
	  
	  default:
	    begin
	       data_ready <= 0;
	       if(RxD_data_ready)
		 begin
		    input_buffer <= input_buffer << 8;
		    input_buffer[7:0] <= RxD_data;
		    demux_state <= demux_state + 1;
		 end
	    end
	endcase // case (demux_state)
     end // always @ (posedge clk)
   
endmodule // serial_receive

// For transmission, we can use the same serial_transmit as the miners