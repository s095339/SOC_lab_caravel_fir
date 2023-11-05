module WB_AXISOUT
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    // Wishbone Slave ports (WB MI A)
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
    // axis interfacce
    input   wire                     sm_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] sm_tdata, 
    input   wire                     sm_tlast, 
    output  wire                     sm_tready
);

endmodule