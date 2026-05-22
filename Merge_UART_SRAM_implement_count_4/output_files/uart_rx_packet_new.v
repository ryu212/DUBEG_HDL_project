module uart_rx_packet_new
(
    input  wire        CLOCK50,

    input  wire        rx_valid,
    input  wire [7:0]  rx_data,

    input  wire        tx_busy,

    output reg         packet_valid,

    output reg [7:0]   tx_data,
    output reg         tx_start,

    output reg         rx_clear
);

    // =====================================================
    // STATE
    // =====================================================

    localparam IDLE        = 4'd0;
    localparam CLEAR_DATA  = 4'd1;
    localparam DATA        = 4'd2;
    localparam CLEAR_CRC   = 4'd3;
    localparam REC_CRC8    = 4'd4;
    localparam RECOVERY    = 4'd5;
    localparam NACK        = 4'd6;
    localparam ACK         = 4'd7;
    localparam WAIT_SEND   = 4'd8;
    localparam CLEAR_IDLE  = 4'd9;

    reg [3:0] state;
    reg [3:0] next_state;

    // =====================================================
    // REG
    // =====================================================

    reg [7:0]   crc;
    reg [7:0]   crc_rec;

    reg [7:0]   byte_cnt;

    reg [31:0]  timeout_cnt;

    wire timeout;

    assign timeout = (timeout_cnt > 32'd250000);

    // =====================================================
    // CRC8 FUNCTION
    // POLY = x^8 + x^2 + x + 1 = 0x07
    // =====================================================

    function [7:0] crc8;
        input [7:0] crc_in;
        input [7:0] data_in;

        reg [7:0] crc_temp;
        reg [7:0] data_temp;

        integer i;

        begin

            crc_temp  = crc_in;
            data_temp = data_in;

            for(i=0;i<8;i=i+1)
            begin
                if((crc_temp[7] ^ data_temp[7]) == 1'b1)
                    crc_temp = {crc_temp[6:0],1'b0} ^ 8'h07;
                else
                    crc_temp = {crc_temp[6:0],1'b0};

                data_temp = {data_temp[6:0],1'b0};
            end

            crc8 = crc_temp;

        end
    endfunction

    wire [7:0] crc_calc;

    assign crc_calc = crc;

    // =====================================================
    // NEXT STATE
    // =====================================================

    always @(*)
    begin

        next_state = state;

        case(state)

        // =================================================
        // IDLE
        // =================================================

        IDLE:
        begin
            if(rx_valid && rx_data == 8'hAA)
                next_state = CLEAR_DATA;
        end

        // =================================================
        // CLEAR_DATA
        // =================================================

        CLEAR_DATA:
        begin
            if(!rx_valid)
                next_state = DATA;
        end

        // =================================================
        // DATA
        // =================================================

        DATA:
        begin

            if(timeout)
                next_state = RECOVERY;

            else if(rx_valid && byte_cnt == 8'd255)
                next_state = CLEAR_CRC;

            else if(rx_valid && byte_cnt < 8'd255)
                next_state = CLEAR_DATA;

        end

        // =================================================
        // CLEAR CRC
        // =================================================

        CLEAR_CRC:
        begin
            if(!rx_valid)
                next_state = REC_CRC8;
        end

        // =================================================
        // REC CRC8
        // =================================================

        REC_CRC8:
        begin

            if(timeout)
                next_state = RECOVERY;

            else if(rx_valid && rx_data != crc_calc)
                next_state = RECOVERY;

            else if(rx_valid && rx_data == crc_calc)
                next_state = ACK;

        end

        // =================================================
        // RECOVERY
        // =================================================

        RECOVERY:
        begin
            next_state = NACK;
        end

        // =================================================
        // NACK
        // =================================================

        NACK:
        begin
            if(tx_busy)
                next_state = WAIT_SEND;
        end

        // =================================================
        // ACK
        // =================================================

        ACK:
        begin
            if(tx_busy)
                next_state = WAIT_SEND;
        end

        // =================================================
        // WAIT SEND
        // =================================================

        WAIT_SEND:
        begin
            if(!tx_busy)
                next_state = CLEAR_IDLE;
        end

        // =================================================
        // CLEAR IDLE
        // =================================================

        CLEAR_IDLE:
        begin
            if(!rx_valid)
                next_state = IDLE;
        end

        default:
            next_state = IDLE;

        endcase

    end

    // =====================================================
    // FSM
    // =====================================================

    always @(posedge CLOCK50)
    begin

        state <= next_state;

        case(state)

        // =================================================
        // IDLE
        // =================================================

        IDLE:
        begin

            timeout_cnt  <= 32'd0;
            byte_cnt     <= 8'd0;

            rx_clear     <= 1'b0;

            tx_start     <= 1'b0;

            packet_valid <= 1'b0;

        end

        // =================================================
        // CLEAR DATA
        // =================================================

        CLEAR_DATA:
        begin

            timeout_cnt  <= 32'd0;

            byte_cnt     <= byte_cnt;

            rx_clear     <= 1'b1;

            tx_start     <= 1'b0;

            packet_valid <= 1'b0;

            // reset crc only at start packet
            if(state == CLEAR_DATA && byte_cnt == 8'd0)
                crc <= 8'hFF;

        end

        // =================================================
        // DATA
        // =================================================

        DATA:
        begin

            if(rx_valid)
                timeout_cnt <= 32'd0;
            else
                timeout_cnt <= timeout_cnt + 32'd1;

            if(rx_valid)
                byte_cnt <= byte_cnt + 8'd1;

            rx_clear <= 1'b0;

            tx_start <= 1'b0;

            packet_valid <= 1'b0;

            if(rx_valid)
                crc <= crc8(crc, rx_data);

        end

        // =================================================
        // CLEAR CRC
        // =================================================

        CLEAR_CRC:
        begin

            timeout_cnt <= 32'd0;

            byte_cnt <= byte_cnt;

            rx_clear <= 1'b1;

            tx_start <= 1'b0;

            packet_valid <= 1'b0;

        end

        // =================================================
        // REC CRC8
        // =================================================

        REC_CRC8:
        begin

            if(rx_valid)
                timeout_cnt <= 32'd0;
            else
                timeout_cnt <= timeout_cnt + 32'd1;

            rx_clear <= 1'b0;

            tx_start <= 1'b0;

            packet_valid <= 1'b0;

            if(rx_valid)
                crc_rec <= rx_data;

        end

        // =================================================
        // RECOVERY
        // =================================================

        RECOVERY:
        begin

            timeout_cnt <= 32'd0;

            byte_cnt <= 8'd0;

            rx_clear <= 1'b0;

            tx_start <= 1'b0;

            packet_valid <= 1'b0;

        end

        // =================================================
        // NACK
        // =================================================

        NACK:
        begin

            timeout_cnt <= 32'd0;

            byte_cnt <= 8'd0;

            rx_clear <= 1'b0;

            tx_start <= 1'b1;

            tx_data <= 8'h15;

            packet_valid <= 1'b0;

        end

        // =================================================
        // ACK
        // =================================================

        ACK:
        begin

            timeout_cnt <= 32'd0;

            byte_cnt <= 8'd0;

            rx_clear <= 1'b0;

            tx_start <= 1'b1;

            tx_data <= 8'h06;

            packet_valid <= 1'b1;

        end

        // =================================================
        // WAIT SEND
        // =================================================

        WAIT_SEND:
        begin

            timeout_cnt <= 32'd0;

            byte_cnt <= 8'd0;

            rx_clear <= 1'b0;

            tx_start <= 1'b0;

            packet_valid <= 1'b0;

        end

        // =================================================
        // CLEAR IDLE
        // =================================================

        CLEAR_IDLE:
        begin

            timeout_cnt <= 32'd0;

            byte_cnt <= 8'd0;

            rx_clear <= 1'b1;

            tx_start <= 1'b0;

            packet_valid <= 1'b0;

        end

        endcase

    end

endmodule