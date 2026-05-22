module sram_packet_writer
(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  packet_pd_data,
    input  wire        packet_valid,

    output wire [17:0] addr,
    output wire [15:0] wr_data,
    output reg         wr_en,
    output reg         write_finish,

    output wire [7:0]  packet_pd_address
);

    // =====================================================
    // STATE DECLARATION
    // =====================================================

    localparam IDLE         = 3'd0;
    localparam WRITE_DATA_1 = 3'd1;
    localparam WRITE_DATA_2 = 3'd2;
    localparam SRAM_WRITE   = 3'd3;
    localparam UPDATE       = 3'd4;
    localparam FINISH       = 3'd5;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // =====================================================
    // REG DECLARATION
    // =====================================================

    reg        packet_valid_d;

    reg [9:0]  packet_cnt;

    reg [17:0] addr_latch;

    reg [7:0]  word_index;

    reg [7:0]  data_low;

    reg [15:0] w_data;

    reg [7:0]  packet_pd_address_latch;

    // =====================================================
    // WIRE DECLARATION
    // =====================================================

    wire packet_valid_posedge;

    // =====================================================
    // ASSIGN
    // =====================================================

    assign packet_pd_address = packet_pd_address_latch;

    assign addr    = addr_latch;

    assign wr_data = w_data;

    // =====================================================
    // EDGE DETECT
    // =====================================================
    assign packet_valid_posedge = packet_valid & ~packet_valid_d;
    // =====================================================
    // DELAY packet_valid
    // =====================================================

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            packet_valid_d <= 1'b0;
        else
            packet_valid_d <= packet_valid;
    end

    // =====================================================
    // STATE REGISTER
    // =====================================================

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // =====================================================
    // NEXT STATE LOGIC
    // =====================================================

    always @(*)
    begin
        next_state = current_state;

        case(current_state)

            IDLE:
            begin
                if(packet_valid_posedge)
                    next_state = WRITE_DATA_1;
                else
                    next_state = IDLE;
            end

            WRITE_DATA_1:
            begin
                next_state = WRITE_DATA_2;
            end

            WRITE_DATA_2:
            begin
                next_state = SRAM_WRITE;
            end

            SRAM_WRITE:
            begin
                if(packet_pd_address_latch == 8'd255)
                    next_state = UPDATE;
                else
                    next_state = WRITE_DATA_1;
            end

            UPDATE:
            begin
                if(packet_cnt < 10'd599)
                    next_state = IDLE;
                else
                    next_state = FINISH;
            end

            FINISH:
            begin
                next_state = FINISH;
            end

            default:
            begin
                next_state = IDLE;
            end

        endcase
    end

    // =====================================================
    // MOORE OUTPUT LOGIC
    // =====================================================

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            wr_en                    <= 1'b0;
            write_finish             <= 1'b0;

            packet_cnt               <= 10'd0;

            addr_latch               <= 18'd0;

            word_index               <= 8'd0;

            data_low                 <= 8'd0;

            w_data                   <= 16'd0;

            packet_pd_address_latch  <= 8'd0;
        end
        else
        begin
            // =============================================
            // DEFAULT
            // =============================================

            wr_en        <= 1'b0;

            // =============================================
            // STATE ACTION
            // =============================================

            case(current_state)

                // =========================================
                // IDLE
                // =========================================

                IDLE:
                begin
                    wr_en        <= 1'b0;
                    write_finish <= 1'b0;
                end

                // =========================================
                // WRITE_DATA_1
                // =========================================

                WRITE_DATA_1:
                begin
                    data_low <= packet_pd_data;

                    wr_en <= 1'b0;

                    packet_pd_address_latch
                        <= packet_pd_address_latch + 8'd1;
                end

                // =========================================
                // WRITE_DATA_2
                // =========================================

                WRITE_DATA_2:
                begin
                    w_data <= {packet_pd_data, data_low};

                    wr_en <= 1'b0;

                    packet_pd_address_latch
                        <= packet_pd_address_latch + 8'd1;

                    addr_latch <= (packet_cnt << 7) + word_index;
                end

                // =========================================
                // SRAM_WRITE
                // =========================================

                SRAM_WRITE:
                begin
                    wr_en <= 1'b1;

                    word_index <= word_index + 8'd1;
                end

                // =========================================
                // UPDATE
                // =========================================

                UPDATE:
                begin
                    packet_pd_address_latch <= 8'd0;

                    packet_cnt <= packet_cnt + 10'd1;

                    word_index <= 8'd0;
                end

                // =========================================
                // FINISH
                // =========================================

                FINISH:
                begin
                    wr_en <= 1'b0;

                    write_finish <= 1'b1;
                end

                default:
                begin
                    wr_en        <= 1'b0;
                    write_finish <= 1'b0;
                end

            endcase
        end
    end

endmodule