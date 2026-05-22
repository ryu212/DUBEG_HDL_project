module baud_rate_gen (
    input  wire clk_50m,
    input  wire rst_n,
    output reg  ov_tick,     // pulse 1 clock, 921600 Hz
    output reg  uart_tick    // pulse 1 clock, 115200 Hz
);

    // 50e6 / 921600 = 54.253...
    parameter OV_MAX_COUNT = 54;

    reg [5:0] ov_counter;
    reg [2:0] uart_counter;

    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            ov_counter   <= 0;
            uart_counter <= 0;
            ov_tick      <= 1'b0;
            uart_tick    <= 1'b0;
        end
        else begin
            // mặc định: pulse = 0
            ov_tick   <= 1'b0;
            uart_tick <= 1'b0;

            // tạo ov_tick 1 clock
            if (ov_counter == OV_MAX_COUNT - 1) begin
                ov_counter <= 0;
                ov_tick <= 1'b1;

                // cứ 8 ov_tick -> 1 uart_tick
                if (uart_counter == 3'd7) begin
                    uart_counter <= 0;
                    uart_tick <= 1'b1;
                end
                else begin
                    uart_counter <= uart_counter + 1'b1;
                end
            end
            else begin
                ov_counter <= ov_counter + 1'b1;
            end
        end
    end

endmodule