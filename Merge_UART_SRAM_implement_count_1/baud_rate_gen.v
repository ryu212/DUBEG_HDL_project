module baud_rate_gen (
    input  wire clk_50m,
    input  wire rst_n,
    output reg  ov_tick,     // pulse 1 clock, 16x UART baud
    output reg  uart_tick    // pulse 1 clock, 115200 Hz
);

    // 50e6 / (115200 * 16) = 27.126...
    parameter OV_MAX_COUNT = 27;

    reg [5:0] ov_counter;
    reg [3:0] uart_counter;

    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            ov_counter   <= 0;
            uart_counter <= 0;
            ov_tick      <= 1'b0;
            uart_tick    <= 1'b0;
        end
        else begin
            ov_tick   <= 1'b0;
            uart_tick <= 1'b0;

            if (ov_counter == OV_MAX_COUNT - 1) begin
                ov_counter <= 0;
                ov_tick <= 1'b1;

                if (uart_counter == 4'd15) begin
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
