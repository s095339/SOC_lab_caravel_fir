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

`default_nettype none
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
    wire decoded;

    reg ready;
    reg [BITS-17:0] delayed_count;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i && decoded; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;
    assign wbs_ack_o = ready;

    // IO
    assign io_out = count;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000; // Unused

    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    /*
    先備知識
    去複習wb的interface 怎麼做read write，上課都有講過，所以有講義可以參考。


    
    目標：把wishbone interface的訊號按照MMIO分給 WB_AXI 和 exem
    (decoder )
    (1) 你需要宣告兩組wb的訊號線，他從input接近來，根據addr的不同，會把訊號分給這兩組，
    一個接給WB_AXI 另一個給 EXEM
    (2) 如果 wb是write的話 根據addr的不同，把他的訊號接給不同的地方
    (3) 如果wb是read的話 根據addr的不同 判斷要傳回給SOC的wb資料是來自 WB_AXI 還是 EXEM 
    (exem)
    (4) 你可能需要修改exem的code 看狀況
    (wb_axi)
    (5) WB_AXI module的訊號 要由你來填入。

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

    //TODO 我們需要更大的decoder
    assign decoded = wbs_adr_i[31:20] == 12'h380 ? 1'b1 : 1'b0;
    

    //*****************************************************//
    // exmen                                               //
    //*****************************************************//

    //TODO 你可能會需要改這邊的code 看你設計
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
    // 0x3800_0000
    bram user_bram (
        .CLK(clk),
        .WE0(wstrb),
        .EN0(valid),
        .Di0(wbs_dat_i),
        .Do0(rdata),
        .A0(wbs_adr_i)
    );

    //*****************************************************//
    //wb_axi                                               //
    //*****************************************************//
    //0x3000_0000
    // TODO 把你宣告給wb_axi的訊號線填進去
    //
    WB_AXI wb_axi(
        //wb
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),
        // Logic Analyzer Signals
        .la_data_in(la_data_in),
        .la_data_out(la_data_out),
        .la_oenb(la_oenb)
    );
endmodule



`default_nettype wire