module uart_rx(
    input  wire       ov_tick,
    input  wire       rst_n,
    input  wire       rx,
    input  wire       rx_clear,
    output reg [7:0]  data_out = 8'b0,
    output reg        rx_valid = 1'b0,
    output wire [1:0] rx_state
);

    parameter TIMEOUT_MAX = 8'd100;
	 localparam IDLE  = 2'b00,
               START = 2'b01,
               DATA  = 2'b10,
               STOP  = 2'b11;

    reg [1:0] state = IDLE, next_state = IDLE;
    reg [2:0] tick_cnt = 3'd0;
    reg [2:0] bit_cnt  = 3'd0;
    reg [2:0] samples  = 3'b000;
    reg [7:0] rx_reg   = 8'b0;
	 reg [7:0] valid_timeout_cnt = 8'd0;

    assign rx_state = state;

    wire voted_bit = (samples[0] & samples[1]) |
                     (samples[1] & samples[2]) |
                     (samples[0] & samples[2]);

    // ==========================================================
    // GIá»® NGUYÃŠN: next state logic
    // ==========================================================
    always @(*) begin
        next_state = state;

        case(state)
            IDLE : if(!rx)                              next_state = START;
            START: if(tick_cnt == 3'd7)                 next_state = DATA;
            DATA : if(tick_cnt == 3'd7 && bit_cnt==7)   next_state = STOP;
            STOP : if(tick_cnt == 3'd7)                 next_state = IDLE;
        endcase
    end

    // ==========================================================
    // CHANGED:
    // - XÃ“A khá»‘i "state register" riÃªng:
    //     always @(posedge ov_tick or negedge rst_n)
    // - Gá»˜P "state <= next_state" vÃ o khá»‘i dÆ°á»›i Ä‘Ã¢y
    // - Giá»¯ nguyÃªn toÃ n bá»™ logic datapath vÃ  rx_valid
    // ==========================================================
    always @(posedge ov_tick or posedge rx_clear or negedge rst_n) begin

        if(!rst_n) begin
            // CHANGED: reset state trong cÃ¹ng always block
            state    <= IDLE;

            rx_valid <= 1'b0;
            tick_cnt <= 3'd0;
            bit_cnt  <= 3'd0;
            samples  <= 3'b000;
            rx_reg   <= 8'd0;
            data_out <= 8'd0;
				valid_timeout_cnt <= 8'd0;
        end
        else if(rx_clear) begin
            rx_valid <= 1'b0;
				valid_timeout_cnt <= 8'd0;
        end
        else begin
            // CHANGED: cáº­p nháº­t state trong cÃ¹ng always block
            state <= next_state;
				if(rx_valid) begin
                if(valid_timeout_cnt >= TIMEOUT_MAX) begin
                    rx_valid <= 1'b0;
                    valid_timeout_cnt <= 8'd0;
                end
                else begin
                    valid_timeout_cnt <= valid_timeout_cnt + 1'b1;
                end
            end
            else begin
                valid_timeout_cnt <= 8'd0;
            end
            // GIá»® NGUYÃŠN logic datapath
            case(state)
                IDLE: begin
                    tick_cnt <= 3'd0;
                    bit_cnt  <= 3'd0;
                end

                START:
                    tick_cnt <= tick_cnt + 1'b1;

                DATA: begin
                    if(tick_cnt == 3'd3) samples[0] <= rx;
                    if(tick_cnt == 3'd4) samples[1] <= rx;
                    if(tick_cnt == 3'd5) samples[2] <= rx;

                    if(tick_cnt == 3'd7) begin
                        tick_cnt <= 3'd0;
                        rx_reg <= {voted_bit, rx_reg[7:1]};

                        if(bit_cnt == 3'd7)
                            bit_cnt <= 3'd0;
                        else
                            bit_cnt <= bit_cnt + 1'b1;
                    end
                    else begin
                        tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if(tick_cnt != 3'd7) begin
                        tick_cnt <= tick_cnt + 1'b1;
                    end
                    else begin
								rx_valid <= 1'b1;
                        data_out <= rx_reg;
                        tick_cnt <= 3'd0;
                    end
                end
            endcase
        end
    end

endmodule