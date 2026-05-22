module uart_rx(
    input  wire       clk_50m,
    input  wire       ov_tick,
    input  wire       rst_n,
    input  wire       rx,
    input  wire       rx_clear,
    output reg [7:0]  data_out = 8'b0,
    output reg        rx_valid = 1'b0,
    output wire [1:0] rx_state
);

    localparam IDLE  = 2'b00,
               START = 2'b01,
               DATA  = 2'b10,
               STOP  = 2'b11;

    reg [1:0] state    = IDLE;
    reg [3:0] tick_cnt = 4'd0;
    reg [2:0] bit_cnt  = 3'd0;
    reg [7:0] rx_reg   = 8'd0;
    reg       rx_meta  = 1'b1;
    reg       rx_sync  = 1'b1;

    assign rx_state = state;

    always @(posedge clk_50m or negedge rst_n) begin
        if(!rst_n) begin
            state    <= IDLE;
            tick_cnt <= 4'd0;
            bit_cnt  <= 3'd0;
            rx_reg   <= 8'd0;
            data_out <= 8'd0;
            rx_valid <= 1'b0;
            rx_meta  <= 1'b1;
            rx_sync  <= 1'b1;
        end
        else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;

            rx_valid <= 1'b0;

            if(ov_tick) begin
                case(state)
                    IDLE: begin
                        tick_cnt <= 4'd0;
                        bit_cnt  <= 3'd0;

                        if(!rx_sync)
                            state <= START;
                    end

                    START: begin
                        if(tick_cnt == 4'd7) begin
                            if(!rx_sync) begin
                                tick_cnt <= 4'd0;
                                state    <= DATA;
                            end
                            else begin
                                tick_cnt <= 4'd0;
                                state    <= IDLE;
                            end
                        end
                        else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end

                    DATA: begin
                        if(tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            rx_reg   <= {rx_sync, rx_reg[7:1]};

                            if(bit_cnt == 3'd7) begin
                                bit_cnt <= 3'd0;
                                state   <= STOP;
                            end
                            else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                        else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end

                    STOP: begin
                        if(tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            state    <= IDLE;

                            if(rx_sync) begin
                                data_out <= rx_reg;
                                rx_valid <= 1'b1;
                            end
                        end
                        else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end

                    default: begin
                        state    <= IDLE;
                        tick_cnt <= 4'd0;
                        bit_cnt  <= 3'd0;
                    end
                endcase
            end

            if(rx_clear)
                rx_valid <= 1'b0;
        end
    end

endmodule
