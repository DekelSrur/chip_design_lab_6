`timescale 1ns/1ps

module parser #(
    localparam BYTE = 8
)(
    input logic clk, rst_n, msg_valid,
    input logic [16*BYTE-1:0] rx_message,
    output logic [BYTE-1:0] row_index, col_index, pixel_value,
    output logic correct_format
); 

    localparam MSG_STRT = 8'h7B; // "{"
    localparam ROW_LET = 8'h52;  // "R"
    localparam COL_LET = 8'h43;  // "C"
    localparam VAL_LET = 8'h56;  // "V"
    localparam COMMA = 8'h2C;    // ","
    localparam MSG_CLS = 8'h7D;  // "}"
    localparam ZERO = 8'h30;     // "0"
    localparam NINE = 8'h39;     // "9"

    logic [15:0][BYTE-1:0] msg;

    assign msg = rx_message;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_index <= 'b0;
            col_index <= 'b0;
            pixel_value <= 'b0;
        end
        else if (correct_format && msg_valid) begin          
            row_index <= BYTE'(msg[13][3:0])*8'd100 + BYTE'(msg[12][3:0])*8'd10 + BYTE'(msg[11][3:0]);         
            col_index <= BYTE'(msg[8][3:0])*8'd100 + BYTE'(msg[7][3:0])*8'd10 + BYTE'(msg[6][3:0]);  
            pixel_value <= BYTE'(msg[3][3:0])*8'd100 + BYTE'(msg[2][3:0])*8'd10 + BYTE'(msg[1][3:0]);  
        end
    end
    always_comb begin
        correct_format = 'b0;
        correct_format = (msg[15] == MSG_STRT) &&
                        (msg[14] == ROW_LET) &&
                        (msg[13] >= ZERO) && (msg[13] <= NINE) && 
                        (msg[12] >= ZERO) && (msg[12] <= NINE) && 
                        (msg[11] >= ZERO) && (msg[11] <= NINE) && 
                        (msg[10] == COMMA) &&
                        (msg[9] == COL_LET) &&
                        (msg[8] >= ZERO) && (msg[8] <= NINE) && 
                        (msg[7] >= ZERO) && (msg[7] <= NINE) && 
                        (msg[6] >= ZERO) && (msg[6] <= NINE) && 
                        (msg[5] == COMMA) &&
                        (msg[4] == VAL_LET) &&
                        (msg[3] >= ZERO) && (msg[3] <= NINE) && 
                        (msg[2] >= ZERO) && (msg[2] <= NINE) && 
                        (msg[1] >= ZERO) && (msg[1] <= NINE) && 
                        (msg[0] == MSG_CLS);
    end

endmodule
