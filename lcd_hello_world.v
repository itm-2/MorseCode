module lcd_hello_world (
    input wire clk,          // 시스템 클럭 (예: 50MHz)
    input wire rst_n,        // Active Low 리셋
    output reg lcd_rs,       // 0: 명령어, 1: 데이터
    output reg lcd_rw,       // 0: 쓰기, 1: 읽기 (항상 0)
    output reg lcd_e,        // Enable 신호
    output reg [7:0] lcd_data // 데이터 버스 DB0-DB7
);

    // -------------------------------------------------------------------------
    // 파라미터 및 상수 정의 (50MHz 클럭 기준)
    // -------------------------------------------------------------------------
    parameter CLK_FREQ = 50_000_000;
    
    // 타이밍 상수
    localparam CNT_15MS  = 750_000; // Power On 대기 (>15ms)
    localparam CNT_5MS   = 250_000; // 첫 번째 0x30 후 대기 (>4.1ms)
    localparam CNT_100US = 5_000;   // 두 번째 0x30 후 대기 (>100us)
    localparam CNT_CMD   = 2_500;   // 일반 명령어 실행 시간 (>37us)
    localparam CNT_CLR   = 100_000; // Display Clear 실행 시간 (>1.52ms)

    // 명령어 정의
    localparam CMD_WAKEUP     = 8'h30;
    localparam CMD_FUNC_SET   = 8'h38; // 8-bit, 2-line, 5x8 font
    localparam CMD_DISP_OFF   = 8'h08; // Display Off
    localparam CMD_DISP_CLEAR = 8'h01; // Display Clear
    localparam CMD_ENTRY_MODE = 8'h06; // Inc addr, No shift
    localparam CMD_DISP_ON    = 8'h0C; // Display On, Cursor Off, Blink Off

    // 상태 머신 정의
    localparam S_IDLE        = 0;
    localparam S_INIT_WAIT   = 1;
    localparam S_INIT_1      = 2;
    localparam S_INIT_2      = 3;
    localparam S_INIT_3      = 4;
    localparam S_FUNC_SET    = 5;
    localparam S_DISP_OFF    = 6;
    localparam S_DISP_CLR    = 7;
    localparam S_ENTRY_MODE  = 8;
    localparam S_DISP_ON     = 9;
    localparam S_WRITE_DATA  = 10;
    localparam S_DONE        = 11;

    reg [4:0] state;
    reg [31:0] wait_cnt;    // 타이머 카운터
    reg [3:0] char_idx;     // 문자열 인덱스

    // 출력할 메시지 저장
    reg [7:0] message [0:10];

    initial begin
        message[0] = "H"; message[1] = "E"; message[2] = "L"; message[3] = "L";
        message[4] = "O"; message[5] = " "; message[6] = "W"; message[7] = "O";
        message[8] = "R"; message[9] = "L"; message[10] = "D";
    end

    // -------------------------------------------------------------------------
    // 동작 로직
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            wait_cnt <= 0;
            char_idx <= 0;
            lcd_e <= 0;
            lcd_rs <= 0;
            lcd_rw <= 0;
            lcd_data <= 8'h00;
        end else begin
            case (state)
                // 1. 전원 인가 후 대기
                S_IDLE: begin
                    wait_cnt <= 0;
                    state <= S_INIT_WAIT;
                end
                
                S_INIT_WAIT: begin
                    if (wait_cnt >= CNT_15MS) begin
                        wait_cnt <= 0;
                        state <= S_INIT_1;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 2. 초기화 시퀀스 (0x30 3번 전송)
                // 첫 번째 0x30
                S_INIT_1: begin
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_WAKEUP;
                    
                    // Enable Pulse 생성 (20 clock = 400ns width)
                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    // 지연 시간 체크
                    if (wait_cnt >= (CNT_5MS + 20)) begin
                        wait_cnt <= 0;
                        state <= S_INIT_2;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 두 번째 0x30
                S_INIT_2: begin
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_WAKEUP;
                    
                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    if (wait_cnt >= (CNT_100US + 20)) begin
                        wait_cnt <= 0;
                        state <= S_INIT_3;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 세 번째 0x30
                S_INIT_3: begin
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_WAKEUP;
                    
                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    if (wait_cnt >= (CNT_CMD + 20)) begin
                        wait_cnt <= 0;
                        state <= S_FUNC_SET;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 3. Function Set
                S_FUNC_SET: begin
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_FUNC_SET;
                    
                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    if (wait_cnt >= (CNT_CMD + 20)) begin
                        wait_cnt <= 0;
                        state <= S_DISP_OFF;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 4. Display OFF
                S_DISP_OFF: begin
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_DISP_OFF;

                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    if (wait_cnt >= (CNT_CMD + 20)) begin
                        wait_cnt <= 0;
                        state <= S_DISP_CLR;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 5. Display Clear (오래 걸림)
                S_DISP_CLR: begin
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_DISP_CLEAR;

                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    if (wait_cnt >= (CNT_CLR + 20)) begin // 1.52ms 이상
                        wait_cnt <= 0;
                        state <= S_ENTRY_MODE;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 6. Entry Mode Set
                S_ENTRY_MODE: begin
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_ENTRY_MODE;

                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    if (wait_cnt >= (CNT_CMD + 20)) begin
                        wait_cnt <= 0;
                        state <= S_DISP_ON;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 7. Display ON
                S_DISP_ON: begin
                    lcd_rs <= 0; lcd_rw <= 0; lcd_data <= CMD_DISP_ON;

                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    if (wait_cnt >= (CNT_CMD + 20)) begin
                        wait_cnt <= 0;
                        char_idx <= 0;
                        state <= S_WRITE_DATA;
                    end else wait_cnt <= wait_cnt + 1;
                end

                // 8. 데이터 쓰기 (HELLO WORLD)
                S_WRITE_DATA: begin
                    lcd_rs <= 1; // 데이터 모드
                    lcd_rw <= 0;
                    lcd_data <= message[char_idx];

                    if (wait_cnt == 0) lcd_e <= 1;
                    else if (wait_cnt == 20) lcd_e <= 0;

                    // 문자 하나 쓰고 대기
                    if (wait_cnt >= (CNT_CMD + 20)) begin
                        wait_cnt <= 0;
                        if (char_idx == 10) state <= S_DONE; // 11글자(0~10) 완료
                        else char_idx <= char_idx + 1;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                // 9. 완료 (정지)
                S_DONE: begin
                    lcd_e <= 0;
                    state <= S_DONE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule