`timescale 1ns / 1ps

module Button_Debouncer (
    input wire clk,       // [시스템 표준] 100kHz 클럭 입력
    input wire rst_n,     // Active Low Reset
    input wire btn_in,    // 노이즈가 섞인 버튼 입력
    output reg btn_out    // 디바운싱 완료된 깨끗한 출력
);

    // =========================================================================
    // 1. 파라미터 정의 (100kHz 기준)
    // =========================================================================
    parameter CLK_FREQ    = 100_000; // 100kHz
    parameter DEBOUNCE_MS = 20;      // 20ms
    
    // 목표 카운트: 100,000 * 0.02 = 2,000
    localparam CNT_MAX = (CLK_FREQ / 1000) * DEBOUNCE_MS;

    // =========================================================================
    // 2. 내부 변수
    // =========================================================================
    reg [31:0] cnt;
    reg btn_sync_0;       // 싱크로나이저 1
    reg btn_sync_1;       // 싱크로나이저 2

    // =========================================================================
    // 3. 동작 로직
    // =========================================================================
    
    // 3-1. 입력 동기화 (외부 신호 -> 내부 클럭)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    // 3-2. 디바운싱 카운터
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            btn_out <= 1'b0;
        end else begin
            // 현재 출력과 입력(동기화됨)이 다르면 카운트 시작
            if (btn_out != btn_sync_1) begin
                cnt <= cnt + 1;
                
                // 20ms(2000클럭) 동안 유지되면 값 변경
                if (cnt >= CNT_MAX) begin
                    btn_out <= btn_sync_1;
                    cnt <= 0;
                end
            end else begin
                // 중간에 값이 튀면 카운터 초기화
                cnt <= 0;
            end
        end
    end

endmodule