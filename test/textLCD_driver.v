`timescale 1ns / 1ps

module TextLCD_Driver (
    input wire clk,           // 100kHz
    input wire rst_n,

    // --- 사용자 요청 인터페이스 ---
    input wire req,           // 1: 출력 요청 (Pulse)
    input wire [1:0] row,     // 0: 윗줄, 1: 아랫줄
    input wire [3:0] col,     // 가로 좌표 (0 ~ 15)
    input wire [7:0] data,    // 출력할 문자 (ASCII Code)
    
    output reg busy,          // 1: 동작 중
    output reg done,          // 1: 출력 완료 (Pulse)

    // --- LCD 하드웨어 핀 ---
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_e,
    output reg [7:0] lcd_data
);

    // 파라미터 (100kHz 기준)
    localparam CNT_15MS  = 1500; 
    localparam CNT_5MS   = 500;  
    localparam CNT_100US = 10;   
    localparam CNT_CMD   = 10;   
    localparam CNT_CLR   = 200;  

    // 명령어
    localparam CMD_WAKEUP     = 8'h30;
    localparam CMD_FUNC_SET   = 8'h38;
    localparam CMD_DISP_OFF   = 8'h08; 
    localparam CMD_DISP_CLEAR = 8'h01;
    localparam CMD_ENTRY_MODE = 8'h06;
    localparam CMD_DISP_ON    = 8'h0C;

    // FSM 상태
    localparam S_PWR_WAIT   = 0;
    localparam S_INIT_1     = 1;
    localparam S_INIT_2     = 2;
    localparam S_INIT_3     = 3;
    localparam S_FUNC_SET   = 4;
    localparam S_DISP_OFF   = 5;
    localparam S_DISP_CLR   = 6;
    localparam S_ENTRY_MODE = 7;
    localparam S_DISP_ON    = 8;
    localparam S_IDLE       = 9;  
    localparam S_SET_ADDR   = 10; 
    localparam S_WRITE_DATA = 11; 
    localparam S_DONE_PULSE = 12; 

    reg [4:0] state;
    reg [15:0] wait_cnt;
    
    // [수정 1] 입력 데이터 보존을 위한 래치 레지스터 추가
    reg [7:0] latched_data;
    reg [6:0] target_addr; // 계산된 주소 저장

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_PWR_WAIT;
            wait_cnt <= 0;
            busy <= 1;
            done <= 0;
            lcd_e <= 0; lcd_rs <= 0; lcd_rw <= 0; lcd_data <= 0;
            latched_data <= 0;
            target_addr <= 0;
        end else begin
            done <= 0; 

            case (state)
                // --- 초기화 시퀀스 (동일) ---
                S_PWR_WAIT: begin
                    busy <= 1;
                    if (wait_cnt >= CNT_15MS) begin wait_cnt <= 0; state <= S_INIT_1; end
                    else wait_cnt <= wait_cnt + 1;
                end
                S_INIT_1: begin 
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_WAKEUP;
                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;
                    if (wait_cnt >= (CNT_5MS + 5)) begin wait_cnt <= 0; state <= S_INIT_2; end
                    else wait_cnt <= wait_cnt + 1;
                end
                S_INIT_2: begin 
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_WAKEUP;
                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;
                    if (wait_cnt >= (CNT_100US + 5)) begin wait_cnt <= 0; state <= S_INIT_3; end
                    else wait_cnt <= wait_cnt + 1;
                end
                S_INIT_3: begin 
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_WAKEUP;
                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;
                    if (wait_cnt >= (CNT_CMD + 2)) begin wait_cnt <= 0; state <= S_FUNC_SET; end
                    else wait_cnt <= wait_cnt + 1;
                end
                S_FUNC_SET: begin 
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_FUNC_SET;
                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;
                    if (wait_cnt >= (CNT_CMD + 2)) begin wait_cnt <= 0; state <= S_DISP_OFF; end
                    else wait_cnt <= wait_cnt + 1;
                end
                S_DISP_OFF: begin 
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_DISP_OFF;
                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;
                    if (wait_cnt >= (CNT_CMD + 2)) begin wait_cnt <= 0; state <= S_DISP_CLR; end
                    else wait_cnt <= wait_cnt + 1;
                end
                S_DISP_CLR: begin 
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_DISP_CLEAR;
                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;
                    if (wait_cnt >= (CNT_CLR + 2)) begin wait_cnt <= 0; state <= S_ENTRY_MODE; end
                    else wait_cnt <= wait_cnt + 1;
                end
                S_ENTRY_MODE: begin 
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_ENTRY_MODE;
                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;
                    if (wait_cnt >= (CNT_CMD + 2)) begin wait_cnt <= 0; state <= S_DISP_ON; end
                    else wait_cnt <= wait_cnt + 1;
                end
                S_DISP_ON: begin 
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_DISP_ON;
                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;
                    if (wait_cnt >= (CNT_CMD + 2)) begin wait_cnt <= 0; state <= S_IDLE; end
                    else wait_cnt <= wait_cnt + 1;
                end

                // --- [수정 2] 동작 로직 (Latch 적용) ---
                S_IDLE: begin
                    lcd_e <= 0;
                    wait_cnt <= 0;
                    busy <= 0; 

                    if (req == 1'b1) begin
                        busy <= 1; 
                        
                        // [중요] 요청이 들어온 순간 데이터와 주소를 캡쳐(Latch)
                        latched_data <= data;
                        
                        // 좌표 계산하여 저장
                        if (row == 1'b0) target_addr <= {3'b000, col};
                        else             target_addr <= {3'b100, col};
                        
                        state <= S_SET_ADDR;
                    end
                end

                S_SET_ADDR: begin
                    // 1. 커서 위치 이동 (저장된 target_addr 사용)
                    lcd_rs <= 0; lcd_rw <= 0;
                    lcd_data <= {1'b1, target_addr};

                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;

                    if (wait_cnt >= (CNT_CMD + 2)) begin 
                        wait_cnt <= 0; 
                        state <= S_WRITE_DATA; 
                    end
                    else wait_cnt <= wait_cnt + 1;
                end

                S_WRITE_DATA: begin
                    // 2. 글자 쓰기 (저장된 latched_data 사용)
                    lcd_rs <= 1; lcd_rw <= 0;
                    lcd_data <= latched_data;

                    if (wait_cnt == 1) lcd_e <= 1; else if (wait_cnt == 2) lcd_e <= 0;

                    if (wait_cnt >= (CNT_CMD + 2)) begin 
                        wait_cnt <= 0; 
                        state <= S_DONE_PULSE; 
                    end
                    else wait_cnt <= wait_cnt + 1;
                end

                S_DONE_PULSE: begin
                    done <= 1;       
                    state <= S_IDLE; 
                end

                default: state <= S_PWR_WAIT;
            endcase
        end
    end
endmodule