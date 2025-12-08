//==============================================================================
// Translator Module (Morse Code ↔ Text) - FINAL CORRECTED
//==============================================================================
module translator (
    input wire clk,
    input wire rst_n,
    
    // Control
    input wire req,
    input wire mode,  // 0: Morse→Text, 1: Text→Morse
    
    // Input Data (단일 입력)
    input wire [7:0] data_in,
    
    // Output Data
    output reg [39:0] morse_out,
    output reg [5:0] morse_out_len,
    output reg [7:0] char_out,
    
    // Status
    output reg done,
    output reg error
);

//==============================================================================
// State Machine
//==============================================================================
localparam IDLE      = 2'b00;
localparam TRANSLATE = 2'b01;
localparam DONE_ST   = 2'b10;

reg [1:0] state, next_state;

//==============================================================================
// Morse Code Lookup Table (Text → Morse)
//==============================================================================
function [45:0] get_morse_code;
    input [7:0] ascii_char;
    begin
        case (ascii_char)
            8'h41: get_morse_code = {6'd2, 40'b01};        // A: .-
            8'h42: get_morse_code = {6'd4, 40'b1000};      // B: -...
            8'h43: get_morse_code = {6'd4, 40'b1010};      // C: -.-.
            8'h44: get_morse_code = {6'd3, 40'b100};       // D: -..
            8'h45: get_morse_code = {6'd1, 40'b0};         // E: .
            8'h46: get_morse_code = {6'd4, 40'b0010};      // F: ..-.
            8'h47: get_morse_code = {6'd3, 40'b110};       // G: --.
            8'h48: get_morse_code = {6'd4, 40'b0000};      // H: ....
            8'h49: get_morse_code = {6'd2, 40'b00};        // I: ..
            8'h4A: get_morse_code = {6'd4, 40'b0111};      // J: .---
            8'h4B: get_morse_code = {6'd3, 40'b101};       // K: -.-
            8'h4C: get_morse_code = {6'd4, 40'b0100};      // L: .-..
            8'h4D: get_morse_code = {6'd2, 40'b11};        // M: --
            8'h4E: get_morse_code = {6'd2, 40'b10};        // N: -.
            8'h4F: get_morse_code = {6'd3, 40'b111};       // O: ---
            8'h50: get_morse_code = {6'd4, 40'b0110};      // P: .--.
            8'h51: get_morse_code = {6'd4, 40'b1101};      // Q: --.-
            8'h52: get_morse_code = {6'd3, 40'b010};       // R: .-.
            8'h53: get_morse_code = {6'd3, 40'b000};       // S: ...
            8'h54: get_morse_code = {6'd1, 40'b1};         // T: -
            8'h55: get_morse_code = {6'd3, 40'b001};       // U: ..-
            8'h56: get_morse_code = {6'd4, 40'b0001};      // V: ...-
            8'h57: get_morse_code = {6'd3, 40'b011};       // W: .--
            8'h58: get_morse_code = {6'd4, 40'b1001};      // X: -..-
            8'h59: get_morse_code = {6'd4, 40'b1011};      // Y: -.--
            8'h5A: get_morse_code = {6'd4, 40'b1100};      // Z: --..
            8'h30: get_morse_code = {6'd5, 40'b11111};     // 0: -----
            8'h31: get_morse_code = {6'd5, 40'b01111};     // 1: .----
            8'h32: get_morse_code = {6'd5, 40'b00111};     // 2: ..---
            8'h33: get_morse_code = {6'd5, 40'b00011};     // 3: ...--
            8'h34: get_morse_code = {6'd5, 40'b00001};     // 4: ....-
            8'h35: get_morse_code = {6'd5, 40'b00000};     // 5: .....
            8'h36: get_morse_code = {6'd5, 40'b10000};     // 6: -....
            8'h37: get_morse_code = {6'd5, 40'b11000};     // 7: --...
            8'h38: get_morse_code = {6'd5, 40'b11100};     // 8: ---..
            8'h39: get_morse_code = {6'd5, 40'b11110};     // 9: ----.
            8'h20: get_morse_code = {6'd0, 40'b0};         // SPACE
            default: get_morse_code = {6'd0, 40'b0};
        endcase
    end
endfunction

