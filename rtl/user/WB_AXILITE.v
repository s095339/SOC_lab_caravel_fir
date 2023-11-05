
//author: 陳佳詳

module WB_AXILITE
#(
    parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    
     // Wishbone Slave ports (WB MI A)===============
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,
    //axilite ports=================================
    //write(input)--
    input    wire                     awready,
    input    wire                     wready,
    output   wire                     awvalid,
    output   wire [(pADDR_WIDTH-1):0] awaddr,
    output   wire                     wvalid,
    output   wire [(pDATA_WIDTH-1):0] wdata,
    //read(output)---
    input    wire                     arready,
    output   wire                     rready,
    output   wire                     arvalid,
    output   wire [(pADDR_WIDTH-1):0] araddr,
    input    wire                     rvalid,
    input    wire [(pDATA_WIDTH-1):0] rdata
);

endmodule
