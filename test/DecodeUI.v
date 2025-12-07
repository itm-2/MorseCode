module DecodeUI(
    input wire clk,
    input wire rst_n,
    input wire is_active,          
    input wire key_valid,          
    input wire [3:0] k_data,       
    input wire key_pressed,        
    
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_e,
    output reg [7:0] lcd_data,
    
    output reg piezo,              
    output wire [15:0] piezo_freq, // [필수] 주파수 출력
    output reg req_mode_change,
    
    output wire [3:0] ui_version,
    output reg is_error,           
    output wire [3:0] led_out      // [필수] LED 출력
    );

    // --- Parameters ---
    localparam S_IDLE        = 3'd0;
    localparam S_INPUT       = 3'd1;
    localparam S_TRANSLATING = 3'd2;
    
    // 키 코드 (입력 스위치 값에 맞춰 설정 필요)
    localparam KEY_DOT  = 4'd1;  // 예: 0001
    localparam KEY_DASH = 4'd2;  // 예: 0010
    localparam KEY_BACK = 4'd11; // 예: 1011

    localparam DIT_GAP_LIM = 32'd20_000_000; 

    // --- Registers ---
    reg [2:0] state;
    reg [31:0] silence_timer;
    
    reg [9:0] ibuffer_bits; 
    reg [3:0] ibuffer_len;
    
    reg [7:0] obuffer [0:15]; 
    reg [3:0] cursor;         

    // LCD Control
    reg [31:0] lcd_timer;
    reg [2:0] lcd_step;
    reg [4:0] lcd_idx;
    
    // Piezo Control
    reg [31:0] piezo_timer;
    reg piezo_active;

    integer i;
    
    // --- Assigns ---
    assign ui_version = 4'd2;
    assign led_out = k_data;       // 입력 키 확인용
    assign piezo_freq = 16'd2000;  // 2kHz 톤

    // --- Main Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            req_mode_change <= 1'b0;
            is_error <= 1'b0;
            cursor <= 0;
            ibuffer_len <= 0;
            ibuffer_bits <= 0;
            silence_timer <= 0;
            piezo_active <= 0;
            piezo <= 0;
            piezo_timer <= 0;
            for(i=0; i<16; i=i+1) obuffer[i] <= 8'd32;
        end 
        else begin
            // Piezo Timer
            if (piezo_active) begin
                if (piezo_timer > 0) piezo_timer <= piezo_timer - 1;
                else piezo_active <= 0;
            end
            piezo <= piezo_active; 

            if (!is_active) begin
                state <= S_IDLE;
                req_mode_change <= 1'b0;
                is_error <= 1'b0;
            end 
            else begin
                case (state)
                    S_IDLE: begin
                        cursor <= 0;
                        ibuffer_len <= 0;
                        ibuffer_bits <= 0;
                        is_error <= 1'b0;
                        for(i=0; i<16; i=i+1) obuffer[i] <= 8'd32;
                        state <= S_INPUT;
                        req_mode_change <= 1'b0;
                    end

                    S_INPUT: begin
                        if (key_valid) begin
                            silence_timer <= 0; 
                            is_error <= 1'b0; 
                            
                            if (k_data == KEY_BACK) begin
                                req_mode_change <= 1'b1;
                                state <= S_IDLE;
                            end
                            else if (k_data == KEY_DOT || k_data == KEY_DASH) begin
                                if (ibuffer_len < 5) begin
                                    if (k_data == KEY_DOT) 
                                        ibuffer_bits <= (ibuffer_bits << 2) | 2'b01;
                                    else 
                                        ibuffer_bits <= (ibuffer_bits << 2) | 2'b10;
                                    
                                    ibuffer_len <= ibuffer_len + 1;
                                    
                                    piezo_active <= 1;
                                    piezo_timer <= 32'd10_000_000; 
                                end
                            end
                        end
                        
                        if (!key_pressed && ibuffer_len > 0) begin
                            if (silence_timer < DIT_GAP_LIM)
                                silence_timer <= silence_timer + 1;
                            else begin
                                state <= S_TRANSLATING;
                            end
                        end
                    end

                    S_TRANSLATING: begin
                        case (ibuffer_bits)
                            10'b0000000110: begin obuffer[cursor] <= "A"; is_error <= 0; end 
                            10'b0010010101: begin obuffer[cursor] <= "B"; is_error <= 0; end 
                            10'b0010011001: begin obuffer[cursor] <= "C"; is_error <= 0; end 
                            default: begin 
                                obuffer[cursor] <= "?"; 
                                is_error <= 1; 
                            end
                        endcase
                        
                        if (cursor < 15) cursor <= cursor + 1;
                        else begin
                            for(i=0; i<15; i=i+1) obuffer[i] <= obuffer[i+1];
                            cursor <= 15;
                        end
                        
                        ibuffer_len <= 0;
                        ibuffer_bits <= 0;
                        silence_timer <= 0;
                        state <= S_INPUT;
                    end
                endcase
            end
        end
    end

    // --- LCD Driver Logic ---
    always @(posedge clk) begin
        if (!rst_n) begin
            lcd_e <= 0; lcd_step <= 0; lcd_timer <= 0;
            lcd_rs <= 0; lcd_rw <= 0; lcd_data <= 0; lcd_idx <= 0;
        end
        else if (is_active) begin
            lcd_timer <= lcd_timer + 1;
            if (lcd_timer > 32'd50_000) begin 
                lcd_timer <= 0;
                case (lcd_step)
                    0: begin 
                        lcd_rs <= 0; lcd_rw <= 0; lcd_data <= 8'h80; lcd_e <= 1;
                        lcd_step <= 1;
                    end
                    1: begin lcd_e <= 0; lcd_step <= 2; end
                    2: begin 
                        lcd_rs <= 1; lcd_rw <= 0; 
                        lcd_data <= obuffer[lcd_idx]; 
                        lcd_e <= 1;
                        lcd_step <= 3;
                    end
                    3: begin 
                        lcd_e <= 0; 
                        if (lcd_idx < 15) begin
                            lcd_idx <= lcd_idx + 1;
                            lcd_step <= 2;
                        end else begin
                            lcd_idx <= 0;
                            lcd_step <= 4;
                        end
                    end
                    4: begin 
                        lcd_rs <= 0; lcd_rw <= 0; lcd_data <= 8'hC0; lcd_e <= 1;
                        lcd_step <= 5;
                    end
                    5: begin lcd_e <= 0; lcd_step <= 6; end
                    6: begin 
                        lcd_rs <= 1; lcd_rw <= 0;
                        case(lcd_idx)
                            0: lcd_data <= "M"; 1: lcd_data <= "O"; 2: lcd_data <= "R"; 3: lcd_data <= "S";
                            4: lcd_data <= "E"; 5: lcd_data <= " "; 6: lcd_data <= "D"; 7: lcd_data <= "E";
                            8: lcd_data <= "C"; 9: lcd_data <= "O"; 10: lcd_data <= "D"; 11: lcd_data <= "E";
                            default: lcd_data <= " ";
                        endcase
                        lcd_e <= 1;
                        lcd_step <= 7;
                    end
                    7: begin
                        lcd_e <= 0;
                        if (lcd_idx < 15) begin
                            lcd_idx <= lcd_idx + 1;
                            lcd_step <= 6;
                        end else begin
                            lcd_idx <= 0;
                            lcd_step <= 0; 
                        end
                    end
                endcase
            end
        end
    end

endmodule