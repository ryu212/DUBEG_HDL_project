module uart_rx_packet
(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  uart_data,
    input  wire        uart_valid,
    output reg         rx_clear,

    output reg  [7:0]  tx_data,
    output reg         tx_start,
    input  wire        tx_busy,
	 output reg         packet_valid,
	 
	 input  wire [7:0]  packet_pd_address,
    output wire [7:0]  packet_pd_data,

    output reg [17:0]  LEDR,
	 output wire [6:0] HEX0,
		output wire [6:0] HEX1,
		output wire [6:0] HEX2
);

    // =====================================================
    // PACKET FORMAT
    // =====================================================
    // Python sends:
    //   HEADER : AA 55
    //   DATA   : 256 bytes
    //   CRC16  : low byte first, high byte second
    // Response:
    //   ACK    : 0x06
    //   NACK   : 0x15
    // =====================================================

    localparam HEADER1 = 8'hAA;
    localparam HEADER2 = 8'h55;

    localparam IDLE        = 4'd0;
    localparam WAIT_HEADER = 4'd1;
    localparam RECV_DATA   = 4'd2;
    localparam RECV_CRC1   = 4'd3;
    localparam RECV_CRC2   = 4'd4;
    localparam SEND_ACK    = 4'd5;
    localparam SEND_NACK   = 4'd6;
    localparam WAIT_SEND   = 4'd7;
    localparam CLEAR_RX    = 4'd8;
	 localparam RECOVERY    = 4'd9;
	

    // 50 MHz clock: 250000 cycles = about 5 ms
    // If a byte does not arrive within this time while inside a packet,
    // the receiver sends NACK and resets debug flags for easier observation.
    localparam TIMEOUT_MAX = 32'd250000;

    reg [3:0]  state;
    reg [3:0]  next_state;
    reg [3:0]  clear_return_state;

    reg [7:0]  byte_cnt;
    reg [31:0] timeout_cnt;

    reg [15:0] crc_calc;
    reg [15:0] crc_rx;

    reg timeout_error;
    reg crc_error;
    reg ack_seen;
    reg nack_seen;
    reg crc_pass_seen;

    wire timeout;

    assign timeout = (timeout_cnt >= TIMEOUT_MAX);

    // =====================================================
    // CRC16-CCITT
    // Poly = 0x1021, init = 0xFFFF
    // Must match Python crc16_ccitt().
    // =====================================================
    reg [7:0] buffer [0:255];
	 assign packet_pd_data = buffer[packet_pd_address];
	 
    function [15:0] crc16_next;
        input [15:0] crc;
        input [7:0]  data;

        integer k;
        reg [15:0] c;
        reg [7:0]  d;

        begin
            c = crc;
            d = data;

            for (k = 0; k < 8; k = k + 1)
            begin
                if (c[15] ^ d[7])
                    c = {c[14:0], 1'b0} ^ 16'h1021;
                else
                    c = {c[14:0], 1'b0};

                d = {d[6:0], 1'b0};
            end

            crc16_next = c;
        end
    endfunction

    // =====================================================
    // NEXT STATE LOGIC
    // =====================================================

    always @(*)
    begin
        next_state = state;

        case (state)

            IDLE:
            begin
                // Important: clear every received byte.
                // If it is not HEADER1, main FSM will return to IDLE.
                if (uart_valid)
                    next_state = CLEAR_RX;
            end

            WAIT_HEADER:
            begin
                if (timeout)
                    next_state = RECOVERY;
                else if (uart_valid)
                    next_state = CLEAR_RX;
            end

            RECV_DATA:
            begin
                if (timeout)
                    next_state = RECOVERY;
                else if (uart_valid)
                    next_state = CLEAR_RX;
            end

            RECV_CRC1:
            begin
                if (timeout)
                    next_state = RECOVERY;
                else if (uart_valid)
                    next_state = CLEAR_RX;
            end

            RECV_CRC2:
            begin
                if (timeout)
                    next_state = RECOVERY;
                else if (uart_valid)
                    next_state = CLEAR_RX;
            end

            CLEAR_RX:
            begin
                //if (!uart_valid)
                    next_state = clear_return_state;
            end

            SEND_ACK:
            begin
                if (tx_busy)
                    next_state = WAIT_SEND;
            end

            SEND_NACK:
            begin
                if (tx_busy)
                    next_state = WAIT_SEND;
            end

            WAIT_SEND:
            begin
                if (!tx_busy)
                    next_state = IDLE;
					 else
							next_state = CLEAR_RX;
            end
				RECOVERY:
				begin 
					next_state = SEND_NACK;
					if (uart_valid)
                    next_state = CLEAR_RX;
				end
            default:
            begin
                next_state = IDLE;
            end

        endcase
    end

    // =====================================================
    // STATE REGISTER
    // =====================================================

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // =====================================================
    // MAIN FSM
    // =====================================================

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            byte_cnt <= 8'd0;
            timeout_cnt <= 32'd0;

            crc_calc <= 16'hFFFF;
            crc_rx <= 16'd0;

            tx_data <= 8'd0;
            tx_start <= 1'b0;
            rx_clear <= 1'b0;

            timeout_error <= 1'b0;
            crc_error <= 1'b0;
            ack_seen <= 1'b0;
            nack_seen <= 1'b0;
            crc_pass_seen <= 1'b0;
				
				packet_valid <= 1'b0;


            clear_return_state <= IDLE;
        end
        else
        begin
            tx_start <= 1'b0;
            rx_clear <= 1'b0;
				packet_valid <= 1'b0;

            // =================================================
            // TIMEOUT COUNTER
            // =================================================
            if (state == WAIT_HEADER || state == RECV_DATA ||
                state == RECV_CRC1   || state == RECV_CRC2)
            begin
                if (uart_valid)
                    timeout_cnt <= 32'd0;
                else if (!timeout)
                    timeout_cnt <= timeout_cnt + 1'b1;
            end
            else
            begin
                timeout_cnt <= 32'd0;
            end

            case (state)

                IDLE:
                begin
                    byte_cnt <= 8'd0;
                    crc_calc <= 16'hFFFF;
                    crc_rx <= 16'd0;
                    clear_return_state <= IDLE;

                    if (uart_valid)
                    begin
                        if (uart_data == HEADER1)
                        begin
                            // Start a new packet: reset debug LEDs/flags.
                            timeout_error <= 1'b0;
                            crc_error <= 1'b0;
                            ack_seen <= 1'b0;
                            nack_seen <= 1'b0;
                            crc_pass_seen <= 1'b0;

                            clear_return_state <= WAIT_HEADER;
                        end
                        else
                        begin
                            // Trash byte: clear it and stay in IDLE.
                            clear_return_state <= IDLE;
                        end
                    end
                end

                WAIT_HEADER:
                begin
                    if (uart_valid)
                    begin
                        if (uart_data == HEADER2)
                            clear_return_state <= RECV_DATA;
                        else
                            clear_return_state <= RECOVERY;
                    end

                    if (timeout)
                    begin
                        // Internal UART packet timeout.
                        // Reset LED/debug flags first, then show timeout + NACK.
                        timeout_error <= 1'b1;
                        crc_error <= 1'b0;
                        ack_seen <= 1'b0;
                        nack_seen <= 1'b0;
                        crc_pass_seen <= 1'b0;
                    end
                end

                RECV_DATA:
                begin
                    if (uart_valid)
                    begin
                        buffer[byte_cnt] <= uart_data;
								crc_calc <= crc16_next(crc_calc, uart_data);

                        // Receive exactly 256 data bytes: byte_cnt 0..255.
                        if (byte_cnt == 8'd255)
                            clear_return_state <= RECV_CRC1;
                        else
                        begin
                            byte_cnt <= byte_cnt + 1'b1;
                            clear_return_state <= RECV_DATA;
                        end
                    end

                    if (timeout)
                    begin
                        // Reset LED/debug flags to make timeout easy to see.
                        timeout_error <= 1'b1;
                        crc_error <= 1'b0;
                        ack_seen <= 1'b0;
                        nack_seen <= 1'b0;
                        crc_pass_seen <= 1'b0;
                    end
                end

                RECV_CRC1:
                begin
                    if (uart_valid)
                    begin
                        crc_rx[7:0] <= uart_data;
                        clear_return_state <= RECV_CRC2;
                    end

                    if (timeout)
                    begin
                        timeout_error <= 1'b1;
                        crc_error <= 1'b0;
                        ack_seen <= 1'b0;
                        nack_seen <= 1'b0;
                        crc_pass_seen <= 1'b0;
                    end
                end

                RECV_CRC2:
                begin
                    if (uart_valid)
                    begin
                        crc_rx[15:8] <= uart_data;

                        if (crc_calc == {uart_data, crc_rx[7:0]})
                        begin
                            crc_error <= 1'b0;
                            crc_pass_seen <= 1'b1;
                            clear_return_state <= SEND_ACK;
                        end
                        else
                        begin
                            crc_error <= 1'b1;
                            crc_pass_seen <= 1'b0;
                            clear_return_state <= RECOVERY;
                        end
                    end

                    if (timeout)
                    begin
                        timeout_error <= 1'b1;
                        crc_error <= 1'b0;
                        ack_seen <= 1'b0;
                        nack_seen <= 1'b0;
                        crc_pass_seen <= 1'b0;
                    end
                end

                CLEAR_RX:
                begin
                    rx_clear <= 1'b1;
                end

                SEND_ACK:
                begin
					     packet_valid <= 1'b1;

                    ack_seen <= 1'b1;
                    nack_seen <= 1'b0;

                    tx_data <= 8'h06;
                    tx_start <= 1'b1;
                end

                SEND_NACK:
                begin
                    // Reset receiver context after any packet error.
                    clear_return_state <= IDLE;

                    ack_seen <= 1'b0;
                    nack_seen <= 1'b1;

                    tx_data <= 8'h15;
                    tx_start <= 1'b1;
                end
					 RECOVERY:
					 begin 
						      byte_cnt      <= 8'd0;
								 crc_calc      <= 16'hFFFF;
								 crc_rx        <= 16'd0;
								 timeout_cnt   <= 32'd0;
								 timeout_error <= 1'b0;
						       clear_return_state <= SEND_NACK;
					 end
                WAIT_SEND:
                begin
							clear_return_state <= IDLE;
                    // Nothing here. Wait until tx_busy returns to 0,
                    // then next-state logic goes to IDLE.
                end

            endcase
        end
    end

    // =====================================================
    // DEBUG LED
    // =====================================================
    // LEDR[7:0]   : byte counter inside packet
    // LEDR[11:8]  : FSM state
    // LEDR[12]    : internal packet timeout
    // LEDR[13]    : CRC error
    // LEDR[14]    : ACK sent
    // LEDR[15]    : NACK sent
    // LEDR[16]    : CRC passed
    // LEDR[17]    : uart_valid currently high
    // =====================================================

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            LEDR <= 18'd0;
        end
        else
        begin
            LEDR[7:0]   <= byte_cnt;
            LEDR[11:8]  <= state;
            LEDR[12]    <= timeout_error;
            LEDR[13]    <= crc_error;
            LEDR[14]    <= ack_seen;
            LEDR[15]    <= nack_seen;
            LEDR[16]    <= crc_pass_seen;
            LEDR[17]    <= uart_valid;
        end
    end
	 
	 assign packet_pd_data = buffer[packet_pd_address];

endmodule
