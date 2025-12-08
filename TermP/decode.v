//==============================================================================
// Decode UI Module (UC-01: Morse Code Decoding)
//==============================================================================
module decode_ui (
    input wire clk,
    input wire rst_n,
    input wire active,
    
    // Button inputs
    input wire [11:0] button_pressed,
    
    // Buffer Interface
    output reg ibuffer_push,
    output reg [7:0] ibuffer_data_in,
    input wire ibuffer_full,
    
    // Translator Interface
    output reg translate_req,
    input wire translate_done,
    input wire [7:0] char_out,
    input wire translate_error,
    
    // LCD Interface
    output reg lcd_write_req,
    output reg [4:0] lcd_x_pos,
    output reg [1:0] lcd_y_pos,
    output reg [127:0] lcd_text,
    output reg [7:0] lcd_text_len,
    
    // LED Interface (Button indicators)
    output reg [7:0] led_enable,
    
    // RGB LED (Error indicator)
    output reg rgb_r,
    output reg rgb_g,
    output reg rgb_b,
    
    // UI Navigation
    output reg [3:0] next_uuid,
    output reg ui_update,
    
    // Timing Configuration
    input wire [31:0] dit_time,
    input wire [31:0] space_time,
    input wire [31:0] long_key_threshold
);

//==============================================================================
// Parameters
//==============================================================================
localparam IDLE             = 4'b0000;
localparam INPUT            = 4'b0001;
localparam WAIT_SPACE       = 4'b0010;
localparam TRANSLATE_INIT   = 4'b0011;
localparam TRANSLATE_WAIT   = 4'b0100;
localparam DISPLAY_CHAR     = 4'b0101;
localparam WAIT_ENTER       = 4'b0110;
localparam DONE             = 4'b0111;

localparam UUID_MAIN     = 4'b0000;
localparam UUID_DECODE   = 4'b0001;

// Key Types
localparam TYPE_SINGLE_KEY    = 3'b000;
localparam TYPE_LONG_KEY      = 3'b001;
localparam TYPE_MULTI_KEY     = 3'b010;
localparam TYPE_CTRL_SINGLE   = 3'b100;
localparam TYPE_CTRL_LONG     = 3'b101;
localparam TYPE_CTRL_MULTI    = 3'b110;
localparam TYPE_MACRO         = 3'b011;

//==============================================================================
// Internal Registers
//==============================================================================
reg [3:0] state, next_state;
reg [39:0] morse_buffer;        // Current morse code sequence
reg [5:0] morse_bit_cnt;        // Number of bits in current sequence
reg [7:0] text_buffer [0:15];   // Decoded text buffer
reg [3:0] text_cnt;             // Number of decoded characters
reg [31:0] space_counter;       // Counter for SPACE detection
reg [127:0] display_line1;
reg [127:0] display_line2;

// Macro buffer (for macro playback)
reg [39:0] macro_buffer;
reg [5:0] macro_bit_cnt;
reg macro_playing;

// KeyMapping interface
wire [10:0] key_output;
wire key_valid;
wire key_freeze;

// Space detection flag
reg space_detected;

integer i;

