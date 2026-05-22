module SRAM_controller
(
    // =========================================
    // USER INTERFACE
    // =========================================
    input  wire [17:0] addr,
    input  wire [15:0] wr_data,

    input  wire        wr_en,
    input  wire        rd_en,

    output wire [15:0] rd_data,

    // =========================================
    // SRAM INTERFACE
    // =========================================
    output wire [17:0] SRAM_ADDR,
    inout  wire [15:0] SRAM_DQ,

    output wire        SRAM_WE_N,
    output wire        SRAM_OE_N,
    output wire        SRAM_CE_N,
    output wire        SRAM_UB_N,
    output wire        SRAM_LB_N
);

    // =====================================================
    // ADDRESS
    // =====================================================
    assign SRAM_ADDR = addr;

    // =====================================================
    // CONTROL SIGNALS
    // =====================================================
    assign SRAM_CE_N = 1'b0;

    assign SRAM_WE_N = ~wr_en;
    assign SRAM_OE_N = ~rd_en;

    assign SRAM_UB_N = 1'b0;
    assign SRAM_LB_N = 1'b0;

    // =====================================================
    // DATA BUS
    // =====================================================
    assign SRAM_DQ = (wr_en) ? wr_data : 16'bz;

    assign rd_data = SRAM_DQ;

endmodule