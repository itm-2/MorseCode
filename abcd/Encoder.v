module Encoder #(
    parameter OUT_MAX_BITS = 256
)(
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   start,
    input  wire [3:0]             text_length,
    input  wire [7:0]             t0,  t1,  t2,  t3,  t4,  t5,  t6,  t7,
    input  wire [7:0]             t8,  t9,  t10, t11, t12, t13, t14, t15,

    output reg                    busy,
    output reg                    done,
    output reg [OUT_MAX_BITS-1:0] bitstream,
    output reg [8:0]              bitlen
);

    localparam IDLE      = 2'd0;
    localparam FETCH     = 2'd1;
    localparam ENCODE    = 2'd2;
    localparam DONE_ST   = 2'd3;

    reg [1:0]  state, next_state;
    reg [3:0]  char_idx;
    reg [7:0]  fetched_char;
    reg [3:0]  morse_step;
    reg [3:0]  morse_len;
    reg [4:0]  morse_pattern;
    reg        is_space;

    // ========================================
    // Character fetch
    // ========================================
    function [7:0] get_char;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:  get_char = t0;   4'd1:  get_char = t1;
                4'd2:  get_char = t2;   4'd3:  get_char = t3;
                4'd4:  get_char = t4;   4'd5:  get_char = t5;
                4'd6:  get_char = t6;   4'd7:  get_char = t7;
                4'd8:  get_char = t8;   4'd9:  get_char = t9;
                4'd10: get_char = t10;  4'd11: get_char = t11;
                4'd12: get_char = t12;  4'd13: get_char = t13;
                4'd14: get_char = t14;  4'd15: get_char = t15;
            endcase
        end
    endfunction

    // ========================================
    // Normalize
    // ========================================
    function [7:0] normalize;
        input [7:0] c;
        begin
            normalize = (c >= 8'h61 && c <= 8'h7A) ? (c - 8'd32) : c;
        end
    endfunction

    // ========================================
    // Morse lookup (LSB first)
    // ========================================
    // ========================================
// Morse lookup (LSB first, 올바른 순서)
// ========================================
    function [8:0] morse_lookup;
        input [7:0] c;
        begin
            case (c)
                "A": morse_lookup = {4'd2, 5'b00010};  // .- = 0,10 = 0,01 reversed
                "B": morse_lookup = {4'd4, 5'b00001};  // -... = 10,0,0,0 = 0001 reversed
                "C": morse_lookup = {4'd4, 5'b00101};  // -.-. = 10,0,10,0 = 0101 reversed
                "D": morse_lookup = {4'd3, 5'b00001};  // -.. = 10,0,0 = 001 reversed
                "E": morse_lookup = {4'd1, 5'b00000};  // . = 0
                "F": morse_lookup = {4'd4, 5'b01000};  // ..-. = 0,0,10,0 = 0010 reversed
                "G": morse_lookup = {4'd3, 5'b00011};  // --. = 10,10,0 = 011 reversed
                "H": morse_lookup = {4'd4, 5'b00000};  // .... = 0,0,0,0
                "I": morse_lookup = {4'd2, 5'b00000};  // .. = 0,0
                "J": morse_lookup = {4'd4, 5'b01110};  // .--- = 0,10,10,10 = 0111 reversed
                "K": morse_lookup = {4'd3, 5'b00101};  // -.- = 10,0,10 = 101 reversed
                "L": morse_lookup = {4'd4, 5'b00010};  // .-.. = 0,10,0,0 = 0100 reversed
                "M": morse_lookup = {4'd2, 5'b00011};  // -- = 10,10 = 11
                "N": morse_lookup = {4'd2, 5'b00010};  // -. = 10,0 = 01 reversed
                "O": morse_lookup = {4'd3, 5'b00111};  // --- = 10,10,10 = 111
                "P": morse_lookup = {4'd4, 5'b01100};  // .--. = 0,10,10,0 = 0110 reversed
                "Q": morse_lookup = {4'd4, 5'b01011};  // --.- = 10,10,0,10 = 1101 reversed
                "R": morse_lookup = {4'd3, 5'b00100};  // .-. = 0,10,0 = 010 reversed
                "S": morse_lookup = {4'd3, 5'b00000};  // ... = 0,0,0
                "T": morse_lookup = {4'd1, 5'b00001};  // - = 10 = 1
                "U": morse_lookup = {4'd3, 5'b00100};  // ..- = 0,0,10 = 100 reversed
                "V": morse_lookup = {4'd4, 5'b01000};  // ...- = 0,0,0,10 = 1000 reversed
                "W": morse_lookup = {4'd3, 5'b00110};  // .-- = 0,10,10 = 110 reversed
                "X": morse_lookup = {4'd4, 5'b01001};  // -..- = 10,0,0,10 = 1001 reversed
                "Y": morse_lookup = {4'd4, 5'b01101};  // -.-- = 10,0,10,10 = 1011 reversed
                "Z": morse_lookup = {4'd4, 5'b00011};  // --.. = 10,10,0,0 = 0011 reversed
    
                "0": morse_lookup = {4'd5, 5'b11111};  // ----- = 10,10,10,10,10
                "1": morse_lookup = {4'd5, 5'b11110};  // .---- = 0,10,10,10,10
                "2": morse_lookup = {4'd5, 5'b11100};  // ..--- = 0,0,10,10,10
                "3": morse_lookup = {4'd5, 5'b11000};  // ...-- = 0,0,0,10,10
                "4": morse_lookup = {4'd5, 5'b10000};  // ....- = 0,0,0,0,10
                "5": morse_lookup = {4'd5, 5'b00000};  // ..... = 0,0,0,0,0
                "6": morse_lookup = {4'd5, 5'b00001};  // -.... = 10,0,0,0,0
                "7": morse_lookup = {4'd5, 5'b00011};  // --... = 10,10,0,0,0
                "8": morse_lookup = {4'd5, 5'b00111};  // ---.. = 10,10,10,0,0
                "9": morse_lookup = {4'd5, 5'b01111};  // ----. = 10,10,10,10,0
    
                default: morse_lookup = {4'd0, 5'b00000};
            endcase
        end
    endfunction

    // ========================================
    // State register
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ========================================
    // Next state logic
    // ========================================
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = FETCH;
            end
    
            FETCH: begin
                if (char_idx >= text_length)
                    next_state = DONE_ST;
                else if (normalize(get_char(char_idx)) == 8'd32)  // ← 여기 수정!
                    next_state = FETCH;  // Space면 다시 FETCH
                else
                    next_state = ENCODE;  // 일반 문자면 ENCODE
            end
    
            ENCODE: begin
                if (morse_step >= morse_len)
                    next_state = FETCH;
            end
    
            DONE_ST: begin
                next_state = IDLE;
            end
        endcase
    end

    // ========================================
    // Datapath
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy          <= 1'b0;
            done          <= 1'b0;
            bitstream     <= {OUT_MAX_BITS{1'b0}};
            bitlen        <= 9'd0;
            char_idx      <= 4'd0;
            fetched_char  <= 8'd0;
            morse_step    <= 4'd0;
            morse_len     <= 4'd0;
            morse_pattern <= 5'd0;
            is_space      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy      <= 1'b1;
                        bitstream <= {OUT_MAX_BITS{1'b0}};
                        bitlen    <= 9'd0;
                        char_idx  <= 4'd0;
                    end
                end

                FETCH: begin
                if (char_idx < text_length) begin
                    fetched_char <= normalize(get_char(char_idx));
                    morse_step   <= 4'd0;
                    
                    if (normalize(get_char(char_idx)) == 8'd32) begin
                        // Space = 1111
                        if (bitlen + 9'd4 <= OUT_MAX_BITS) begin
                            bitstream[bitlen]   <= 1'b1;
                            bitstream[bitlen+1] <= 1'b1;
                            bitstream[bitlen+2] <= 1'b1;
                            bitstream[bitlen+3] <= 1'b1;
                            bitlen <= bitlen + 9'd4;
                        end
                        char_idx <= char_idx + 4'd1;
                        // is_space 플래그는 사실 필요 없음!
                    end else begin
                        {morse_len, morse_pattern} <= morse_lookup(normalize(get_char(char_idx)));
                    end
                end
            end

                ENCODE: begin
                    if (morse_step < morse_len) begin
                        // LSB first로 읽기
                        if (morse_pattern[morse_step] == 1'b0) begin
                            // Dot = 0
                            if (bitlen < OUT_MAX_BITS) begin
                                bitstream[bitlen] <= 1'b0;
                                bitlen <= bitlen + 9'd1;
                            end
                        end else begin
                            // Dash = 10
                            if (bitlen + 9'd2 <= OUT_MAX_BITS) begin
                                bitstream[bitlen]   <= 1'b1;
                                bitstream[bitlen+1] <= 1'b0;
                                bitlen <= bitlen + 9'd2;
                            end
                        end
                        morse_step <= morse_step + 4'd1;
                    end else begin
                        // Letter end = 11
                        if (bitlen + 9'd2 <= OUT_MAX_BITS) begin
                            bitstream[bitlen]   <= 1'b1;
                            bitstream[bitlen+1] <= 1'b1;
                            bitlen <= bitlen + 9'd2;
                        end
                        char_idx <= char_idx + 4'd1;
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule