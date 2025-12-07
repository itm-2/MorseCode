`timescale 1ns / 1ps

module tb_Button_Debouncer;

    // =========================================================================
    // 1. 변수 및 DUT 연결
    // =========================================================================
    reg clk;
    reg rst_n;
    reg btn_in;
    wire btn_out;

    // 100kHz 환경 설정
    parameter TEST_CLK_FREQ = 100_000;
    parameter TEST_DEBOUNCE_MS = 20;

    Button_Debouncer #(
        .CLK_FREQ(TEST_CLK_FREQ), 
        .DEBOUNCE_MS(TEST_DEBOUNCE_MS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_in(btn_in),
        .btn_out(btn_out)
    );

    // =========================================================================
    // 2. 100kHz 클럭 생성 (Divider 없이 직접 생성)
    // =========================================================================
    initial begin
        clk = 0;
    end
    
    // 5000ns(5us)마다 반전 -> 주기 10us -> 100kHz
    always #5000 clk = ~clk; 

    // =========================================================================
    // 3. 테스트 시나리오
    // =========================================================================
    initial begin
        $display("=== Simulation Start (100kHz Clock) ===");
        
        // 초기화
        rst_n = 0;
        btn_in = 0;
        #2_000_000; // 2ms 대기
        rst_n = 1;
        #2_000_000;

        // ---------------------------------------------------------------------
        // Case 1: 짧은 노이즈 (5ms) -> 무시되어야 함
        // ---------------------------------------------------------------------
        $display("[Time: %t] Noise Injection (5ms)", $time);
        btn_in = 1; 
        #5_000_000; // 5ms 유지 (설정값 20ms 미만)
        btn_in = 0;
        
        #30_000_000; // 충분히 대기 (30ms)

        if (btn_out == 0) $display(" -> PASS: Noise Ignored");
        else              $display(" -> FAIL: Noise Detected");

        // ---------------------------------------------------------------------
        // Case 2: 정상 입력 (30ms) -> 인식되어야 함
        // ---------------------------------------------------------------------
        $display("[Time: %t] Stable Press (30ms)", $time);
        btn_in = 1;
        #30_000_000; // 30ms 유지 (설정값 20ms 이상)
        
        if (btn_out == 1) $display(" -> PASS: Signal Detected");
        else              $display(" -> FAIL: Signal Missed");

        // ---------------------------------------------------------------------
        // Case 3: 버튼 뗌 -> 복귀 확인
        // ---------------------------------------------------------------------
        btn_in = 0;
        #30_000_000;
        
        if (btn_out == 0) $display(" -> PASS: Release Detected");
        else              $display(" -> FAIL: Release Failed");

        $display("=== Simulation End ===");
        $finish;
    end

endmodule