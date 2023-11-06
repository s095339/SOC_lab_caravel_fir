// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype wire
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

`define MPRJ_IO_PADS_1 19	/* number of user GPIO pads on user1 side */
`define MPRJ_IO_PADS_2 19	/* number of user GPIO pads on user2 side */
`define MPRJ_IO_PADS (`MPRJ_IO_PADS_1 + `MPRJ_IO_PADS_2)

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10
)(
`ifdef USE_POWER_PINS
    inout vccd1, // User area 1 1.8V supply
    inout vssd1, // User area 1 digital ground
`endif

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

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    wire [31:0] rdata; 
    wire [31:0] wdata;
    wire [BITS-1:0] count;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;
    reg  [1:0] decoded;

    reg  ready;
    reg  [BITS-17:0] delayed_count;
    reg  [31:0] merged_output_data;
    wire [31:0] BRAM_Do;
    wire [31:0] output_data_WB_FIR;
        
    reg merged_output_ACK;
    wire wbs_ack_BRAM;
    wire wbs_ack_WB_FIR;

    wire [3:0] BRAM_WE; // wstrb in lab4-1
    
    wire wbs_we_BRAM;
    wire wbs_we_WB_FIR;
    
    assign wbs_we_BRAM=wbs_we_i;
    assign wbs_we_WB_FIR=wbs_we_i;

    wire [3:0] wbs_sel_BRAM;
    wire [3:0] wbs_sel_WB_FIR;


    wire [31:0] BRAM_adr;
    wire [31:0] WB_FIR_adr; 

    
    wire [31:0] BRAM_Di;
    wire [31:0] WB_FIR_Di;


    reg wbs_stb_BRAM;
    reg wbs_cyc_BRAM;
    reg WB_FIR_stb;
    reg WB_FIR_cyc;

    /////////////////////sub module//////////////////////////////////
    bram user_bram (
        .CLK(clk),
        .WE0(BRAM_WE),
        .EN0(valid),
        .Di0(BRAM_Di),
        .Do0(BRAM_Do),
        .A0 (BRAM_adr)
    );

    //0x3000_0000
/*
    WB_AXI wb_axi(
        //wb
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wbs_stb_i(WB_FIR_stb),
        .wbs_cyc_i(WB_FIR_cyc),
        .wbs_we_i(wbs_we_WB_FIR),
        .wbs_sel_i(wbs_sel_WB_FIR),
        .wbs_dat_i(WB_FIR_Di),
        .wbs_adr_i(WB_FIR_adr),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),
        // Logic Analyzer Signals
        .la_data_in(la_data_in),
        .la_data_out(la_data_out),
        .la_oenb(la_oenb)
    );
*/

    //////////////////////////////////////////////////////////////////////////////////////

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i && (decoded==2'd2); //decode==2'd2 為0x380
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;


    // IO
    assign io_out = merged_output_data;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000; // Unused
    
    ////////////////////////// interface output //////////////////////////
    assign wbs_dat_o = merged_output_data;


    // LA
    assign la_data_out = {{(127-BITS){1'b0}},  merged_output_data};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

 
    /*
    test
    在提交給你的版本中，我會透過韌體 送一筆資料 0xAB990000 給0x30000000
    如果你的code是正確的(wb_write的部份) 你打開波形圖，去看你送給user project的訊號
    應該就會看到一個0x30000000的addr 和 0xAB990000的data 然後卡在這裡
    這時候 去把counter_la_fir.c的第131行註解掉，他會是一個(*(volatile uint32_t*)開頭的東西
    然後再跑一次run_sim 然後打開波形圖，testbench的check bit訊號
    如果你有看到check bit在後面從0數到A 然後輸出AB51 那代表你的exem也OK了

    你要確定你寫的東西是有可讀性的。
                                    ┌───────────┐
        ┌───────────┐       ┌──────>│  wb_axi   │
        │           │       │       └───────────┘
    --->│  decoder  │───────┤
    wb  │           │       │       ┌───────────┐
        └───────────┘       └──────>│  exem     │
                                    └───────────┘
    */
    //*****************************************************//
    //Decoder                                              //
    //*****************************************************//

    //decode select
    //12'h380 for BRAM
    //12'h300 for FIR
    always @* begin
        case(wbs_adr_i[31:20])
        12'h380: decoded=2'b10;
        12'h300: decoded=2'b11;
        default: decoded=2'b00;
        endcase
    end


    //*****************************************************//
    // exmen                                               //
    //*****************************************************//

    always @(posedge clk) begin
        if (rst) begin
            ready <= 1'b0;
            delayed_count <= 16'b0;
        end else begin
            ready <= 1'b0;
            if ( valid && !ready ) begin
                if ( delayed_count == DELAYS ) begin
                    delayed_count <= 16'b0;
                    ready <= 1'b1;
                end else begin
                    delayed_count <= delayed_count + 1;
                end
            end
        end
    end

///////////////////////////////// decode /////////////////////////////////

    //stb cyc decode

    always @* begin
        case(decoded)
        2'b10:begin
            wbs_stb_BRAM=wbs_stb_i;
            wbs_cyc_BRAM=wbs_cyc_i;
            WB_FIR_stb=0;
            WB_FIR_cyc=0;
        end
        2'b11:begin
            wbs_stb_BRAM=0;
            wbs_cyc_BRAM=0;
            WB_FIR_stb=wbs_stb_i;
            WB_FIR_cyc=wbs_cyc_i;
        end
        default:begin
            wbs_stb_BRAM=0;
            wbs_cyc_BRAM=0;
            WB_FIR_stb=0;
            WB_FIR_cyc=0;
        end
        endcase
    end

    
    //wbs_adr_i
    assign BRAM_adr   = (decoded==2'b10)?wbs_adr_i:32'd0;
    assign WB_FIR_adr = (decoded==2'b11)?wbs_adr_i:32'd0;

    //wbs_data_in
    assign BRAM_Di    = (decoded==2'b10)?wbs_dat_i:32'd0;
    assign WB_FIR_Di  = (decoded==2'b11)?wbs_dat_i:32'd0;
    
    //decode for merged_output
    always @* begin
        case(decoded)
        2'b10:begin
            merged_output_data = BRAM_Do;
        end
        2'b11:begin
            merged_output_data = output_data_WB_FIR;
        end
        default:begin
            merged_output_data = 0;
        end
        endcase
    end


        //decode for merged_output
    always @* begin
        case(decoded)
        2'b10:begin
            merged_output_ACK  = wbs_ack_BRAM;
        end
        2'b11:begin
            merged_output_ACK  = wbs_ack_WB_FIR;
        end
        default:begin
            merged_output_ACK  = 0;
        end
        endcase
    end

    ////////////////////////// output interface //////////////////////////
    assign wbs_dat_o = merged_output_data;
    assign wbs_ack_o = merged_output_ACK;

    // IO
    assign io_out = merged_output_data;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Not implemented here

    // WB MI A
    assign valid = wbs_cyc_BRAM && wbs_stb_BRAM && (decoded==2'b10); 
    assign BRAM_WE = wbs_sel_BRAM & {4{wbs_we_BRAM}};
    assign wbs_ack_BRAM = ready;
    //wbs_sel
    assign wbs_sel_BRAM=wbs_sel_i;
    assign wbs_sel_WB_FIR=wbs_sel_i;



endmodule



