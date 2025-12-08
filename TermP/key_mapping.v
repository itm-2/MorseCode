//==============================================================================
// Key Mapping Module (CORRECTED VERSION)
//==============================================================================
module key_mapping (
    input wire clk,
    input wire rst_n,
    
    // Button inputs (12 buttons)
    input wire [11:0] button_pressed,
    
    // Mode and State
    input wire [1:0] current_mode,      // 0: Alphabet, 1: Morse, 2: Setting
    input wire [2:0] current_state,     // 0-4 for Alphabet, 0 for others
    
    // Timing configuration
    input wire [31:0] long_key_threshold,
    
    // Output
    output reg [10:0] key_output,       // [10:8] type, [7:0] data
    output reg key_valid,
    output reg freeze
);

//==============================================================================
// Parameters
//==============================================================================
// Key Types
localparam TYPE_SINGLE_KEY    = 3'b000;
localparam TYPE_LONG_KEY      = 3'b001;
localparam TYPE_MULTI_KEY     = 3'b010;
localparam TYPE_MACRO_KEY     = 3'b011;
localparam TYPE_CTRL_SINGLE   = 3'b100;
localparam TYPE_CTRL_LONG     = 3'b101;
localparam TYPE_CTRL_MULTI    = 3'b110;

// Modes
localparam MODE_ALPHABET = 2'b00;
localparam MODE_MORSE    = 2'b01;
localparam MODE_SETTING  = 2'b10;

// States
localparam IDLE           = 3'b000;
localparam FIRST_PRESSED  = 3'b001;
localparam WAIT_LONG      = 3'b010;
localparam LONG_DETECTED  = 3'b011;
localparam MULTI_DETECTED = 3'b100;
localparam WAIT_RELEASE   = 3'b101;

//==============================================================================
// Internal Registers
//==============================================================================
reg [2:0] state, next_state;
reg [3:0] first_button_idx;
reg [3:0] second_button_idx;
reg [31:0] press_counter;
reg [11:0] button_prev;
reg button_released;  // ? 레지스터로 선언

//==============================================================================
// Key Map ROM
//==============================================================================
// Alphabet Mode Key Maps
reg [7:0] alphabet_map [0:39];  // 5 states * 8 buttons

initial begin
    // State 0: 1,2,3,4,5,6,7,8
    alphabet_map[0]  = 8'h31; // '1'
    alphabet_map[1]  = 8'h32; // '2'
    alphabet_map[2]  = 8'h33; // '3'
    alphabet_map[3]  = 8'h34; // '4'
    alphabet_map[4]  = 8'h35; // '5'
    alphabet_map[5]  = 8'h36; // '6'
    alphabet_map[6]  = 8'h37; // '7'
    alphabet_map[7]  = 8'h38; // '8'
    
    // State 1: 9,0,A,B,C,D,E,F
    alphabet_map[8]  = 8'h39; // '9'
    alphabet_map[9]  = 8'h30; // '0'
    alphabet_map[10] = 8'h41; // 'A'
    alphabet_map[11] = 8'h42; // 'B'
    alphabet_map[12] = 8'h43; // 'C'
    alphabet_map[13] = 8'h44; // 'D'
    alphabet_map[14] = 8'h45; // 'E'
    alphabet_map[15] = 8'h46; // 'F'
    
    // State 2: G,H,I,J,K,L,M,N
    alphabet_map[16] = 8'h47; // 'G'
    alphabet_map[17] = 8'h48; // 'H'
    alphabet_map[18] = 8'h49; // 'I'
    alphabet_map[19] = 8'h4A; // 'J'
    alphabet_map[20] = 8'h4B; // 'K'
    alphabet_map[21] = 8'h4C; // 'L'
    alphabet_map[22] = 8'h4D; // 'M'
    alphabet_map[23] = 8'h4E; // 'N'
    
    // State 3: O,P,Q,R,S,T,U,V
    alphabet_map[24] = 8'h4F; // 'O'
    alphabet_map[25] = 8'h50; // 'P'
    alphabet_map[26] = 8'h51; // 'Q'
    alphabet_map[27] = 8'h52; // 'R'
    alphabet_map[28] = 8'h53; // 'S'
    alphabet_map[29] = 8'h54; // 'T'
    alphabet_map[30] = 8'h55; // 'U'
    alphabet_map[31] = 8'h56; // 'V'
    
    // State 4: W,X,Y,Z
    alphabet_map[32] = 8'h57; // 'W'
    alphabet_map[33] = 8'h58; // 'X'
    alphabet_map[34] = 8'h59; // 'Y'
    alphabet_map[35] = 8'h5A; // 'Z'
    alphabet_map[36] = 8'h00;
    alphabet_map[37] = 8'h00;
    alphabet_map[38] = 8'h00;
    alphabet_map[39] = 8'h00;
