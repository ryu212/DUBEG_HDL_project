module uart_controller(
    input  wire       clk_50m,   
	 input  wire       rst_n, 
	 input wire 	    rx_clear,
    input  wire       rx,         
    output wire       tx,         
    input  wire [7:0] tx_data_in, 
    input  wire       tx_start,   
    output wire       tx_busy,    
    output wire [7:0] rx_data_out,
    output wire       rx_valid,
    output wire [1:0] rx_state	 
);

    wire ov_tick_net;
    wire uart_tick_net;

    baud_rate_gen brg_inst (
        .clk_50m(clk_50m),
        .ov_tick(ov_tick_net),
        .uart_tick(uart_tick_net),
		  .rst_n(rst_n)
    );

    uart_tx tx_inst (
        .clk_50m(clk_50m),
        .uart_tick(uart_tick_net),
		  .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data_in),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    uart_rx rx_inst (
        .clk_50m(clk_50m),
        .ov_tick(ov_tick_net),
		  .rst_n(rst_n),
        .rx(rx),
        .data_out(rx_data_out),
        .rx_valid(rx_valid),
		  .rx_clear(rx_clear),
		  .rx_state(rx_state)
    );

endmodule
