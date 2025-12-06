module morse_key_mapping (
    input wire clk,
    input wire rst_n,
    input wire [12:1] btn_in,    // 1~12 Keypad Input
    input wire [1:0] mode,       // 0:Alpha, 1:Morse, 2:Setting
    input wire freeze_ext,       // External Freeze Signal from UI
    input wire [31:0] timer_threshold, // Threshold for Long Key Detection

    output reg cmd_valid,        // Pulse high when command is ready
    output reg [10:0] cmd_out,   // 3-bit Type + 8-bit Data
    output reg [2:0] current_state // Internal State (0~4) for Servo/Mapping
);

    // --- Configuration ---
    parameter ACTIVE_LOW = 1;          // 1: Button gives 0 when pressed (Default for FPGA boards)
    parameter MIN_PRESS_TIME = 50_000; // 1ms Debounce Threshold at 50MHz

    // --- Command Types ---
    localparam TYPE_SINGLE      = 3'b000;
    localparam TYPE_LONG        = 3'b001;
    localparam TYPE_MULTI       = 3'b010;
    localparam TYPE_MACRO       = 3'b011;
    localparam TYPE_CTRL_SINGLE = 3'b100;
    localparam TYPE_CTRL_LONG   = 3'b101;
    localparam TYPE_CTRL_MULTI  = 3'b110;

    // --- Modes ---
    localparam MODE_ALPHA   = 2'd0;
    localparam MODE_MORSE   = 2'd1;
    localparam MODE_SETTING = 2'd2;

    // --- FSM States ---
    localparam S_IDLE       = 0;
    localparam S_PRESSED_1  = 1; 
    localparam S_PRESSED_2  = 2; 
    localparam S_FREEZE     = 3; 

    reg [2:0] state;
    reg [3:0] key1, key2;        
    reg [31:0] press_timer;
    reg [12:1] btn_prev;
    reg internal_freeze;         

    // Normalize Input (Active High logic: 1 means pressed)
    wire [12:1] btn_norm;
    assign btn_norm = ACTIVE_LOW ? ~btn_in : btn_in;

    integer i;

    // --- Key Mapping Helper Function ---
    function [7:0] map_key_value;
        input [1:0] cur_mode;
        input [2:0] cur_st;
        input [3:0] k;
        begin
            map_key_value = 8'd0;
            // 1. Common Control Keys
            if (k == 10) map_key_value = 8'h10; // CLEAR
            else if (k == 11) map_key_value = 8'h20; // BACK
            else if (k == 12) map_key_value = 8'h40; // ENTER
            else begin
                case (cur_mode)
                    MODE_ALPHA: begin
                        case (cur_st)
                            3'd0: if(k<=8) map_key_value = "0" + k; // '1'...'8'
                            3'd1: case(k) 1:map_key_value="9"; 2:map_key_value="0"; 3:map_key_value="A"; 4:map_key_value="B"; 5:map_key_value="C"; 6:map_key_value="D"; 7:map_key_value="E"; 8:map_key_value="F"; default:map_key_value=0; endcase
                            3'd2: case(k) 1:map_key_value="G"; 2:map_key_value="H"; 3:map_key_value="I"; 4:map_key_value="J"; 5:map_key_value="K"; 6:map_key_value="L"; 7:map_key_value="M"; 8:map_key_value="N"; default:map_key_value=0; endcase
                            3'd3: case(k) 1:map_key_value="O"; 2:map_key_value="P"; 3:map_key_value="Q"; 4:map_key_value="R"; 5:map_key_value="S"; 6:map_key_value="T"; 7:map_key_value="U"; 8:map_key_value="V"; default:map_key_value=0; endcase
                            3'd4: case(k) 1:map_key_value="W"; 2:map_key_value="X"; 3:map_key_value="Y"; 4:map_key_value="Z"; default:map_key_value=0; endcase
                            default: map_key_value = 0;
                        endcase
                        if (k == 9) map_key_value = 8'h20; // SPACE
                    end
                    MODE_MORSE: begin
                        if (k == 1) map_key_value = 8'd1; // Button 1
                        else if (k == 2) map_key_value = 8'd2; // Button 2
                        else if (k == 9) map_key_value = 8'd4; // PAUSE
                        else if (k >= 3 && k <= 8) map_key_value = (1 << (k-3)); // Macro
                    end
                    MODE_SETTING: begin
                        if (k == 1) map_key_value = 8'd4; // UP
                        else if (k == 2) map_key_value = 8'd8; // DOWN
                    end
                endcase
            end
        end
    endfunction

    // --- Main FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            key1 <= 0; key2 <= 0;
            press_timer <= 0;
            btn_prev <= 0;
            current_state <= 0;
            cmd_valid <= 0; cmd_out <= 0;
            internal_freeze <= 0;
        end else begin
            cmd_valid <= 0; // Pulse default low
            btn_prev <= btn_norm;

            // Global Freeze Check
            if (freeze_ext || internal_freeze) begin
                // CRITICAL FIX: Use btn_norm instead of btn_in
                if (btn_norm == 0) internal_freeze <= 0; 
            end 
            else begin
                case (state)
                    S_IDLE: begin
                        press_timer <= 0;
                        // Rising Edge Detection
                        if (btn_norm != 0 && btn_prev == 0) begin
                            // Priority Encoder
                            if(btn_norm[1]) key1 <= 1; else if(btn_norm[2]) key1 <= 2; else if(btn_norm[3]) key1 <= 3;
                            else if(btn_norm[4]) key1 <= 4; else if(btn_norm[5]) key1 <= 5; else if(btn_norm[6]) key1 <= 6;
                            else if(btn_norm[7]) key1 <= 7; else if(btn_norm[8]) key1 <= 8; else if(btn_norm[9]) key1 <= 9;
                            else if(btn_norm[10]) key1 <= 10; else if(btn_norm[11]) key1 <= 11; else if(btn_norm[12]) key1 <= 12;
                            
                            // Morse Mode Exception (Immediate Trigger)
                            if (mode == MODE_MORSE && (btn_norm[2] || btn_norm[9])) begin
                                generate_cmd(TYPE_SINGLE, (btn_norm[2]? 4'd2 : 4'd9), 0);
                            end 
                            state <= S_PRESSED_1;
                        end
                    end

                    S_PRESSED_1: begin
                        press_timer <= press_timer + 1;

                        // Check Release
                        if ((btn_norm & (1 << (key1-1))) == 0) begin
                            // Debounce: Ignore very short presses
                            if (press_timer < MIN_PRESS_TIME) begin
                                state <= S_IDLE;
                            end
                            else begin
                                if (mode == MODE_MORSE && (key1 == 2 || key1 == 9)) begin
                                    state <= S_IDLE; // Already handled
                                end
                                else begin
                                    if (press_timer > timer_threshold) generate_cmd(TYPE_LONG, key1, 0);
                                    else generate_cmd(TYPE_SINGLE, key1, 0);
                                    state <= S_IDLE;
                                end
                            end
                        end
                        // Check Multi Key
                        else if ((btn_norm & ~(1 << (key1-1))) != 0) begin
                            for (i=1; i<=12; i=i+1) begin
                                if (btn_norm[i] && i != key1) key2 <= i[3:0];
                            end
                            state <= S_PRESSED_2;
                        end
                        // Check Long Key Hold
                        else if (press_timer > timer_threshold + 1000) begin
                            if (!(mode == MODE_MORSE && (key1 == 2 || key1 == 9))) begin
                                generate_cmd(TYPE_LONG, key1, 0);
                                internal_freeze <= 1; 
                                state <= S_IDLE; 
                            end
                        end
                    end

                    S_PRESSED_2: begin
                        generate_cmd(TYPE_MULTI, key1, key2);
                        internal_freeze <= 1; 
                        state <= S_IDLE;      
                    end
                    default: state <= S_IDLE;
                endcase
            end
        end
    end

    // --- Output Generator Task ---
    task generate_cmd;
        input [2:0] t_type;
        input [3:0] k1;
        input [3:0] k2;
        reg [10:0] tmp_out;
        reg [7:0] val;
        reg is_ctrl;
        begin
            is_ctrl = 0;
            val = 8'd0;
            
            if (k1 >= 10 && k1 <= 12) begin
                is_ctrl = 1;
                val = map_key_value(mode, current_state, k1);
            end
            else begin
                case (mode)
                    MODE_ALPHA: begin
                        if (k1 == 9 && t_type == TYPE_MULTI) begin
                            is_ctrl = 1; 
                            if (k2 == 7) begin // Next State
                                val = 8'd1; 
                                if (current_state == 4) current_state <= 0;
                                else current_state <= current_state + 1;
                            end 
                            else if (k2 == 8) begin // Prev State
                                val = 8'd2; 
                                if (current_state == 0) current_state <= 4;
                                else current_state <= current_state - 1;
                            end
                        end
                        else if (k1 == 9) begin
                             is_ctrl = 1; val = 8'h04; 
                        end
                        else begin
                             val = map_key_value(mode, current_state, k1);
                        end
                    end
                    MODE_MORSE: begin
                        if (k1 == 9) begin is_ctrl = 1; val = 8'h04; end
                        else if (k1 >= 3 && k1 <= 8) val = (1 << (k1 - 3)); 
                        else val = map_key_value(mode, current_state, k1);
                    end
                    MODE_SETTING: val = map_key_value(mode, current_state, k1);
                endcase
            end

            if (is_ctrl) begin
                if (t_type == TYPE_SINGLE) tmp_out = {TYPE_CTRL_SINGLE, val};
                else if (t_type == TYPE_LONG) tmp_out = {TYPE_CTRL_LONG, val};
                else tmp_out = {TYPE_CTRL_MULTI, val};
            end 
            else if (mode == MODE_MORSE && k1 >= 3 && k1 <= 8) tmp_out = {TYPE_MACRO, val};
            else tmp_out = {t_type, val};

            cmd_out <= tmp_out;
            cmd_valid <= 1;
        end
    endtask
endmodule