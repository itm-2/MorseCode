`timescale 1ns / 1ps

module tb_top;

    // Inputs
    reg clk;
    reg rst_n;
    reg [3:0] key_val;
    reg key_trig;

    // Outputs
    wire lcd_rs;
    wire lcd_rw;
    wire lcd_e;
    wire [7:0] lcd_data;
    wire piezo_out;  // [수정] Top.v의 포트명과 일치시킴
    wire [3:0] led;

    // Instantiate the Unit Under Test (UUT)
    Top uut (
        .clk(clk), 
        .rst_n(rst_n), 
        .key_val(key_val), 
        .key_trig(key_trig), 
        .lcd_rs(lcd_rs), 
        .lcd_rw(lcd_rw), 
        .lcd_e(lcd_e), 
        .lcd_data(lcd_data), 
        .piezo_out(piezo_out), // [수정] 에러 발생하던 부분 해결
        .led(led)
    );

    // Clock Generation (100MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        key_val = 0;
        key_trig = 0;

        // Wait 100 ns for global reset to finish
        #100;
        rst_n = 1;
        #100;
        
        // --- 테스트 시나리오 시작 ---
        
        // 1. 점(Dot) 입력 (A의 앞부분)
        key_val = 4'd1; // KEY_DOT
        key_trig = 1;   // 버튼 누름
        #20;
        key_trig = 0;   // 버튼 뗌
        #100000;        // 처리 대기

        // 2. 선(Dash) 입력 (A의 뒷부분)
        key_val = 4'd2; // KEY_DASH
        key_trig = 1;
        #20;
        key_trig = 0;
        #100000;

        // 3. 대기 (자동 번역 트리거 확인)
        #50000000; // 충분한 시간 대기
        
        $stop;
    end
      
endmodule