`timescale 1ns / 1ps

module RX_fsm #(
    parameter int CLKS_PER_BIT = 1736   // system_clk / baud_rate = 100MHz / 57600
)(
    input  logic clk, rst_n,
    input  logic rx,
    output logic [127:0] msg,
    output logic msg_valid // one-cycle pulse: 16 bytes collected, msg is complete
);

localparam int TICKS_RATE = CLKS_PER_BIT/16;   // clocks per 1/16 bit: 1736/16 = 108 (rounded down)

typedef enum logic [2:0] {IDLE, CHECK_START_BIT, SAMPLE_DATA, STOP_BIT, STORE_DATA} state_t;
state_t current_state, next_state;

logic rx_meta, rx_sync, rx_prev; // 2-FF synchronizer + previous value (edge detect)
logic [$clog2(TICKS_RATE)-1:0] baud_rate_cntr; // counts TICKS_RATE clock cycles
logic baud_tick; // pulse every 1/16 bit
logic [3:0] ticks16_cntr; // 16 ticks per bit (free running)
logic [2:0] bits_cntr; // data bits sampled: 0..7
logic [3:0] bytes_to_msg_cntr;// valid bytes collected for the current message: 0..15
logic [7:0] shift_reg_byte; // current byte
logic [127:0] shift_reg_msg;  // sliding window of the last 16 bytes
logic [2:0] start_samples; // samples at ticks 6,7,8 of the start bit

// 2-FF synchronizer for the asynchronous rx input
always_ff @(posedge clk) begin
    if (!rst_n)
        {rx_meta, rx_sync, rx_prev} <= 3'b111;   // high = line idle
    else begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
        rx_prev <= rx_sync;
    end
end

// Baud tick generator: held in reset while IDLE, so it starts aligned to the start-bit edge
always_ff @(posedge clk) begin
    if (!rst_n || current_state == IDLE) begin
        baud_rate_cntr <= '0;
        baud_tick  <= 1'b0;
    end else if (baud_rate_cntr == TICKS_RATE-1) begin
        baud_rate_cntr <= '0;
        baud_tick <= 1'b1;
    end else begin
        baud_rate_cntr <= baud_rate_cntr + 1'b1;
        baud_tick <= 1'b0;
    end
end

// Sequential: state + datapath
always_ff @(posedge clk) begin
    if (!rst_n) begin
        current_state <= IDLE;
        ticks16_cntr <= '0;
        bits_cntr <= '0;
        shift_reg_byte <= '0;
        shift_reg_msg <= '0;
        start_samples <= 3'b111;
        bytes_to_msg_cntr <= '0;
        msg_valid <= 1'b0;
    end else begin
        current_state <= next_state;
        msg_valid <= 1'b0;   // default: pulse lasts one clock cycle

        case (current_state)
            IDLE: begin
                ticks16_cntr  <= '0;
                bits_cntr <= '0;
                start_samples <= 3'b111;   // "not valid" until 3 real samples arrive
            end

            CHECK_START_BIT: if (baud_tick) begin
                ticks16_cntr <= ticks16_cntr + 1'b1;
                if (ticks16_cntr >= 4'd6 && ticks16_cntr <= 4'd8)
                    start_samples <= {start_samples[1:0], rx_sync};
            end

            SAMPLE_DATA: if (baud_tick) begin
                ticks16_cntr <= ticks16_cntr + 1'b1;  // wraps 15 -> 0
                if (ticks16_cntr == 4'd7) begin // middle of the bit
                    shift_reg_byte <= {rx_sync, shift_reg_byte[7:1]}; // LSB first
                    bits_cntr <= bits_cntr + 1'b1;
                end
            end

            STOP_BIT: if (baud_tick) begin
                ticks16_cntr <= ticks16_cntr + 1'b1;
            end

            STORE_DATA: begin
                shift_reg_msg <= {shift_reg_msg[119:0], shift_reg_byte}; // first byte ends at [127:120]
                if (bytes_to_msg_cntr == 4'd15) begin
                    bytes_to_msg_cntr <= '0;
                    msg_valid  <= 1'b1;   // 16th byte enters now, so msg is complete when this is high
                end else begin
                    bytes_to_msg_cntr <= bytes_to_msg_cntr + 1'b1;
                end
            end

            default: ;
        endcase
    end
end

// Combinational: next-state
always_comb begin
    next_state = current_state;
    unique case (current_state)
        IDLE:
            if (rx_prev && !rx_sync) // falling edge = start bit
                next_state = CHECK_START_BIT;

        CHECK_START_BIT:
            if (baud_tick && ticks16_cntr == 4'd9)
                next_state = (start_samples == 3'b000) ? SAMPLE_DATA : IDLE;  // else glitch

        SAMPLE_DATA:
            if (baud_tick && ticks16_cntr == 4'd7 && bits_cntr == 3'd7)
                next_state = STOP_BIT; // 8th data bit

        STOP_BIT:
            if (baud_tick && ticks16_cntr == 4'd7) // middle of the stop bit
                next_state = rx_sync ? STORE_DATA : IDLE; // 0 = framing error

        STORE_DATA:
            next_state = IDLE;

        default:
            next_state = IDLE;
    endcase
end

assign msg = shift_reg_msg;

endmodule