`timescale 1ns/1ps

module parser #(
    localparam BYTE = 8
)(
    input logic clk, rst_n, rx_ready,
    input logic [BYTE-1:0] rx_byte,
    output logic [BYTE-1:0] row_index, col_index, pixel_value,
    output logic led, RGB_wr_en, led_wr_en,
    output logic correct_format
); 

    // localparam MSG_STRT = 8'h7B;  // "{"
    // localparam ROW_LET  = 8'h52;  // "R"
    // localparam COL_LET  = 8'h43;  // "C"
    // localparam VAL_LET  = 8'h56;  // "V"
    // localparam LED_LET  = 8'h4C;  // "L"
    // localparam COMMA    = 8'h2C;  // ","
    // localparam MSG_CLS  = 8'h7D;  // "}"
    localparam ZERO     = 8'h30;  // "0"
    localparam NINE     = 8'h39;  // "9"

    typedef enum logic[4:0] {IDLE, MSG_START, ROW, R1, R2, R3,
                                              COL, C1, C2, C3, 
                                              VAL, V1, V2, V3, RGB_MSG_END
                                              LED, L1, L2, L3, LED_MSG_END} msg_state;
    
    msg_state current_state, next_state;
    logic [15:0][BYTE-1:0] msg;
    logic msg_valid;
    logic [23:0] current_message;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            msg <= '0;
            msg_valid <= 1'b0;
        end else begin
            msg_valid <= rx_ready;                       // check one clock after the shift
            if (rx_ready) msg <= {msg[14:0], rx_byte};   // newest byte at msg[0]
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_index <= '0;
            col_index <= '0;
            pixel_value <= '0;
            correct_format <= '0;
            current_RGB <='0;
        end
        else if (current_state == RGB_MSG_END) begin
            {row_index, col_index, pixel_value} <= current_message;
            RGB_wr_en <='1;
        end
        else if (current_state == LED_MSG_END) begin
            led <= (current_led == )
            wr_en
        end
    end

    always_comb begin
        next_state = IDLE;
        case (current_state)
            IDLE        :  rx_byte == "{"                    ? next_state = MSG_START;
            MSG_START   : begin if (rx_byte == "R")            next_state = ROW;
                              else if (rx_byte == "L")         next_state = LED;
                          end
            ROW         : (rx_byte >= "0" && rx_byte <= "9") ? next_state = R1;
            R1          : (rx_byte >= "0" && rx_byte <= "9") ? next_state = R2;
            R2          : (rx_byte >= "0" && rx_byte <= "9") ? next_state = R3;
            R3          :  rx_byte == "C"                    ? next_state = COL;
            COL         : (rx_byte >= "0" && rx_byte <= "9") ? next_state = C1;
            C1          : (rx_byte >= "0" && rx_byte <= "9") ? next_state = C2;
            C2          : (rx_byte >= "0" && rx_byte <= "9") ? next_state = C3;
            C3          :  rx_byte == "V"                    ? next_state = VAL;
            VAL         : (rx_byte >= "0" && rx_byte <= "9") ? next_state = V1;
            V1          : (rx_byte >= "0" && rx_byte <= "9") ? next_state = V2;
            V2          : (rx_byte >= "0" && rx_byte <= "9") ? next_state = V3;
            V3          :  rx_byte == "}"                    ? next_state = RGB_MSG_END;
            RGB_MSG_END :  rx_byte == "{"                    ? next_state = MSG_START;
            LED         : (rx_byte >= "0" && rx_byte <= "9") ? next_state = L1;
            L1          : (rx_byte >= "0" && rx_byte <= "9") ? next_state = L2;
            L2          : (rx_byte >= "0" && rx_byte <= "9") ? next_state = L3;
            L3          :  rx_byte == "}"                    ? next_state = LED_MSG_END;
            LED_MSG_END :  rx_byte == "{"                    ? next_state = MSG_START;
        endcase
    end
/*
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
                         (msg[9]  == COL_LET) &&
                         (msg[8]  >= ZERO) && (msg[8] <= NINE) && 
                         (msg[7]  >= ZERO) && (msg[7] <= NINE) && 
                         (msg[6]  >= ZERO) && (msg[6] <= NINE) && 
                         (msg[5]  == COMMA) &&
                         (msg[4]  == VAL_LET) &&
                         (msg[3]  >= ZERO) && (msg[3] <= NINE) && 
                         (msg[2]  >= ZERO) && (msg[2] <= NINE) && 
                         (msg[1]  >= ZERO) && (msg[1] <= NINE) && 
                         (msg[0]  == MSG_CLS);
    end
*/
endmodule
