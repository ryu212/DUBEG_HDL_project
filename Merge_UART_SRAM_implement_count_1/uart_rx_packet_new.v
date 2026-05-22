module uart_rx_packet_new
(
    input  wire        CLOCK50,
    input  wire        rst_n,
    input  wire        rx_valid,
    input  wire [7:0]  rx_data,
    input  wire        tx_busy,

    output reg         packet_valid,
    output reg [7:0]   tx_data,
    output reg         tx_start,
    output reg         rx_clear,
    input  wire [7:0]  packet_pd_address,
    output wire [7:0]  packet_pd_data,
    output wire [17:0] LEDR
);

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

    localparam TIMEOUT_MAX = 32'd250000;

    reg [3:0]  state;
    reg [3:0]  next_state;
    reg [7:0]  crc;
    reg [7:0]  crc_rec;
    reg [7:0]  byte_cnt;
    reg [31:0] timeout_cnt;
    reg [7:0]  buffer [0:255];

    wire timeout;
    wire [7:0] crc_calc;

    assign timeout = (timeout_cnt >= TIMEOUT_MAX);
    assign crc_calc = crc;
    assign packet_pd_data = buffer[packet_pd_address];

    function [7:0] crc8;
        input [7:0] crc_in;
        input [7:0] data_in;

        reg [7:0] crc_temp;
        reg [7:0] data_temp;
        integer i;

        begin
            crc_temp  = crc_in;
            data_temp = data_in;

            for(i = 0; i < 8; i = i + 1)
            begin
                if(crc_temp[7] ^ data_temp[7])
                    crc_temp = {crc_temp[6:0], 1'b0} ^ 8'h07;
                else
                    crc_temp = {crc_temp[6:0], 1'b0};

                data_temp = {data_temp[6:0], 1'b0};
            end

            crc8 = crc_temp;
        end
    endfunction

    always @(*)
    begin
        next_state = state;

        case(state)
            IDLE:
            begin
                if(rx_valid && rx_data == 8'hAA)
                    next_state = CLEAR_DATA;
            end

            CLEAR_DATA:
            begin
                if(!rx_valid)
                    next_state = DATA;
            end

            DATA:
            begin
                if(timeout)
                    next_state = RECOVERY;
                else if(rx_valid && byte_cnt == 8'd255)
                    next_state = CLEAR_CRC;
                else if(rx_valid)
                    next_state = CLEAR_DATA;
            end

            CLEAR_CRC:
            begin
                if(!rx_valid)
                    next_state = REC_CRC8;
            end

            REC_CRC8:
            begin
                if(timeout)
                    next_state = RECOVERY;
                else if(rx_valid && rx_data != crc_calc)
                    next_state = RECOVERY;
                else if(rx_valid && rx_data == crc_calc)
                    next_state = ACK;
            end

            RECOVERY:
            begin
                next_state = NACK;
            end

            NACK:
            begin
                if(tx_busy)
                    next_state = WAIT_SEND;
                else if(timeout)
                    next_state = CLEAR_IDLE;
            end

            ACK:
            begin
                if(tx_busy)
                    next_state = WAIT_SEND;
                else if(timeout)
                    next_state = CLEAR_IDLE;
            end

            WAIT_SEND:
            begin
                if(!tx_busy)
                    next_state = CLEAR_IDLE;
                else if(timeout)
                    next_state = CLEAR_IDLE;
            end

            CLEAR_IDLE:
            begin
                if(!rx_valid)
                    next_state = IDLE;
            end

            default:
            begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge CLOCK50 or negedge rst_n)
    begin
        if(!rst_n)
        begin
            state        <= IDLE;
            crc          <= 8'hFF;
            crc_rec      <= 8'd0;
            byte_cnt     <= 8'd0;
            timeout_cnt  <= 32'd0;
            rx_clear     <= 1'b0;
            tx_start     <= 1'b0;
            tx_data      <= 8'd0;
            packet_valid <= 1'b0;
        end
        else
        begin
            state <= next_state;

            case(state)
                IDLE:
                begin
                    timeout_cnt  <= 32'd0;
                    byte_cnt     <= 8'd0;
                    rx_clear     <= 1'b0;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;
                end

                CLEAR_DATA:
                begin
                    timeout_cnt  <= 32'd0;
                    rx_clear     <= 1'b1;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;

                    if(byte_cnt == 8'd0)
                        crc <= 8'hFF;
                end

                DATA:
                begin
                    if(rx_valid)
                    begin
                        timeout_cnt <= 32'd0;
                        byte_cnt    <= byte_cnt + 8'd1;
                        buffer[byte_cnt] <= rx_data;
                        crc         <= crc8(crc, rx_data);
                    end
                    else if(!timeout)
                    begin
                        timeout_cnt <= timeout_cnt + 32'd1;
                    end

                    rx_clear     <= 1'b0;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;
                end

                CLEAR_CRC:
                begin
                    timeout_cnt  <= 32'd0;
                    rx_clear     <= 1'b1;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;
                end

                REC_CRC8:
                begin
                    if(rx_valid)
                    begin
                        timeout_cnt <= 32'd0;
                        crc_rec     <= rx_data;
                    end
                    else if(!timeout)
                    begin
                        timeout_cnt <= timeout_cnt + 32'd1;
                    end

                    rx_clear     <= 1'b0;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;
                end

                RECOVERY:
                begin
                    timeout_cnt  <= 32'd0;
                    byte_cnt     <= 8'd0;
                    rx_clear     <= 1'b0;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;
                end

                NACK:
                begin
                    if(!tx_busy && !timeout)
                        timeout_cnt <= timeout_cnt + 32'd1;
                    else
                        timeout_cnt <= 32'd0;

                    byte_cnt     <= 8'd0;
                    rx_clear     <= 1'b0;
                    tx_start     <= 1'b1;
                    tx_data      <= 8'h15;
                    packet_valid <= 1'b0;
                end

                ACK:
                begin
                    if(!tx_busy && !timeout)
                        timeout_cnt <= timeout_cnt + 32'd1;
                    else
                        timeout_cnt <= 32'd0;

                    byte_cnt     <= 8'd0;
                    rx_clear     <= 1'b0;
                    tx_start     <= 1'b1;
                    tx_data      <= 8'h06;
                    packet_valid <= 1'b1;
                end

                WAIT_SEND:
                begin
                    if(tx_busy && !timeout)
                        timeout_cnt <= timeout_cnt + 32'd1;
                    else
                        timeout_cnt <= 32'd0;

                    rx_clear     <= 1'b0;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;
                end

                CLEAR_IDLE:
                begin
                    timeout_cnt  <= 32'd0;
                    byte_cnt     <= 8'd0;
                    rx_clear     <= 1'b1;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;
                end

                default:
                begin
                    state        <= IDLE;
                    timeout_cnt  <= 32'd0;
                    byte_cnt     <= 8'd0;
                    rx_clear     <= 1'b0;
                    tx_start     <= 1'b0;
                    packet_valid <= 1'b0;
                end
            endcase
        end
    end

    assign LEDR[7:0]   = rx_data;
    assign LEDR[8]     = rx_valid;
    assign LEDR[12:9]  = state;
    assign LEDR[13]    = timeout;
    assign LEDR[14]    = tx_busy;
    assign LEDR[15]    = tx_start;
    assign LEDR[16]    = packet_valid;
    assign LEDR[17]    = (crc_calc == crc_rec);

endmodule
