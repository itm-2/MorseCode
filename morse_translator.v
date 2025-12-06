// ========================================
// morse_system_complete.v
// 모든 모듈을 하나의 파일에 통합
// ========================================

// ========================================
// 1. 키 매핑 모듈
// ========================================
module morse_key_mapping (
    input wire clk,
    input wire rst_n,
    input wire [12:1] btn_in,    
    input wire [1:0] mode,       
    input wire freeze_ext,       
    input wire [31:0] timer_threshold, 

    output reg cmd_valid,        
    output reg [10:0] cmd_out,   
    output reg [2:0] current_state,
    output wire [2:0] fsm_state_debug 
);
    parameter ACTIVE_LOW = 0;          
    parameter MIN_PRESS_TIME = 500_000; 

    localparam TYPE_SINGLE      = 3'b000;
    localparam TYPE_LONG        = 3'b001;
    localparam TYPE_MULTI       = 3'b010;
    localparam TYPE_MACRO       = 3'b011;
    localparam TYPE_CTRL_SINGLE = 3'b100;
    localparam TYPE_CTRL_LONG   = 3'b101;
    localparam TYPE_CTRL_MULTI  = 3'b110;

    localparam MODE_ALPHA   = 2'd0;
    localparam MODE_MORSE   = 2'd1;
    localparam MODE_SETTING = 2'd2;

    localparam S_IDLE       = 0;
    localparam S_PRESSED_1  = 1; 
    localparam S_PRESSED_2  = 2; 

    reg [2:0] state;
    assign fsm_state_debug = state; 

    reg [3:0] key1, key2;        
    reg [31:0] press_timer;
    reg [12:1] btn_prev;
    reg internal_freeze;         

    wire [12:1] btn_norm;
    assign btn_norm = ACTIVE_LOW ? ~btn_in : btn_in;

    integer i;

    function [7:0] map_key_value;
        input [1:0] cur_mode;
        input [2:0] cur_st;
        input [3:0] k;
        begin
            map_key_value = 8'd0;
            if (k == 10) map_key_value = 8'h10;
            else if (k == 11) map_key_value = 8'h20;
            else if (k == 12) map_key_value = 8'h40;
            else begin
                case (cur_mode)
                    MODE_ALPHA: begin
                        case (cur_st)
                            3'd0: if(k<=8) map_key_value = "0" + k; 
                            3'd1: case(k) 1:map_key_value="9"; 2:map_key_value="0"; 3:map_key_value="A"; 4:map_key_value="B"; 5:map_key_value="C"; 6:map_key_value="D"; 7:map_key_value="E"; 8:map_key_value="F"; default:map_key_value=0; endcase
                            3'd2: case(k) 1:map_key_value="G"; 2:map_key_value="H"; 3:map_key_value="I"; 4:map_key_value="J"; 5:map_key_value="K"; 6:map_key_value="L"; 7:map_key_value="M"; 8:map_key_value="N"; default:map_key_value=0; endcase
                            3'd3: case(k) 1:map_key_value="O"; 2:map_key_value="P"; 3:map_key_value="Q"; 4:map_key_value="R"; 5:map_key_value="S"; 6:map_key_value="T"; 7:map_key_value="U"; 8:map_key_value="V"; default:map_key_value=0; endcase
                            3'd4: case(k) 1:map_key_value="W"; 2:map_key_value="X"; 3:map_key_value="Y"; 4:map_key_value="Z"; default:map_key_value=0; endcase
                            default: map_key_value = 0;
                        endcase
                        if (k == 9) map_key_value = 8'h20;
                    end
                    MODE_MORSE: begin
                        if (k == 1) map_key_value = 8'd1;
                        else if (k == 2) map_key_value = 8'd2;
                        else if (k == 9) map_key_value = 8'd4;
                        else if (k >= 3 && k <= 8) map_key_value = (1 << (k-3)); 
                    end
                    MODE_SETTING: begin
                        if (k == 1) map_key_value = 8'd4;
                        else if (k == 2) map_key_value = 8'd8;
                    end
                endcase
            end
        end
    endfunction

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
            cmd_valid <= 0;
            btn_prev <= btn_norm;

            if (freeze_ext || internal_freeze) begin
                if (btn_norm == 0) internal_freeze <= 0; 
            end 
            else begin
                case (state)
                    S_IDLE: begin
                        press_timer <= 0;
                        if (btn_norm != 0 && btn_prev == 0) begin
                            if(btn_norm[1]) key1 <= 1; else if(btn_norm[2]) key1 <= 2; else if(btn_norm[3]) key1 <= 3;
                            else if(btn_norm[4]) key1 <= 4; else if(btn_norm[5]) key1 <= 5; else if(btn_norm[6]) key1 <= 6;
                            else if(btn_norm[7]) key1 <= 7; else if(btn_norm[8]) key1 <= 8; else if(btn_norm[9]) key1 <= 9;
                            else if(btn_norm[10]) key1 <= 10; else if(btn_norm[11]) key1 <= 11; else if(btn_norm[12]) key1 <= 12;
                            
                            if (mode == MODE_MORSE && (btn_norm[2] || btn_norm[9])) begin
                                generate_cmd(TYPE_SINGLE, (btn_norm[2]? 4'd2 : 4'd9), 0);
                            end 
                            state <= S_PRESSED_1;
                        end
                    end

                    S_PRESSED_1: begin
                        press_timer <= press_timer + 1;
                        if ((btn_norm & (1 << (key1-1))) == 0) begin
                            if (press_timer < MIN_PRESS_TIME) state <= S_IDLE;
                            else begin
                                if (mode == MODE_MORSE && (key1 == 2 || key1 == 9)) state <= S_IDLE; 
                                else begin
                                    if (press_timer > timer_threshold) generate_cmd(TYPE_LONG, key1, 0);
                                    else generate_cmd(TYPE_SINGLE, key1, 0);
                                    state <= S_IDLE;
                                end
                            end
                        end
                        else if ((btn_norm & ~(1 << (key1-1))) != 0) begin
                            for (i=1; i<=12; i=i+1) if (btn_norm[i] && i != key1) key2 <= i[3:0];
                            state <= S_PRESSED_2;
                        end
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

    task generate_cmd;
        input [2:0] t_type;
        input [3:0] k1;
        input [3:0] k2;
        reg [10:0] tmp_out;
        reg [7:0] val;
        reg is_ctrl;
        begin
            is_ctrl = 0; val = 8'd0;
            if (k1 >= 10 && k1 <= 12) begin
                is_ctrl = 1; val = map_key_value(mode, current_state, k1);
            end
            else begin
                case (mode)
                    MODE_ALPHA: begin
                        if (k1 == 9 && t_type == TYPE_MULTI) begin
                            is_ctrl = 1; 
                            if (k2 == 7) begin 
                                val = 8'd1; 
                                if (current_state == 4) current_state <= 0; else current_state <= current_state + 1;
                            end 
                            else if (k2 == 8) begin 
                                val = 8'd2; 
                                if (current_state == 0) current_state <= 4; else current_state <= current_state - 1;
                            end
                        end
                        else if (k1 == 9) begin is_ctrl = 1; val = 8'h04; end
                        else val = map_key_value(mode, current_state, k1);
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

