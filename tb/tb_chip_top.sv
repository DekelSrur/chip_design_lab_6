`timescale 1ns / 1ps

module tb_chip_top;

    localparam CPB = 64;              // clocks per bit in simulation
    localparam T_BIT = CPB * 10;     // one bit = 80 ns

    logic clk = 0, cpu_resetn = 0;
    logic btnc = 0;
    logic [15:0] sw = '0;
    logic uart_rxd = 1;              // UART line idles high
    logic uart_txd, led, led15, dp;
    logic [7:0] an;
    logic [6:0] seg;
    
    int errors = 0;
    int rx_n = 0;

    logic [7:0]  rx_char [3000];     // characters sent by the FPGA
    
    // short times for simulation: debounce 10 clocks, delays 20/40/80 clocks
    chip_top #(.CLKS_PER_BIT(CPB), .DEBOUNCE_CYCLES(10), .DELAY_50MS(20),
               .DELAY_100MS(40), .DELAY_200MS(80), .REFRESH_DIV(4)) dut (
        .clk(clk), .cpu_resetn(cpu_resetn), .btnc(btnc), .sw(sw), .uart_rxd(uart_rxd),
        .uart_txd(uart_txd), .led(led), .led15(led15), .an(an), .seg(seg), .dp(dp));

    always #5 clk = ~clk;

    // stop the simulation if it hangs (for example a wait that never ends)
    initial begin
        #100_000_000;
        $display("tb_chip_top FAILED: timeout");
        $finish;
    end

    // PC receiver: read every character on uart_txd (8N1, LSB first)
    initial begin
        logic [7:0] r;
        forever begin
            @(negedge uart_txd);                // start bit
            #(T_BIT/2);
            for (int i = 0; i < 8; i++) begin   // sample every data bit in its middle
                #(T_BIT);
                r[i] = uart_txd;
            end
            #(T_BIT);                           // stop bit
            rx_char[rx_n] = r;
            rx_n++;
        end
    end

    // press the button (longer than the 100 ns debounce window)
    task automatic press();
        btnc = 1;
        #300;
        btnc = 0;
        #300;
    endtask

    // PC transmitter: send one byte on uart_rxd
    task automatic send_byte(input logic [7:0] b);
        uart_rxd = 0;                           // start bit
        #(T_BIT);
        for (int i = 0; i < 8; i++) begin       // data bits, LSB first
            uart_rxd = b[i];
            #(T_BIT);
        end
        uart_rxd = 1;                           // stop bit
        #(T_BIT);
    endtask

    // send a 16-character message, first character first
    task automatic send_msg(input logic [127:0] msg);
        for (int i = 0; i < 16; i++) begin
            send_byte(msg[127:120]);            // top character
            msg = msg << 8;                     // next character moves to the top
        end
        #(2 * T_BIT);
    endtask

    initial begin
        #100 cpu_resetn = 1;
        #100;

        // test 1: after reset - TX line idle, TX mode
        if (uart_txd !== 1 || led15 !== 0) begin
            $display("Test 1 FAILED");
            errors++;
        end
        else
            $display("Test 1 PASSED: TX line idle, TX mode");

        // test 2: TX, byte 41, N = 1, no delay "41 20 0D 0A", display "01 01 0.0 41"
        sw = 16'b0_00_000_00_0100_0001;         // {mode, count, unused, speed, byte}
        #200;                                   // let the switches pass the debouncer
        press();
        wait (dut.busy == 0);
        #(20 * T_BIT);                          // let the PC receiver read the last character
        if (rx_n !== 4 || rx_char[0] !== 8'h41 || rx_char[1] !== 8'h20 ||
            rx_char[2] !== 8'h0D || rx_char[3] !== 8'h0A || led !== 1) begin
            $display("Test 2 FAILED: %0d chars", rx_n);
            errors++;
        end
        else
            $display("Test 2 PASSED: PC received %h %h %h %h", rx_char[0], rx_char[1], rx_char[2], rx_char[3]);
        if (dut.digits !== 32'h0101_0041) begin // display value inside the design
            $display("Test 2 FAILED: display %h", dut.digits);
            errors++;
        end
        else
            $display("Test 2 PASSED: display %h", dut.digits);

        // test 3: TX, byte 55, N = 32, 50 ms 2112 characters, display "20 20 0.5 55"
        rx_n = 0;
        sw = 16'b0_01_000_01_0101_0101;
        #200;
        press();
        wait (dut.busy == 0);
        #(20 * T_BIT);
        if (rx_n !== 2112 || dut.digits !== 32'h2020_0555) begin
            $display("Test 3 FAILED: %0d chars, display %h", rx_n, dut.digits);
            errors++;
        end
        else
            $display("Test 3 PASSED: %0d chars, display %h", rx_n, dut.digits);

        // test 4: RX mode, valid message display "0C C8 -- FF"
        sw[15] = 1;                             // switch to RX mode
        #200;
        send_msg("{R012,C200,V255}");
        if (led15 !== 1 || dut.digits !== 32'h0CC8_00FF) begin
            $display("Test 4 FAILED: LED15=%b display %h", led15, dut.digits);
            errors++;
        end
        else
            $display("Test 4 PASSED: LED15 on, display %h", dut.digits);

        // test 5: invalid messages - display does not change
        send_msg("{R300,C010,V020}");           // value > 255
        send_msg("{X001,C001,V001}");           // wrong letter
        if (dut.digits !== 32'h0CC8_00FF) begin
            $display("Test 5 FAILED: display %h", dut.digits);
            errors++;
        end
        else
            $display("Test 5 PASSED: invalid messages ignored");

        // test 6: button does not start TX in RX mode
        rx_n = 0;
        press();
        #(20 * T_BIT);
        if (dut.busy !== 0 || rx_n !== 0) begin
            $display("Test 6 FAILED: TX started in RX mode");
            errors++;
        end
        else
            $display("Test 6 PASSED: button ignored in RX mode");

        // test 7: no full duplex - a message sent during a TX transfer is ignored
        sw = 16'b0_01_000_00_0100_0001;         // TX, N = 32
        #200;
        press();
        sw[15] = 1;                             // switch to RX while TX is busy
        #200;
        send_msg("{R100,C100,V100}");           // RX is still off
        wait (dut.busy == 0);
        #(20 * T_BIT);
        if (dut.digits !== 32'h0CC8_00FF) begin
            $display("Test 7 FAILED: message accepted during TX");
            errors++;
        end
        else
            $display("Test 7 PASSED: message ignored during TX");
        send_msg("{R009,C008,V007}");           // TX finished -> RX works
        if (dut.digits !== 32'h0908_0007) begin
            $display("Test 7 FAILED: display %h", dut.digits);
            errors++;
        end
        else
            $display("Test 7 PASSED: message accepted after TX, display %h", dut.digits);

        if (errors == 0) $display("tb_chip_top PASSED");
        else             $display("tb_chip_top FAILED, %0d errors", errors);
        $finish;
    end

endmodule