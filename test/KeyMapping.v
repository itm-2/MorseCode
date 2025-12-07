`timescale 1ns / 1ps

module KeyMapping (
    input wire clk,
    input wire rst_n,
    
    input wire [3:0] key_val,       // 1~12
    input wire key_pressed,         
    
    // 시스템 상태 입력
    input wire [1:0] mode,          // 0:Alpha, 1:Morse, 2:Setting
    input wire [2:0] current_state, // Alpha Mode State (0~4)
    input wire [31:0] timer_threshold, 
    
    output reg [10:0] mapped_key,   // [10:8] Type, [7:0] Data
    output reg key_valid,           
    output reg freeze_active        
);

    // KeyAction.txt 정의
    localparam MODE_ALPHA   = 2'd0;
    localparam MODE_MORSE   = 2'd1;
    localparam MODE_SETTING = 2'd2;

    // Type Definition (Source 135)
    localparam T_SINGLE      = 3'b000;
    localparam T_LONG        = 3'b001;
    localparam T_MULTI       = 3'b010;
    localparam T_MACRO       = 3'b011;
    localparam T_CTL_SINGLE  = 3'b100;
    localparam T_CTL_LONG    = 3'b101;
    localparam T_CTL_MULTI   = 3'b110;

    // FSM
    localparam S_IDLE       = 2'd0;
    localparam S_PRESSING   = 2'd1;
    localparam S_FREEZE     = 2'd2;

    reg [1:0] fsm_state;
    reg [3:0] first_key;
    reg [31:0] press_timer;
    reg prev_key_pressed;

    // Helper: Alpha Char Map
    function [7:0] get_alpha_char;
        input [2:0] st;
        input [3:0] k;
        begin
            get_alpha_char = 8'h00;
            case (st)
                3'd0: if (k >= 1 && k <= 8) get_alpha_char = "0" + k; // '1'~'8'
                3'd1: case(k) 1:get_alpha_char="9"; 2:get_alpha_char="0"; 3:get_alpha_char="A"; 4:get_alpha_char="B"; 5:get_alpha_char="C"; 6:get_alpha_char="D"; 7:get_alpha_char="E"; 8:get_alpha_char="F"; endcase
                3'd2: if (k >= 1 && k <= 8) get_alpha_char = "G" + (k - 1); // G~N
                3'd3: if (k >= 1 && k <= 8) get_alpha_char = "O" + (k - 1); // O~V
                3'd4: case(k) 1:get_alpha_char="W"; 2:get_alpha_char="X"; 3:get_alpha_char="Y"; 4:get_alpha_char="Z"; endcase
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_state <= S_IDLE;
            first_key <= 0;
            press_timer <= 0;
            mapped_key <= 0;
            key_valid <= 0;
            prev_key_pressed <= 0;
            freeze_active <= 0;
        end else begin
            key_valid <= 0; // Pulse init
            prev_key_pressed <= key_pressed;
            
            // Freeze Release Logic
            if (!key_pressed && fsm_state == S_FREEZE) begin
                fsm_state <= S_IDLE;
                freeze_active <= 0;
            end

            case (fsm_state)
                S_IDLE: begin
                    if (key_pressed && !prev_key_pressed) begin // Rising Edge
                        first_key <= key_val;
                        press_timer <= 0;

                        // [Exception] Morse Mode Button 2 -> Immediate Single (Source 144)
                        if (mode == MODE_MORSE && key_val == 2) begin
                            mapped_key <= {T_SINGLE, 8'b0000_0010}; // Input 9
                            key_valid <= 1;
                        end
                        // [Exception] Morse Mode Button 9 (Pause) -> Immediate Ctl Single (Source 156)
                        else if (mode == MODE_MORSE && key_val == 9) begin
                            mapped_key <= {T_CTL_SINGLE, 8'b0000_0100}; // Input 18
                            key_valid <= 1;
                        end
                        else begin
                            fsm_state <= S_PRESSING;
                        end
                    end
                end

                S_PRESSING: begin
                    press_timer <= press_timer + 1;

                    // 1. Multi Key Detect
                    if (key_pressed && key_val != first_key) begin
                        // Alpha Mode 9+7(Next), 9+8(Prev) - Source 154
                        if (mode == MODE_ALPHA && first_key == 9) begin
                            if (key_val == 7) begin
                                mapped_key <= {T_CTL_MULTI, 8'b0000_0001}; // Input 16
                                key_valid <= 1;
                            end else if (key_val == 8) begin
                                mapped_key <= {T_CTL_MULTI, 8'b0000_0010}; // Input 17
                                key_valid <= 1;
                            end else begin
                                mapped_key <= 0; // Invalid
                                key_valid <= 1;
                            end
                        end else begin
                            mapped_key <= 0; // General Invalid Multi
                            key_valid <= 1;
                        end
                        fsm_state <= S_FREEZE;
                        freeze_active <= 1;
                    end

                    // 2. Key Release -> Single or Long Decision
                    else if (!key_pressed) begin
                        if (press_timer >= timer_threshold) begin 
                            // --- Long Key ---
                            if (first_key == 11) mapped_key <= {T_CTL_LONG, 8'b0001_0000}; // Exit (Input 21)
                            else if (mode == MODE_MORSE && first_key == 1) mapped_key <= {T_LONG, 8'b0000_0001}; // Dash (Input 8)
                            else mapped_key <= 0; // Others Invalid Long
                        end 
                        else begin
                            // --- Single Key ---
                            // Common Control
                            if (first_key == 11) mapped_key <= {T_CTL_SINGLE, 8'b0001_0000}; // Back (Input 20)
                            else if (first_key == 12) mapped_key <= {T_CTL_SINGLE, 8'b0010_0000}; // Enter
                            else if (mode == MODE_ALPHA) begin
                                if (first_key <= 8) mapped_key <= {T_SINGLE, get_alpha_char(current_state, first_key)};
                                else if (first_key == 9) mapped_key <= {T_CTL_SINGLE, 8'b0000_0100}; // Space (Input 19)
                            end
                            else if (mode == MODE_MORSE) begin
                                if (first_key == 1) mapped_key <= {T_SINGLE, 8'b0000_0001}; // Dot (Input 7)
                                else if (first_key >= 3 && first_key <= 8) mapped_key <= {T_MACRO, (8'd1 << (first_key - 3))}; // Macros (Input 12, 13)
                            end
                            else if (mode == MODE_SETTING) begin
                                if (first_key == 1) mapped_key <= {T_SINGLE, 8'b0000_0100}; // UP (Input 25)
                                else if (first_key == 2) mapped_key <= {T_SINGLE, 8'b0000_1000}; // DOWN (Input 26)
                            end
                        end
                        
                        if (key_valid == 0) key_valid <= 1;
                        fsm_state <= S_IDLE;
                    end

                    // 3. Timer Overflow -> Auto Long Key (Only for Morse Dash)
                    else if (press_timer == timer_threshold + 1) begin
                        if (mode == MODE_MORSE && first_key == 1) begin
                             mapped_key <= {T_LONG, 8'b0000_0001}; // Dash
                             key_valid <= 1;
                             fsm_state <= S_FREEZE; // Freeze until release
                             freeze_active <= 1;
                        end
                    end
                end

                S_FREEZE: begin
                    mapped_key <= 0;
                end
            endcase
        end
    end
endmodule