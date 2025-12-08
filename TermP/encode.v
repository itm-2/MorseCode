//==============================================================================
// Encode UI Module (FINAL CORRECTED VERSION - 비트 슬라이싱 수정)
//==============================================================================
module encode_ui (
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
    input wire [39:0] morse_out,
    
    // LCD Interface
    output reg lcd_write_req,
    output reg [4:0] lcd_x_pos,
    output reg [1:0] lcd_y_pos,
    output reg [127:0] lcd_text,
    output reg [7:0] lcd_text_len,
    
    // Piezo Interface
    output reg piezo_enable,
    output reg [15:0] piezo_duration,
    output reg [15:0] piezo_frequency,
    
    // RGB LED
    output reg rgb_r,
    output reg rgb_g,
    output reg rgb_b,
    
    // Servo Motor (State indicator)
    output reg [7:0] servo_angle,
    
    // UI Navigation
    output reg [3:0] next_uuid,
    output reg ui_update,
    
    // Timing Configuration
    input wire [31:0] dit_time,
    input wire [31:0] dah_time,
    input wire [31:0] long_key_threshold
);

//==============================================================================
// Parameters
//==============================================================================
localparam IDLE             = 4'b0000;
localparam INPUT            = 4'b0001;
localparam LCD_LINE1        = 4'b1100;
localparam LCD_LINE2        = 4'b1101;
localparam TRANSLATE_INIT   = 4'b0010;
localparam TRANSLATE_WAIT   = 4'b0011;
localparam OUTPUT_INIT      = 4'b0100;
localparam OUTPUT_CHAR      = 4'b0101;
localparam OUTPUT_BIT       = 4'b0110;
localparam BIT_GAP          = 4'b0111;
localparam CHAR_GAP         = 4'b1000;
localparam OUTPUT_COMPLETE  = 4'b1001;
localparam WAIT_REPEAT      = 4'b1010;
localparam DONE             = 4'b1011;

localparam UUID_MAIN     = 4'b0000;
localparam UUID_ENCODE   = 4'b0010;

localparam FREQ_DIT      = 16'd800;
localparam FREQ_DAH      = 16'd600;

// Key Types
localparam TYPE_SINGLE_KEY    = 3'b000;
localparam TYPE_LONG_KEY      = 3'b001;
localparam TYPE_MULTI_KEY     = 3'b010;
localparam TYPE_CTRL_SINGLE   = 3'b100;
localparam TYPE_CTRL_LONG     = 3'b101;
localparam TYPE_CTRL_MULTI    = 3'b110;

//==============================================================================
// Internal Registers
//==============================================================================
reg [3:0] state, next_state;
reg [7:0] text_buffer [0:15];
reg [3:0] text_cnt;
reg [2:0] alphabet_state;
reg [2:0] next_alphabet_state;
reg [7:0] current_char_idx;
reg [5:0] morse_bit_idx;
reg [39:0] current_morse;
reg [5:0] morse_length;
reg [31:0] gap_counter;
reg [31:0] repeat_counter;
reg [127:0] display_line1;
reg [127:0] display_line2;

// Morse buffer for each character
reg [39:0] morse_buffer [0:15];
reg [5:0] morse_lengths [0:15];

// KeyMapping interface
wire [10:0] key_output;
wire key_valid;
wire key_freeze;

// Piezo timing
reg piezo_busy;
reg [31:0] piezo_counter;

integer i;

