module uart_tx(
    input  wire       clk_50m,
    input  wire       uart_tick,
	 input  wire 		 rst_n, 
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx = 1'b1,
    output wire        tx_busy
);

    localparam IDLE  = 2'b00,
               START = 2'b01,
               DATA  = 2'b10,
               STOP  = 2'b11;
    reg [1:0] state = IDLE;
	 reg [1:0] next_state = IDLE;
    reg [7:0] tx_reg = 8'b0;
    reg [2:0] bit_cnt = 3'd0;

    always @(posedge clk_50m or negedge rst_n)
		begin
			 if(!rst_n)
				  state <= IDLE;
			 else if(uart_tick)
				  state <= next_state;
		end

    always @(*) begin
        next_state = state;
        case(state)
            IDLE : if(tx_start)         next_state = START;
            START:                      next_state = DATA;
            DATA : if(bit_cnt >= 3'd7) next_state = STOP;
            STOP :                      next_state = IDLE;
        endcase
    end

    // output + datapath
    always @(posedge clk_50m or negedge rst_n) begin
			if(!rst_n) begin
				 tx       <= 1'b1;
				 tx_reg   <= 8'd0;
				 bit_cnt  <= 3'd0;

			end
			else if(uart_tick) begin
        case(state)
            IDLE: begin
                tx <= 1'b1;
                
                bit_cnt <= 3'd0;
            end
            START: begin
                tx <= 1'b0;
					 tx_reg <= tx_data;
					  
				end
            DATA: begin
                tx <= tx_reg[0];
                tx_reg <= {1'b0, tx_reg[7:1]};
                bit_cnt <= bit_cnt + 1'b1;
            end
            STOP:
				begin 
                tx <= 1'b1;
					 
			   end
        endcase
		  end
    end
	 
	 
	 assign tx_busy = (state != IDLE);
	 
	 

endmodule
