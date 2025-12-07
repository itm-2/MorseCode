`timescale 1ns / 1ps

module tb_Signal_Classifier;

    reg clk;
    reg rst_n;
    reg btn_in;
    wire valid;
    wire is_long;

    // 테스트 시간 단축을 위해 Threshold를 낮춤 (30ms = 3000 ticks)
    Signal_Classifier #(
        .LONG_PRESS_TH(3000) 
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_in(btn_in),
        .valid(valid),
        .is_long(is_long)
    );

    // 100kHz 클럭 생성
    initial clk = 0;
    always #5000 clk = ~clk;

    initial begin
        $display("=== Signal Classifier Test Start ===");
        rst_n = 0; btn_in = 0;
        #20000; rst_n = 1; #20000;

        // 1. Short Press Test (10ms 누름)
        // Threshold(30ms)보다 짧으므로 is_long = 0 기대
        $display("Test 1: Short Press (10ms)");
        btn_in = 1; 
        #10000000; // 10ms (100kHz * 1000)
        btn_in = 0; // Release -> 이때 valid가 1이 되어야 함
        
        #10000; // 결과 확인 대기
        if (valid == 1 && is_long == 0) $display(" -> PASS: Short Detected");
        else                            $display(" -> FAIL: valid=%b, long=%b", valid, is_long);

        #20000000; // 대기

        // 2. Long Press Test (50ms 누름)
        // Threshold(30ms)보다 길므로 is_long = 1 기대
        $display("Test 2: Long Press (50ms)");
        btn_in = 1;
        #50000000; // 50ms
        btn_in = 0; // Release

        #10000; 
        if (valid == 1 && is_long == 1) $display(" -> PASS: Long Detected");
        else                            $display(" -> FAIL: valid=%b, long=%b", valid, is_long);

        $finish;
    end
endmodule