//==============================================================================
// KeyMapping Instance
//==============================================================================
key_mapping key_map_inst (
    .clk(clk),
    .rst_n(rst_n),
    .button_pressed(button_pressed),
    .current_mode(2'b00),  // Alphabet mode
    .current_state(alphabet_state),
    .long_key_threshold(long_key_threshold[15:0]),  // ? 하위 16비트만 전달
    .key_output(key_output),
    .key_valid(key_valid),
    .freeze(key_freeze)
);

//==============================================================================
// Piezo Busy Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        piezo_busy <= 1'b0;
        piezo_counter <= 32'b0;
    end else begin
        if (piezo_enable && !piezo_busy) begin
            piezo_busy <= 1'b1;
            piezo_counter <= 32'b0;
        end else if (piezo_busy) begin
            piezo_counter <= piezo_counter + 1;
            if (piezo_counter >= piezo_duration) begin
                piezo_busy <= 1'b0;
            end
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
                    if (text_cnt > 0)
                        next_state = TRANSLATE_INIT;
                end else if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[4]) begin
                    // BACK pressed
                    next_state = DONE;
                end else begin
                    next_state = LCD_LINE1;
                end
            end else begin
                next_state = LCD_LINE1;
            end
        end
        
        LCD_LINE1: next_state = LCD_LINE2;
        LCD_LINE2: next_state = INPUT;
        
        TRANSLATE_INIT: next_state = TRANSLATE_WAIT;
        
        TRANSLATE_WAIT: begin
            if (translate_done) begin
                if (current_char_idx < text_cnt - 1)
                    next_state = TRANSLATE_INIT;
                else
                    next_state = OUTPUT_INIT;
            end
        end
        
        OUTPUT_INIT: next_state = OUTPUT_CHAR;
        
        OUTPUT_CHAR: next_state = OUTPUT_BIT;
        
        OUTPUT_BIT: begin
            if (!piezo_busy)
                next_state = BIT_GAP;
        end
        
        BIT_GAP: begin
            if (gap_counter >= dit_time) begin
                if (morse_bit_idx >= morse_length) begin
                    if (current_char_idx < text_cnt - 1)
                        next_state = CHAR_GAP;
                    else
                        next_state = OUTPUT_COMPLETE;
                end else begin
                    next_state = OUTPUT_BIT;
                end
            end
        end
        
        CHAR_GAP: begin
            if (gap_counter >= (dit_time * 3))
                next_state = OUTPUT_CHAR;
        end
        
        OUTPUT_COMPLETE: next_state = WAIT_REPEAT;
        
        WAIT_REPEAT: begin
            if (repeat_counter >= 32'd100_000_000)
                next_state = INPUT;
            else if (key_valid) begin
                if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[5])
                    next_state = OUTPUT_INIT;
                else if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[4])
                    next_state = DONE;
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
        
        piezo_enable <= 1'b0;
        piezo_duration <= 16'b0;
        piezo_frequency <= 16'b0;
        
        rgb_r <= 1'b0;
        rgb_g <= 1'b0;
        rgb_b <= 1'b0;
        
        servo_angle <= 8'd0;
        
        next_uuid <= UUID_ENCODE;
        ui_update <= 1'b0;
        
        text_cnt <= 4'b0;
        alphabet_state <= 3'b0;
        current_char_idx <= 8'b0;
        morse_bit_idx <= 6'b0;
        current_morse <= 40'b0;
        morse_length <= 6'b0;
        gap_counter <= 32'b0;
        repeat_counter <= 32'b0;
        
        // ? 초기 화면: 빈 공간 (16자 공백)
        display_line1 <= {16{8'h20}};  // 16개의 공백 문자
        display_line2 <= {"1-8             ", 112'b0};
        
    end else if (active) begin
        // Default values
        lcd_write_req <= 1'b0;
        ibuffer_push <= 1'b0;
        translate_req <= 1'b0;
        piezo_enable <= 1'b0;
        ui_update <= 1'b0;
        
        case (state)
            IDLE: begin
                text_cnt <= 4'b0;
                current_char_idx <= 8'b0;
                morse_bit_idx <= 6'b0;
                gap_counter <= 32'b0;
                repeat_counter <= 32'b0;
                
                // ? 초기 화면: 빈 공간으로 시작
                display_line1 <= {16{8'h20}};
                
                // Servo Motor & LCD Line 2 초기화
                case (alphabet_state)
                    3'd0: begin
                        servo_angle <= 8'd0;
                        display_line2 <= {"1-8             ", 112'b0};
                    end
                    3'd1: begin
                        servo_angle <= 8'd45;
                        display_line2 <= {"9-F             ", 112'b0};
                    end
                    3'd2: begin
                        servo_angle <= 8'd90;
                        display_line2 <= {"G-N             ", 112'b0};
                    end
                    3'd3: begin
                        servo_angle <= 8'd135;
                        display_line2 <= {"O-V             ", 112'b0};
                    end
                    3'd4: begin
                        servo_angle <= 8'd180;
                        display_line2 <= {"W-Z             ", 112'b0};
                    end
                    default: begin
                        servo_angle <= 8'd0;
                        display_line2 <= {"1-8             ", 112'b0};
                    end
                endcase
                
                rgb_r <= 1'b0;
                rgb_g <= 1'b1;
                rgb_b <= 1'b0;
            end
            
            INPUT: begin
                if (key_valid && !key_freeze) begin
                    case (key_output[10:8])
                        TYPE_SINGLE_KEY: begin
                            // Regular alphabet input
                            if (!ibuffer_full && text_cnt < 16) begin
                                text_buffer[text_cnt] <= key_output[7:0];
                                
                                // ? 수정: 왼쪽부터 오른쪽으로 문자 삽입
                                // display_line1[127:120] = 첫 번째 문자
                                // display_line1[119:112] = 두 번째 문자
                                // ...
                                display_line1[(127 - text_cnt*8) -: 8] <= key_output[7:0];
                                
                                text_cnt <= text_cnt + 1;
                            end else begin
                                // Buffer full
                                rgb_r <= 1'b1;
                                rgb_g <= 1'b0;
                                rgb_b <= 1'b0;
                            end
                        end
                        
                        TYPE_CTRL_SINGLE: begin
                            if (key_output[6]) begin
                                // CLEAR
                                text_cnt <= 4'b0;
                                display_line1 <= {16{8'h20}};  // ? 전체 공백으로 초기화
                            end else if (key_output[4]) begin
                                // BACKSPACE
                                if (text_cnt > 0) begin
                                    text_cnt <= text_cnt - 1;
                                    // ? 마지막 문자를 공백으로 지우기
                                    display_line1[(127 - (text_cnt-1)*8) -: 8] <= 8'h20;
                                end
                            end else if (key_output[2]) begin
                                // SPACE
                                if (!ibuffer_full && text_cnt < 16) begin
                                    text_buffer[text_cnt] <= 8'h20;
                                    display_line1[(127 - text_cnt*8) -: 8] <= 8'h20;
                                    text_cnt <= text_cnt + 1;
                                end
                            end
                        end
                        
                        TYPE_CTRL_MULTI: begin
                            next_alphabet_state = alphabet_state;
                            
                            if (key_output[1]) begin
                                // NextState (9+8)
                                if (alphabet_state < 4)
                                    next_alphabet_state = alphabet_state + 1;
                            end else if (key_output[0]) begin
                                // PrevState (9+7)
                                if (alphabet_state > 0)
                                    next_alphabet_state = alphabet_state - 1;
                            end
                            
                            alphabet_state <= next_alphabet_state;
                            
                            // Servo Motor & LCD Line 2 즉시 업데이트
                            case (next_alphabet_state)
                                3'd0: begin
                                    servo_angle <= 8'd0;
                                    display_line2 <= {"1-8             ", 112'b0};
                                end
                                3'd1: begin
                                    servo_angle <= 8'd45;
                                    display_line2 <= {"9-F             ", 112'b0};
                                end
                                3'd2: begin
                                    servo_angle <= 8'd90;
                                    display_line2 <= {"G-N             ", 112'b0};
                                end
                                3'd3: begin
                                    servo_angle <= 8'd135;
                                    display_line2 <= {"O-V             ", 112'b0};
                                end
                                3'd4: begin
                                    servo_angle <= 8'd180;
                                    display_line2 <= {"W-Z             ", 112'b0};
                                end
                            endcase
                        end
                    endcase
                end
            end
            
            LCD_LINE1: begin
                lcd_text <= display_line1;
                lcd_text_len <= 8'd16;
                lcd_x_pos <= 5'd0;
                lcd_y_pos <= 2'd0;
                lcd_write_req <= 1'b1;
            end
            
            LCD_LINE2: begin
                lcd_text <= display_line2;
                lcd_text_len <= 8'd16;
                lcd_x_pos <= 5'd0;
                lcd_y_pos <= 2'd1;
                lcd_write_req <= 1'b1;
            end
            
            TRANSLATE_INIT: begin
                translate_req <= 1'b1;
                ibuffer_data_in <= text_buffer[current_char_idx];
                ibuffer_push <= 1'b1;
            end
            
            TRANSLATE_WAIT: begin
                if (translate_done) begin
                    morse_buffer[current_char_idx] <= morse_out;
                    morse_lengths[current_char_idx] <= count_morse_bits(morse_out);
                    current_char_idx <= current_char_idx + 1;
                end
            end
            
            OUTPUT_INIT: begin
                current_char_idx <= 8'b0;
                morse_bit_idx <= 6'b0;
            end
            
            OUTPUT_CHAR: begin
                current_morse <= morse_buffer[current_char_idx];
                morse_length <= morse_lengths[current_char_idx];
                morse_bit_idx <= 6'b0;
            end
            
            OUTPUT_BIT: begin
                if (!piezo_busy) begin
                    if (current_morse[morse_bit_idx]) begin
                        // DAH
                        piezo_enable <= 1'b1;
                        piezo_duration <= dah_time[15:0];  // ? 하위 16비트만 사용
                        piezo_frequency <= FREQ_DAH;
                        rgb_r <= 1'b1;
                        rgb_g <= 1'b0;
                        rgb_b <= 1'b0;
                    end else begin
                        // DIT
                        piezo_enable <= 1'b1;
                        piezo_duration <= dit_time[15:0];  // ? 하위 16비트만 사용
                        piezo_frequency <= FREQ_DIT;
                        rgb_r <= 1'b0;
                        rgb_g <= 1'b1;
                        rgb_b <= 1'b0;
                    end
                    morse_bit_idx <= morse_bit_idx + 1;
                    gap_counter <= 32'b0;
                end
            end
            
            BIT_GAP: begin
                gap_counter <= gap_counter + 1;
                rgb_r <= 1'b0;
                rgb_g <= 1'b0;
                rgb_b <= 1'b0;
            end
            
            CHAR_GAP: begin
                gap_counter <= gap_counter + 1;
                if (gap_counter >= (dit_time * 3)) begin
                    current_char_idx <= current_char_idx + 1;
                    gap_counter <= 32'b0;
                end
            end
            
            OUTPUT_COMPLETE: begin
                lcd_text <= {"DONE! REPEAT?   ", 112'b0};
                lcd_text_len <= 8'd16;
                lcd_x_pos <= 5'd0;
                lcd_y_pos <= 2'd0;
                lcd_write_req <= 1'b1;
                
                rgb_r <= 1'b0;
                rgb_g <= 1'b0;
                rgb_b <= 1'b1;
            end
            
            WAIT_REPEAT: begin
                repeat_counter <= repeat_counter + 1;
            end
            
            DONE: begin
                next_uuid <= UUID_MAIN;
                ui_update <= 1'b1;
            end
        endcase
    end
end

//==============================================================================
// Helper Functions
//==============================================================================
function [5:0] count_morse_bits;
    input [39:0] morse;
    integer j;
    begin
        count_morse_bits = 6'b0;
        for (j = 0; j < 40; j = j + 1) begin
            if (morse[j])
                count_morse_bits = j + 1;
        end
    end
endfunction

endmodule