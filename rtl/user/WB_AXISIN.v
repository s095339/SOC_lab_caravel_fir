module WB_AXISIN
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
    output   wire                     ss_tvalid, 
    output   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    output   wire                     ss_tlast, 
    input    wire                     ss_tready 
);

endmodule