// ========================================
// 2. UI 컨트롤러 모듈
// ========================================
module morse_ui_controller (
    input wire clk,
    input wire rst_n,
    input wire key_valid,
    input wire [10:0] key_cmd,
    output reg [1:0] current_mode,
    output reg freeze_req,
    input wire [2:0] current_state_in, 

    output reg [127:0] lcd_line1,
    output reg [127:0] lcd_line2,
    output reg piezo_en,
    output reg [31:0] piezo_freq,
    output reg [3:0] led_debug
);
    localparam UI_SELECT = 0;
    localparam UI_ENCODE = 1;
    localparam UI_DECODE = 2;
    
    reg [1:0] ui_state;
    reg [1:0] menu_cursor; 
    
    reg [7:0] buffer [0:127]; 
    reg [6:0] buf_head;
    integer i;

    wire [2:0] cmd_type = key_cmd[10:8];
    wire [7:0] cmd_data = key_cmd[7:0];
    
    localparam TYPE_SINGLE      = 3'b000;
    localparam TYPE_LONG        = 3'b001;
    localparam TYPE_CTRL_SINGLE = 3'b100;
    
    // Piezo 타이머 (50MHz 기준)
    reg [31:0] piezo_timer;
    reg piezo_active;
    
    // 모스 부호 타이밍 (50MHz 기준)
    localparam DOT_TIME  = 5_000_000;  // 0.1초 (점)
    localparam DASH_TIME = 15_000_000; // 0.3초 (대시)
    localparam BEEP_FREQ = 1_000;      // 1kHz 주파수 (50,000 클럭 주기)
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ui_state <= UI_SELECT;
            current_mode <= 2; 
            menu_cursor <= 1;
            lcd_line1 <= 0; lcd_line2 <= 0;
            piezo_en <= 0;
            piezo_freq <= 0;
            buf_head <= 0;
            freeze_req <= 0;
            piezo_timer <= 0;
            piezo_active <= 0;
        end else begin
            // Piezo 타이머 처리
            if (piezo_active) begin
                if (piezo_timer > 0) begin
                    piezo_timer <= piezo_timer - 1;
                    piezo_en <= 1;
                    piezo_freq <= BEEP_FREQ;
                end else begin
                    piezo_en <= 0;
                    piezo_active <= 0;
                end
            end else begin
                piezo_en <= 0;
            end
            
            led_debug <= {key_valid, ui_state, 1'b0}; 

            case(ui_state)
                UI_SELECT: begin
                    current_mode <= 2; 
                    lcd_line1[127:112] <= ">>";
                    case(menu_cursor)
                        0: begin lcd_line1[111:0] <= " SETTING      "; lcd_line2 <= "   ENCODE       "; end
                        1: begin lcd_line1[111:0] <= " ENCODE       "; lcd_line2 <= "   DECODE       "; end
                        2: begin lcd_line1[111:0] <= " DECODE       "; lcd_line2 <= "   SETTING      "; end
                    endcase

                    if(key_valid) begin
                        if(cmd_data == 8'd4) begin 
                            if(menu_cursor > 0) menu_cursor <= menu_cursor - 1; else menu_cursor <= 2;
                        end
                        else if(cmd_data == 8'd8) begin 
                            if(menu_cursor < 2) menu_cursor <= menu_cursor + 1; else menu_cursor <= 0;
                        end
                        else if(cmd_data == 8'h40) begin 
                            buf_head <= 0;
                            for(i=0; i<128; i=i+1) buffer[i] <= " ";
                            if(menu_cursor == 1) ui_state <= UI_ENCODE;
                            else if(menu_cursor == 2) ui_state <= UI_DECODE;
                        end
                    end
                end

                UI_ENCODE: begin
                    current_mode <= 0; 
                    lcd_line1[127:80] <= "ENCODE Mode S:";
                    lcd_line1[79:72]  <= "0" + current_state_in; 
                    lcd_line1[71:0]   <= "         ";
                    
                    for(i=0; i<16; i=i+1) begin
                        if(buf_head > 16) lcd_line2[127 - i*8 -: 8] <= buffer[buf_head - 16 + i];
                        else if(i < buf_head) lcd_line2[127 - i*8 -: 8] <= buffer[i];
                        else lcd_line2[127 - i*8 -: 8] <= " ";
                    end

                    if(key_valid) begin
                        if(cmd_type == TYPE_CTRL_SINGLE && cmd_data == 8'h20) begin
                            ui_state <= UI_SELECT;
                        end
                        else if(cmd_type == TYPE_SINGLE && cmd_data >= 8'h20 && cmd_data <= 8'h7A) begin
                            if(buf_head < 127) begin
                                buffer[buf_head] <= cmd_data;
                                buf_head <= buf_head + 1;
                                // 문자 입력 시 짧은 비프음
                                piezo_timer <= DOT_TIME;
                                piezo_active <= 1;
                            end
                        end
                        // ENTER 키 (0x40) - 전체 문자열 재생
                        else if(cmd_type == TYPE_CTRL_SINGLE && cmd_data == 8'h40) begin
                            // 긴 확인음
                            piezo_timer <= DASH_TIME;
                            piezo_active <= 1;
                        end
                    end
                end

                UI_DECODE: begin
                    current_mode <= 1; 
                    lcd_line1 <= "DECODE Mode     ";
                    for(i=0; i<16; i=i+1) begin
                        if(buf_head > 16) lcd_line2[127 - i*8 -: 8] <= buffer[buf_head - 16 + i];
                        else if(i < buf_head) lcd_line2[127 - i*8 -: 8] <= buffer[i];
                        else lcd_line2[127 - i*8 -: 8] <= " ";
                    end

                    if(key_valid) begin
                        if(cmd_type == TYPE_CTRL_SINGLE && cmd_data == 8'h20) begin
                            ui_state <= UI_SELECT;
                        end
                        // Key 1: Dot (짧게) / Dash (길게)
                        else if(cmd_data == 1) begin 
                            if(cmd_type == TYPE_LONG) begin 
                                buffer[buf_head] <= "-"; 
                                buf_head <= buf_head + 1;
                                piezo_timer <= DASH_TIME; // 대시 소리
                                piezo_active <= 1;
                            end 
                            else begin 
                                buffer[buf_head] <= "."; 
                                buf_head <= buf_head + 1;
                                piezo_timer <= DOT_TIME; // 점 소리
                                piezo_active <= 1;
                            end
                        end
                        // Key 2: Dot만
                        else if(cmd_data == 2) begin 
                            buffer[buf_head] <= "."; 
                            buf_head <= buf_head + 1;
                            piezo_timer <= DOT_TIME;
                            piezo_active <= 1;
                        end
                        // Key 9: Space
                        else if(cmd_data == 4) begin 
                            buffer[buf_head] <= " "; 
                            buf_head <= buf_head + 1;
                            // 스페이스는 소리 없음
                        end
                    end
                end
            endcase
        end
    end
endmodule

// ========================================
// 3. LCD 드라이버
// ========================================
module lcd_driver (
    input wire clk,
    input wire rst_n,
    input wire [127:0] line1,
    input wire [127:0] line2,
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_e,
    output reg [7:0] lcd_data
);
    localparam CNT_CMD = 2_500;   
    localparam CNT_INIT = 2_000_000;

    reg [3:0] state;
    reg [31:0] cnt;
    reg [3:0] char_idx; 
    reg line_sel;       

    localparam S_INIT = 0, S_FUNC = 1, S_ON = 2, S_CLR = 3, S_MODE = 4, S_ADDR = 5, S_WRITE = 6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_INIT;
            cnt <= 0; char_idx <= 0; line_sel <= 0;
            lcd_e <= 0; lcd_rs <= 0; lcd_rw <= 0;
        end else begin
            case (state)
                S_INIT: if (cnt > CNT_INIT) begin cnt<=0; state<=S_FUNC; end else cnt<=cnt+1;
                S_FUNC: begin 
                    lcd_rs<=0; lcd_rw<=0; lcd_data<=8'h38;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin cnt<=0; state<=S_ON; end else cnt<=cnt+1;
                end
                S_ON: begin 
                    lcd_rs<=0; lcd_rw<=0; lcd_data<=8'h0C;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin cnt<=0; state<=S_CLR; end else cnt<=cnt+1;
                end
                S_CLR: begin 
                    lcd_rs<=0; lcd_rw<=0; lcd_data<=8'h01;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>100000+22) begin cnt<=0; state<=S_MODE; end else cnt<=cnt+1;
                end
                S_MODE: begin 
                    lcd_rs<=0; lcd_rw<=0; lcd_data<=8'h06;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin cnt<=0; state<=S_ADDR; end else cnt<=cnt+1;
                end
                S_ADDR: begin
                    lcd_rs<=0; lcd_rw<=0;
                    if(!line_sel) lcd_data <= 8'h80 + char_idx; else lcd_data <= 8'hC0 + char_idx;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin cnt<=0; state<=S_WRITE; end else cnt<=cnt+1;
                end
                S_WRITE: begin
                    lcd_rs<=1; lcd_rw<=0;
                    if(!line_sel) lcd_data <= line1[127 - char_idx*8 -: 8];
                    else          lcd_data <= line2[127 - char_idx*8 -: 8];
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin 
                        cnt<=0; 
                        if(char_idx==15) begin char_idx<=0; line_sel<=~line_sel; end 
                        else char_idx<=char_idx+1;
                        state<=S_ADDR; 
                    end else cnt<=cnt+1;
                end
            endcase
        end
    end
endmodule

// ========================================
// 4. Piezo 드라이버
// ========================================
module piezo_driver (
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [31:0] freq_div,
    output reg piezo_out
);
    reg [31:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 0; piezo_out <= 0;
        end else begin
            if(en && freq_div > 0) begin
                if(cnt >= freq_div) begin
                    cnt <= 0;
                    piezo_out <= ~piezo_out;
                end else cnt <= cnt + 1;
            end else begin
                piezo_out <= 0;
                cnt <= 0;
            end
        end
    end
endmodule

// ========================================
// 5. Servo 드라이버
// ========================================
module servo_driver (
    input wire clk,
    input wire rst_n,
    input wire [2:0] angle_idx,
    output reg pwm_out
);
    reg [31:0] cnt;
    reg [31:0] high_time;

    always @(*) begin
        case(angle_idx)
            0: high_time = 30_000;
            1: high_time = 45_000;
            2: high_time = 60_000;
            3: high_time = 75_000;
            4: high_time = 90_000;
            default: high_time = 75_000;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 0; pwm_out <= 0;
        end else begin
            if(cnt < 1_000_000) cnt <= cnt + 1;
            else cnt <= 0;

            if(cnt < high_time) pwm_out <= 1;
            else pwm_out <= 0;
        end
    end
endmodule

// ========================================
// 6. 최상위 모듈
// ========================================
module morse_system_top (
    input wire clk,
    input wire rst_n,
    input wire [12:1] btn_key, 
    
    output wire [3:0] led_debug,
    output wire piezo_out,
    output wire servo_pwm,
    output wire lcd_rs, lcd_rw, lcd_e,
    output wire [7:0] lcd_data
);
    wire key_valid;
    wire [10:0] key_cmd;
    wire [1:0] current_mode;
    wire [2:0] servo_state;   
    wire freeze_req;
    wire [2:0] fsm_state_debug;

    wire piezo_en;
    wire [31:0] piezo_freq;
    wire [127:0] lcd_l1, lcd_l2;

    morse_key_mapping u_keymap (
        .clk(clk),
        .rst_n(rst_n),
        .btn_in(btn_key),
        .mode(current_mode),
        .freeze_ext(freeze_req),
        .timer_threshold(32'd10_000_000),
        .cmd_valid(key_valid),
        .cmd_out(key_cmd),
        .current_state(servo_state),
        .fsm_state_debug(fsm_state_debug)
    );
    
    morse_ui_controller u_ui (
        .clk(clk),
        .rst_n(rst_n),
        .key_valid(key_valid),
        .key_cmd(key_cmd),
        .current_mode(current_mode),
        .freeze_req(freeze_req),
        .current_state_in(servo_state), 
        .lcd_line1(lcd_l1),
        .lcd_line2(lcd_l2),
        .piezo_en(piezo_en),
        .piezo_freq(piezo_freq),
        .led_debug()
    );

    lcd_driver u_lcd (
        .clk(clk), .rst_n(rst_n),
        .line1(lcd_l1), .line2(lcd_l2),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_e(lcd_e), .lcd_data(lcd_data)
    );
    
    piezo_driver u_piezo (
        .clk(clk), .rst_n(rst_n),
        .en(piezo_en),
        .freq_div(piezo_freq),
        .piezo_out(piezo_out)
    );
    
    servo_driver u_servo (
        .clk(clk), .rst_n(rst_n),
        .angle_idx(servo_state),
        .pwm_out(servo_pwm)
    );

    assign led_debug = {fsm_state_debug[1:0], btn_key[1], btn_key[2]};

endmodule