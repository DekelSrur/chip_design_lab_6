`timescale 1ns/1ps

package pkg_param_ctrl;

    parameter BYTE = 8;
    typedef enum logic[1:0] {IDLE, ACTIVATED, PRESSED} state_t;
    typedef enum logic [4:0] {
                                NOCMND = 5'b00000,
                                RIGHT  = 5'b00001,
                                LEFT   = 5'b00010,
                                DOWN   = 5'b00100,
                                UP     = 5'b01000,
                                CENTER = 5'b10000} buttons_t;
    typedef enum logic [1:0] {T0, T1, T2, T3} digits_t;
    typedef enum logic [7:0] {LEDS13_12 = 8'b11000000, 
                                LEDS10_9  = 8'b00110000, 
                                LEDS8_7   = 8'b00001100, 
                                LEDS5_4   = 8'b00000011} leds_t;

endpackage