//==============================================================================
// Morse → ASCII 변환 (8비트 인코딩)
// Format: [7:6] = length_code, [5:0] = morse_data
//==============================================================================
function [7:0] get_ascii_char;
    input [7:0] morse_encoded;
    reg [1:0] length_code;
    reg [5:0] morse_data;
    begin
        length_code = morse_encoded[7:6];
        morse_data = morse_encoded[5:0];
        
        case (length_code)
            2'b00: begin  // 1-bit
                get_ascii_char = morse_data[0] ? 8'h54 : 8'h45;  // T or E
            end
            
            2'b01: begin  // 2-bit
                case (morse_data[1:0])
                    2'b00: get_ascii_char = 8'h49;  // I
                    2'b01: get_ascii_char = 8'h41;  // A
                    2'b10: get_ascii_char = 8'h4E;  // N
                    2'b11: get_ascii_char = 8'h4D;  // M
                endcase
            end
            
            2'b10: begin  // 3-bit
                case (morse_data[2:0])
                    3'b000: get_ascii_char = 8'h53;  // S
                    3'b001: get_ascii_char = 8'h55;  // U
                    3'b010: get_ascii_char = 8'h52;  // R
                    3'b011: get_ascii_char = 8'h57;  // W
                    3'b100: get_ascii_char = 8'h44;  // D
                    3'b101: get_ascii_char = 8'h4B;  // K
                    3'b110: get_ascii_char = 8'h47;  // G
                    3'b111: get_ascii_char = 8'h4F;  // O
                endcase
            end
            
            2'b11: begin  // 4-5 bit
                if (morse_data[4] == 1'b0) begin  // 4-bit
                    case (morse_data[3:0])
                        4'b0000: get_ascii_char = 8'h48;  // H
                        4'b0001: get_ascii_char = 8'h56;  // V
                        4'b0010: get_ascii_char = 8'h46;  // F
                        4'b0100: get_ascii_char = 8'h4C;  // L
                        4'b0110: get_ascii_char = 8'h50;  // P
                        4'b0111: get_ascii_char = 8'h4A;  // J
                        4'b1000: get_ascii_char = 8'h42;  // B
                        4'b1001: get_ascii_char = 8'h58;  // X
                        4'b1010: get_ascii_char = 8'h43;  // C
                        4'b1011: get_ascii_char = 8'h59;  // Y
                        4'b1100: get_ascii_char = 8'h5A;  // Z
                        4'b1101: get_ascii_char = 8'h51;  // Q
                        default: get_ascii_char = 8'h3F;
                    endcase
                end else begin  // 5-bit
                    case (morse_data[4:0])
                        5'b00000: get_ascii_char = 8'h35;  // 5
                        5'b00001: get_ascii_char = 8'h34;  // 4
                        5'b00011: get_ascii_char = 8'h33;  // 3
                        5'b00111: get_ascii_char = 8'h32;  // 2
                        5'b01111: get_ascii_char = 8'h31;  // 1
                        5'b10000: get_ascii_char = 8'h36;  // 6
                        5'b11000: get_ascii_char = 8'h37;  // 7
                        5'b11100: get_ascii_char = 8'h38;  // 8
                        5'b11110: get_ascii_char = 8'h39;  // 9
                        5'b11111: get_ascii_char = 8'h30;  // 0
                        default: get_ascii_char = 8'h3F;
                    endcase
                end
            end
        endcase
    end
endfunction

//==============================================================================
// State Machine
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
end

always @(*) begin
    case (state)
        IDLE: next_state = req ? TRANSLATE : IDLE;
        TRANSLATE: next_state = DONE_ST;
        DONE_ST: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

//==============================================================================
// Translation Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        morse_out <= 40'b0;
        morse_out_len <= 6'b0;
        char_out <= 8'b0;
        done <= 1'b0;
        error <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                error <= 1'b0;
            end
            
            TRANSLATE: begin
                if (mode == 1'b1) begin
                    // Text → Morse
                    {morse_out_len, morse_out} <= get_morse_code(data_in);
                    error <= (morse_out_len == 0 && data_in != 8'h20);
                end else begin
                    // Morse → Text
                    char_out <= get_ascii_char(data_in);
                    error <= (char_out == 8'h3F);
                end
            end
            
            DONE_ST: done <= 1'b1;
        endcase
    end
end

endmodule