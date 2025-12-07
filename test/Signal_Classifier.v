`timescale 1ns / 1ps

module Signal_Classifier (
    input wire clk,         // 100kHz 시스템 클럭
    input wire rst_n,       // Reset
    input wire btn_in,      // Debounced Button Input (H: Pressed)
    
    output reg valid,       // 1: 판독 완료 (버튼 뗄 때 1클럭 Pulse)
    output reg is_long      // 0: Short, 1: Long (valid일 때만 유효)
);

    // =========================================================================
    // 1. 파라미터 정의 (100kHz 기준)
    // =========================================================================
    // Long Press 판단 기준: 300ms
    // 100,000Hz * 0.3s = 30,000 Ticks
    parameter LONG_PRESS_TH = 30000; 

    // =========================================================================
    // 2. 내부 변수
    // =========================================================================
    reg [31:0] press_cnt;
    reg btn_prev; // Edge 검출용

    // =========================================================================
    // 3. 동작 로직
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            press_cnt <= 0;
            btn_prev <= 0;
            valid <= 0;
            is_long <= 0;
        end else begin
            valid <= 0; // Pulse 초기화
            btn_prev <= btn_in;

            if (btn_in == 1'b1) begin
                // A. 버튼 누르는 중: 시간 측정
                // Overflow 방지하며 카운팅
                if (press_cnt < LONG_PRESS_TH + 10) 
                    press_cnt <= press_cnt + 1;
            end 
            else begin
                // B. 버튼을 뗐을 때 (Falling Edge)
                if (btn_prev == 1'b1) begin
                    valid <= 1'b1; // 결과 나왔다고 알림
                    
                    // C. 시간 판별
                    if (press_cnt >= LONG_PRESS_TH) is_long <= 1'b1;
                    else                            is_long <= 1'b0;
                end
                
                // 카운터 초기화
                press_cnt <= 0;
            end
        end
    end

endmodule