//==============================================================================
// KeyMapping Instance
//==============================================================================
key_mapping key_map_inst (
    .clk(clk),
    .rst_n(rst_n),
    .button_pressed(button_pressed),
    .current_mode(2'b01),  // Morse mode
    .current_state(3'b000), // Morse mode has no state
    .long_key_threshold(long_key_threshold),
    .key_output(key_output),
    .key_valid(key_valid),
    .freeze(key_freeze)
);

//==============================================================================
// LED Indicator (Show available buttons: 1, 2, and Macro 3-8)
//==============================================================================
always @(*) begin
    if (active && state == INPUT) begin
        led_enable = 8'b11111111;  // Buttons 1-8 available
    end else begin
        led_enable = 8'b00000000;
    end
end

//==============================================================================
// Space Detection Counter
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        space_counter <= 32'b0;
        space_detected <= 1'b0;
    end else if (active) begin
        if (state == WAIT_SPACE) begin
            space_counter <= space_counter + 1;
            if (space_counter >= space_time) begin
                space_detected <= 1'b1;
            end
        end else begin
            space_counter <= 32'b0;
            space_detected <= 1'b0;
        end
    end
end

//==============================================================================
// State Machine
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else if (active) begin
        state <= next_state;
    end else begin
        state <= IDLE;
    end
end

//==============================================================================
// Next State Logic
//==============================================================================
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: next_state = INPUT;
        
        INPUT: begin
            if (key_valid) begin
                if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[5]) begin
                    // ENTER pressed
                    if (morse_bit_cnt > 0)
                        next_state = TRANSLATE_INIT;
                    else if (text_cnt > 0)
                        next_state = WAIT_ENTER;
                end else if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[4]) begin
                    // BACK pressed
                    next_state = DONE;
                end else if (key_output[10:8] == TYPE_SINGLE_KEY || 
                             key_output[10:8] == TYPE_LONG_KEY ||
                             key_output[10:8] == TYPE_MACRO) begin
                    // Morse input received
                    next_state = WAIT_SPACE;
                end
            end
        end
        
        WAIT_SPACE: begin
            if (space_detected) begin
                // SPACE detected, translate current morse
                next_state = TRANSLATE_INIT;
            end else if (key_valid) begin
                // New input before SPACE
                if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[3]) begin
                    // PAUSE button (9) pressed
                    next_state = TRANSLATE_INIT;
                end else begin
                    next_state = INPUT;
                end
            end
        end
        
        TRANSLATE_INIT: next_state = TRANSLATE_WAIT;
        
        TRANSLATE_WAIT: begin
            if (translate_done) begin
                if (translate_error)
                    next_state = INPUT;  // Invalid morse, return to input
                else
                    next_state = DISPLAY_CHAR;
            end
        end
        
        DISPLAY_CHAR: next_state = INPUT;
        
        WAIT_ENTER: begin
            if (key_valid) begin
                if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[5])
                    next_state = INPUT;  // Restart
                else if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[4])
                    next_state = DONE;   // Exit
            end
        end
        
        DONE: next_state = IDLE;
        
        default: next_state = IDLE;
    endcase
end

//==============================================================================
// Output Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lcd_write_req <= 1'b0;
        lcd_x_pos <= 5'b0;
        lcd_y_pos <= 2'b0;
        lcd_text <= 128'b0;
        lcd_text_len <= 8'b0;
        
        ibuffer_push <= 1'b0;
        ibuffer_data_in <= 8'b0;
        
        translate_req <= 1'b0;
        
        rgb_r <= 1'b0;
        rgb_g <= 1'b0;
        rgb_b <= 1'b0;
        
        next_uuid <= UUID_DECODE;
        ui_update <= 1'b0;
        
        morse_buffer <= 40'b0;
        morse_bit_cnt <= 6'b0;
        text_cnt <= 4'b0;
        macro_buffer <= 40'b0;
        macro_bit_cnt <= 6'b0;
        macro_playing <= 1'b0;
        
        display_line1 <= {"ENTER THE CODE:", 112'b0};
        display_line2 <= {128'b0};
        
    end else if (active) begin
        // Default values
        lcd_write_req <= 1'b0;
        ibuffer_push <= 1'b0;
        translate_req <= 1'b0;
        ui_update <= 1'b0;
        
        case (state)
            IDLE: begin
                morse_buffer <= 40'b0;
                morse_bit_cnt <= 6'b0;
                text_cnt <= 4'b0;
                macro_playing <= 1'b0;
                
                display_line1 <= {"ENTER THE CODE:", 112'b0};
                display_line2 <= {128'b0};
                
                rgb_r <= 1'b0;
                rgb_g <= 1'b1;
                rgb_b <= 1'b0;
            end
            
            INPUT: begin
                if (key_valid && !key_freeze) begin
                    case (key_output[10:8])
                        TYPE_SINGLE_KEY: begin
                            // Button 1: DIT (.)
                            if (key_output[0]) begin
                                if (morse_bit_cnt < 40) begin
                                    morse_buffer[morse_bit_cnt] <= 1'b0;  // DIT = 0
                                    morse_bit_cnt <= morse_bit_cnt + 1;
                                end
                            end
                            // Button 2: Auto DIT (immediate)
                            else if (key_output[1]) begin
                                if (morse_bit_cnt < 40) begin
                                    morse_buffer[morse_bit_cnt] <= 1'b0;
                                    morse_bit_cnt <= morse_bit_cnt + 1;
                                end
                            end
                        end
                        
                        TYPE_LONG_KEY: begin
                            // Button 1: DAH (-)
                            if (key_output[0]) begin
                                if (morse_bit_cnt < 40) begin
                                    morse_buffer[morse_bit_cnt] <= 1'b1;  // DAH = 1
                                    morse_bit_cnt <= morse_bit_cnt + 1;
                                end
                            end
                        end
                        
                        TYPE_MACRO: begin
                            // Macro buttons (3-8)
                            // Load macro from user settings
                            // For now, just mark as macro playing
                            macro_playing <= 1'b1;
                            // TODO: Load macro_buffer from settings
                        end
                        
                        TYPE_CTRL_SINGLE: begin
                            if (key_output[6]) begin
                                // CLEAR (Button 10)
                                morse_buffer <= 40'b0;
                                morse_bit_cnt <= 6'b0;
                                text_cnt <= 4'b0;
                                display_line2 <= {128'b0};
                            end else if (key_output[4]) begin
                                // BACKSPACE (Button 11)
                                if (morse_bit_cnt > 0) begin
                                    morse_bit_cnt <= morse_bit_cnt - 1;
                                    morse_buffer[morse_bit_cnt - 1] <= 1'b0;
                                end
                            end else if (key_output[3]) begin
                                // PAUSE (Button 9) - Reset SPACE timer
                                // Handled in WAIT_SPACE state
                            end
                        end
                    endcase
                end
                
                // Display Line 1: Instruction
                lcd_text <= display_line1;
                lcd_text_len <= 8'd16;
                lcd_x_pos <= 5'd0;
                lcd_y_pos <= 2'd0;
                lcd_write_req <= 1'b1;
                
                // Display Line 2: Current morse code
                // TODO: Convert morse_buffer to visual representation
            end
            
            WAIT_SPACE: begin
                // Wait for SPACE detection or new input
                rgb_r <= 1'b1;
                rgb_g <= 1'b1;
                rgb_b <= 1'b0;  // Yellow = waiting
            end
            
            // decode_ui.v 내부의 TRANSLATE_INIT 부분 수정

        TRANSLATE_INIT: begin
            translate_req <= 1'b1;
            ibuffer_push <= 1'b1;
            
            // 비트 순서: morse_buffer[morse_bit_cnt-1:0]을 MSB부터 전송
            case (morse_bit_cnt)
                6'd1: ibuffer_data_in <= {2'b00, 5'b0, morse_buffer[0]};
                6'd2: ibuffer_data_in <= {2'b01, 4'b0, morse_buffer[1], morse_buffer[0]};  // ? 순서 반전
                6'd3: ibuffer_data_in <= {2'b10, 3'b0, morse_buffer[2], morse_buffer[1], morse_buffer[0]};
                6'd4: ibuffer_data_in <= {2'b11, 1'b0, 1'b0, morse_buffer[3], morse_buffer[2], morse_buffer[1], morse_buffer[0]};
                default: ibuffer_data_in <= {2'b11, 1'b1, morse_buffer[4], morse_buffer[3], morse_buffer[2], morse_buffer[1], morse_buffer[0]};
            endcase
        end
                        
            TRANSLATE_WAIT: begin
                if (translate_done) begin
                    if (translate_error) begin
                        // Invalid morse code
                        rgb_r <= 1'b1;
                        rgb_g <= 1'b0;
                        rgb_b <= 1'b0;  // Red = error
                        
                        // Replace with '?'
                        if (text_cnt < 16) begin
                            text_buffer[text_cnt] <= 8'h3F;  // '?'
                            text_cnt <= text_cnt + 1;
                        end
                    end else begin
                        // Valid translation
                        if (text_cnt < 16) begin
                            text_buffer[text_cnt] <= char_out;
                            text_cnt <= text_cnt + 1;
                        end
                    end
                    
                    // Clear morse buffer
                    morse_buffer <= 40'b0;
                    morse_bit_cnt <= 6'b0;
                end
            end
            
            DISPLAY_CHAR: begin
                // Update LCD with decoded text
                for (i = 0; i < 16; i = i + 1) begin
                    if (i < text_cnt)
                        display_line2[127 - i*8 -: 8] <= text_buffer[i];
                    else
                        display_line2[127 - i*8 -: 8] <= 8'h20;  // Space
                end
                
                lcd_text <= display_line2;
                lcd_text_len <= 8'd16;
                lcd_x_pos <= 5'd0;
                lcd_y_pos <= 2'd1;
                lcd_write_req <= 1'b1;
                
                rgb_r <= 1'b0;
                rgb_g <= 1'b1;
                rgb_b <= 1'b0;  // Green = success
            end
            
            WAIT_ENTER: begin
                // Display complete message
                lcd_text <= {"DONE! PRESS ENT", 112'b0};
                lcd_text_len <= 8'd16;
                lcd_x_pos <= 5'd0;
                lcd_y_pos <= 2'd0;
                lcd_write_req <= 1'b1;
                
                rgb_r <= 1'b0;
                rgb_g <= 1'b0;
                rgb_b <= 1'b1;  // Blue = complete
            end
            
            DONE: begin
                next_uuid <= UUID_MAIN;
                ui_update <= 1'b1;
            end
        endcase
    end
end

endmodule