end

//==============================================================================
// Button Index Encoder
//==============================================================================
function [3:0] encode_button;
    input [11:0] buttons;
    integer i;
    begin
        encode_button = 4'd12;  // Invalid
        for (i = 0; i < 12; i = i + 1) begin
            if (buttons[i]) begin
                encode_button = i;
            end
        end
    end
endfunction

//==============================================================================
// Count Pressed Buttons
//==============================================================================
function [3:0] count_buttons;
    input [11:0] buttons;
    integer i;
    begin
        count_buttons = 0;
        for (i = 0; i < 12; i = i + 1) begin
            if (buttons[i])
                count_buttons = count_buttons + 1;
        end
    end
endfunction

//==============================================================================
// State Machine (? button_released를 레지스터로 계산)
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        button_prev <= 12'b0;
        button_released <= 1'b0;  // ? 추가
    end else begin
        state <= next_state;
        button_prev <= button_pressed;
        // ? button_released를 레지스터로 계산 (타이밍 안정화)
        button_released <= (button_prev != 12'b0) && (button_pressed == 12'b0);
    end
end

//==============================================================================
// Next State Logic (? button_released 계산 제거)
//==============================================================================
always @(*) begin
    next_state = state;
    // ? button_released 계산 제거 (이미 레지스터에서 계산됨)
    
    case (state)
        IDLE: begin
            if (button_pressed != 12'b0 && count_buttons(button_pressed) == 1)
                next_state = FIRST_PRESSED;
        end
        
        FIRST_PRESSED: begin
            // Check for immediate processing (Morse button 2 or button 9)
            if (current_mode == MODE_MORSE && first_button_idx == 1) begin
                next_state = WAIT_RELEASE;
            end else if (first_button_idx == 8) begin  // Button 9 (PAUSE/SPACE)
                next_state = WAIT_RELEASE;
            end else if (count_buttons(button_pressed) == 2) begin
                next_state = MULTI_DETECTED;
            end else if (button_released) begin
                next_state = IDLE;
            end else if (press_counter >= long_key_threshold) begin
                next_state = LONG_DETECTED;
            end else begin
                next_state = WAIT_LONG;
            end
        end
        
        WAIT_LONG: begin
            if (count_buttons(button_pressed) == 2) begin
                next_state = MULTI_DETECTED;
            end else if (button_released) begin
                next_state = IDLE;
            end else if (press_counter >= long_key_threshold) begin
                next_state = LONG_DETECTED;
            end
        end
        
        LONG_DETECTED: begin
            if (button_released)
                next_state = IDLE;
        end
        
        MULTI_DETECTED: begin
            if (button_pressed == 12'b0)
                next_state = IDLE;
        end
        
        WAIT_RELEASE: begin
            if (button_released)
                next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

//==============================================================================
// Output Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_output <= 11'b0;
        key_valid <= 1'b0;
        freeze <= 1'b0;
        press_counter <= 32'b0;
        first_button_idx <= 4'd12;
        second_button_idx <= 4'd12;
        
    end else begin
        key_valid <= 1'b0;
        
        case (state)
            IDLE: begin
                press_counter <= 32'b0;
                freeze <= 1'b0;
                
                if (button_pressed != 12'b0 && count_buttons(button_pressed) == 1) begin
                    first_button_idx <= encode_button(button_pressed);
                end
            end
            
            FIRST_PRESSED: begin
                // Immediate processing for Morse button 2 or button 9
                if (current_mode == MODE_MORSE && first_button_idx == 1) begin
                    key_output <= {TYPE_SINGLE_KEY, 8'b00000010};  // Button 2
                    key_valid <= 1'b1;
                    freeze <= 1'b0;
                end else if (first_button_idx == 8) begin  // Button 9
                    if (current_mode == MODE_ALPHABET)
                        key_output <= {TYPE_CTRL_SINGLE, 8'b00000100};  // SPACE
                    else if (current_mode == MODE_MORSE)
                        key_output <= {TYPE_CTRL_SINGLE, 8'b00000100};  // PAUSE
                    key_valid <= 1'b1;
                    freeze <= 1'b0;
                end else begin
                    press_counter <= press_counter + 1;
                end
            end
            
            WAIT_LONG: begin
                press_counter <= press_counter + 1;
                
                // Single key released before long threshold
                if (button_released) begin
                    if (first_button_idx >= 0 && first_button_idx <= 7) begin
                        // Regular input buttons
                        if (current_mode == MODE_ALPHABET) begin
                            if (current_state <= 4) begin
                                key_output <= {TYPE_SINGLE_KEY, 
                                             alphabet_map[current_state * 8 + first_button_idx]};
                                key_valid <= 1'b1;
                            end
                        end else if (current_mode == MODE_MORSE) begin
                            if (first_button_idx == 0) begin
                                // Button 1: dit
                                key_output <= {TYPE_SINGLE_KEY, 8'b00000001};
                                key_valid <= 1'b1;
                            end
                        end else if (current_mode == MODE_SETTING) begin
                            if (first_button_idx == 0) begin
                                key_output <= {TYPE_SINGLE_KEY, 8'b00000100};  // UP
                                key_valid <= 1'b1;
                            end else if (first_button_idx == 1) begin
                                key_output <= {TYPE_SINGLE_KEY, 8'b00001000};  // DOWN
                                key_valid <= 1'b1;
                            end
                        end
                    end else if (first_button_idx == 9) begin
                        // Button 10: CLEAR
                        key_output <= {TYPE_CTRL_SINGLE, 8'b00001000};
                        key_valid <= 1'b1;
                    end else if (first_button_idx == 10) begin
                        // Button 11: BACK
                        key_output <= {TYPE_CTRL_SINGLE, 8'b00010000};
                        key_valid <= 1'b1;
                    end else if (first_button_idx == 11) begin
                        // Button 12: ENTER
                        key_output <= {TYPE_CTRL_SINGLE, 8'b00100000};
                        key_valid <= 1'b1;
                    end
                end
            end
            
            LONG_DETECTED: begin
                freeze <= 1'b1;
                
                if (!key_valid) begin  // Output once
                    if (current_mode == MODE_MORSE && first_button_idx == 0) begin
                        // Button 1 long: dah
                        key_output <= {TYPE_LONG_KEY, 8'b00000001};
                        key_valid <= 1'b1;
                    end else if (first_button_idx == 10) begin
                        // Button 11 long: EXIT
                        key_output <= {TYPE_CTRL_LONG, 8'b00010000};
                        key_valid <= 1'b1;
                    end
                end
            end
            
            MULTI_DETECTED: begin
                freeze <= 1'b1;
                
                if (!key_valid) begin  // Output once
                    second_button_idx <= encode_button(button_pressed ^ (1 << first_button_idx));
                    
                    // Check for valid multi-key combinations
                    if (first_button_idx == 8) begin  // Button 9 + X
                        if (second_button_idx == 6) begin
                            // 9+7: PrevState
                            key_output <= {TYPE_CTRL_MULTI, 8'b00000001};
                            key_valid <= 1'b1;
                        end else if (second_button_idx == 7) begin
                            // 9+8: NextState
                            key_output <= {TYPE_CTRL_MULTI, 8'b00000010};
                            key_valid <= 1'b1;
                        end
                    end
                end
            end
            
            WAIT_RELEASE: begin
                // Keep outputting for continuous polling
                if (current_mode == MODE_MORSE && first_button_idx == 1) begin
                    key_output <= {TYPE_SINGLE_KEY, 8'b00000010};
                    key_valid <= 1'b1;
                end else if (first_button_idx == 8) begin
                    if (current_mode == MODE_ALPHABET)
                        key_output <= {TYPE_CTRL_SINGLE, 8'b00000100};
                    else if (current_mode == MODE_MORSE)
                        key_output <= {TYPE_CTRL_SINGLE, 8'b00000100};
                    key_valid <= 1'b1;
                end
            end
        endcase
    end
end

endmodule