module top_test_uart (
    input  wire        CLOCK_50,

    // KEY[1] reset active low
    input  wire [1:0]  KEY,

    // UART
    input  wire        UART_RXD,
    output wire        UART_TXD,

    // Debug
    output wire [3:0]  state_led,
    output wire        rx_valid_led,
    output wire        tx_busy_led,
	 
	 //SRAM CHIP 
		inout  wire [15:0] SRAM_DQ,
		output wire [17:0] SRAM_ADDR,

		output wire        SRAM_WE_N,
		output wire        SRAM_OE_N,
		output wire        SRAM_CE_N,
		output wire        SRAM_UB_N,
		output wire        SRAM_LB_N,
    output wire [17:0] LEDR,
    output wire [7:0] LEDG,
	  output wire [6:0] HEX0,
	  output wire [6:0] HEX1,
	  output wire [6:0] HEX2,
	  output wire [6:0] HEX6,
	  output wire [6:0] HEX7
 );

    // =====================================================
    // RESET
    // =====================================================

    wire rst_n;

    assign rst_n = KEY[1];

    // =====================================================
    // UART WIRES
    // =====================================================

    wire [7:0] rx_data;
    wire       rx_valid;
    wire [1:0] rx_state;

    wire       tx_busy;

    wire       rx_clear;

    wire [7:0] tx_data;
    wire       tx_start;

    wire       packet_valid;
    // ADD new information here
	 wire [7:0]  packet_pd_address;
	 wire [7:0]  packet_pd_data;
	 wire [17:0] sram_addr;
	 wire [15:0] sram_wr_data;
	 wire        sram_wr_en;
	 wire        write_finish;
	 wire [7:0]  debug_crc_calc;
	 
	 // For ram:
	 wire [15:0] sram_rd_data;
	 // =====================================
	 reg        packet_valid_d = 1'b0;
		reg [11:0] packet_cnt     = 12'd0;

		always @(posedge CLOCK_50 or negedge rst_n) begin
			 if(!rst_n) begin
				  packet_valid_d <= 1'b0;
				  packet_cnt     <= 12'd0;
			 end
			 else begin
				  // delay 1 clock Ã„â€˜Ã¡Â»Æ’ bÃ¡ÂºÂ¯t cÃ¡ÂºÂ¡nh lÃƒÂªn
				  packet_valid_d <= packet_valid;

				  // posedge detect
				  if(packet_valid && !packet_valid_d)
						packet_cnt <= packet_cnt + 1'b1;
			 end
		end
	 // =====================================
	 
    // =====================================================
    // UART CONTROLLER
    // =====================================================

    uart_controller uart_ctrl_inst
    (
        .clk_50m     (CLOCK_50),
        .rst_n       (rst_n),

        .rx_clear    (rx_clear),

        .rx          (UART_RXD),
        .tx          (UART_TXD),

        .tx_data_in  (tx_data),
        .tx_start    (tx_start),
        .tx_busy     (tx_busy),

        .rx_data_out (rx_data),
        .rx_valid    (rx_valid),
        .rx_state    (rx_state)
    );

    // =====================================================
    // UART PACKET FSM
    // =====================================================

    uart_rx_packet_new packet_inst
	(
		 .CLOCK50          (CLOCK_50),
		 .rst_n            (rst_n),
		 .rx_valid         (rx_valid),
		 .rx_data          (rx_data),
		 .tx_busy          (tx_busy),
		 .packet_valid     (packet_valid),
		 .tx_data          (tx_data),
		 .tx_start         (tx_start),
		 .rx_clear         (rx_clear),
		 .packet_pd_address(packet_pd_address),
		 .packet_pd_data   (packet_pd_data),
		 .LEDR             (LEDR),
		 .debug_flags      (LEDG),
		 .debug_crc_calc   (debug_crc_calc)
	);
	 // ==========================
	 // SRAM WRITER
	 // ==========================
    sram_packet_writer sram_writer_inst
		(
			 .clk               (CLOCK_50),
			 .rst_n             (rst_n),
			 .packet_pd_data    (packet_pd_data),
			 .packet_valid      (packet_valid),
			 .addr              (sram_addr),
			 .wr_data           (sram_wr_data),
			 .wr_en             (sram_wr_en),
			 .write_finish      (write_finish),
			 .packet_pd_address (packet_pd_address)
		);
	 // ==========================
	 // SRAM CONTROLLER
	 // ==========================

	 SRAM_controller sram_ctrl_inst
	 (
		  // USER INTERFACE
		 .addr       (sram_addr),
		 .wr_data    (sram_wr_data),

		 .wr_en      (sram_wr_en),
		 .rd_en      (1'b0),

		 .rd_data    (sram_rd_data),

		 // SRAM INTERFACE
		 .SRAM_ADDR  (SRAM_ADDR),
		 .SRAM_DQ    (SRAM_DQ),

		 .SRAM_WE_N  (SRAM_WE_N),
		 .SRAM_OE_N  (SRAM_OE_N),
		 .SRAM_CE_N  (SRAM_CE_N),
		 .SRAM_UB_N  (SRAM_UB_N),
		 .SRAM_LB_N  (SRAM_LB_N)
	);	
    // =====================================================
    // DEBUG LED
    // =====================================================

    assign state_led    = {2'b00, rx_state};

    assign rx_valid_led = rx_valid;

    assign tx_busy_led  = tx_busy;
	 
	 hex7seg hex0_inst(
		 .bin(packet_cnt[3:0]),
		 .seg(HEX0)
	);

	hex7seg hex1_inst(
		 .bin(packet_cnt[7:4]),
		 .seg(HEX1)
	);

	hex7seg hex2_inst(
		 .bin(packet_cnt[11:8]),
		 .seg(HEX2)
	);

	hex7seg hex6_inst(
		 .bin(debug_crc_calc[3:0]),
		 .seg(HEX6)
	);

	hex7seg hex7_inst(
		 .bin(debug_crc_calc[7:4]),
		 .seg(HEX7)
	);



endmodule
