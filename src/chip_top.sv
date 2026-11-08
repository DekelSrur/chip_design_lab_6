`timescale 1ns/1ps

module chip_top#(
    parameter CLKS_PER_BIT = pkg_lab6::CLKS_PER_BIT,   //from package
    parameter DEBOUNCE_CYCLES = 1_000_000,  //debounce window: 10 ms
    parameter DELAY_50MS = 5_000_000,
    parameter DELAY_100MS = 10_000_000,
    parameter DELAY_200MS = 20_000_000,
    parameter REFRESH_DIV = 25_000          //100 MHz / 25,000 = 4 kHz -> 500 Hz per digit    
)(
    input logic clk,
    input logic cpu_resetn,
    input logic btnc,
    input logic [15:0] sw,                  //0 = TX mode, 1 = RX mode
    input logic uart_rxd,                   //serial line from the PC

    output logic uart_txd,                  //serial line to the PC
    output logic led,                       //LED[0] toggles on every TX data byte
    output logic led15,                     //LED[15] RX/TX mode indicator (1 = RX)
    output logic [7:0]  an,
    output logic [6:0]  seg,
    output logic dp
);

//input signals
    logic rst_n;
    logic btnc_s;
    logic btn_db;
    logic [15:0] sw_s;
    logic [15:0] sw_db;
    logic rxd_s;                            //synchronized uart rx line
    logic rx_mode;                          //sw_db[15]: 0 = TX mode, 1 = RX mode
    // TX path
    logic start;
    logic busy;
    logic [7:0] byte_val;
    logic [1:0] speed_sel, count_sel;
    logic tx_start;
    logic tx_busy;
    logic tx_done;
    logic [7:0] tx_data;
    logic [8:0] rows_sent;
    logic [16:0] bytes_sent;
    // RX path
    logic [127:0] msg;
    logic msg_valid;
    logic [7:0] row_idx, col_idx, pix_val;
    // display
    logic [31:0] digits;
    logic [7:0] dps;

//mode select
    assign rx_mode = sw_db[15];             //debounced mode switch
   // assign rx_en = rx_mode & ~busy;         //RX starts only after a running TX transfer ends
    assign led15 = rx_mode;

//input conditioning    
    sync u_sync (
        .clk(clk), .cpu_resetn(cpu_resetn), .btnc(btnc), .sw(sw), .uart_rxd(uart_rxd),
        .rst_n(rst_n), .btnc_s(btnc_s), .sw_s(sw_s), .rxd_s(rxd_s)
    );

    debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_debouncer (
        .clk(clk), .rst_n(rst_n), .btn_in(btnc_s), .sw_in(sw_s),
        .btn_db(btn_db), .sw_db(sw_db)
    );

    cfg_latch u_cfg_latch (
        .clk(clk), .rst_n(rst_n), .btn_db(btn_db), .busy(busy), .rx_mode(rx_mode), .sw_db(sw_db[14:0]),
        .start(start), .byte_val(byte_val), .speed_sel(speed_sel), .count_sel(count_sel)
    );

//tx path
    tx_fsm #(
        .DELAY_50MS(DELAY_50MS), .DELAY_100MS(DELAY_100MS), .DELAY_200MS(DELAY_200MS)
    ) u_tx_fsm (
        .clk(clk), .rst_n(rst_n), .start(start), .byte_val(byte_val),
        .speed_sel(speed_sel), .count_sel(count_sel), .tx_done(tx_done),
        .tx_start(tx_start), .tx_data(tx_data), .led(led), .busy(busy),
        .rows_sent(rows_sent), .bytes_sent(bytes_sent)
    );

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_uart_tx (
        .clk(clk), .rst_n(rst_n), .tx_start(tx_start), .tx_data(tx_data),
        .tx(uart_txd), .tx_busy(tx_busy), .tx_done(tx_done)
    );

//rx path
    RX_fsm #( .CLKS_PER_BIT(CLKS_PER_BIT)) 
    u_RX_fsm ( .clk(clk), .rst_n(rst_n), .rx(rxd_s), 
               .msg(msg), .msg_valid(msg_valid)
    );

    parser u_parser (
        .clk(clk), .rst_n(rst_n), .msg_valid(msg_valid), .rx_message(msg), .row_index(row_idx),
        .col_index(col_idx), .pixel_value(pix_val), .correct_format()
    );

//display
    display_mux u_display_mux (
        .rx_mode(rx_mode),
        .byte_val(byte_val), .speed_sel(speed_sel), .count_sel(count_sel), .rows_sent(rows_sent),
        .row_idx(row_idx), .col_idx(col_idx), .pix_val(pix_val),
        .digits(digits), .dps(dps)
    );

    seg7_ctrl #(.REFRESH_DIV(REFRESH_DIV)) u_seg7_ctrl(
    .clk(clk), .rst_n(rst_n), .rx_mode(rx_mode), .digits(digits), 
    .dps(dps), .an(an), .seg(seg), .dp(dp)
    );


endmodule
