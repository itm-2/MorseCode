`timescale 1ns / 1ps

module tb_SelectUI;

    reg clk;
    reg rst_n;
    reg is_active;
    
    reg [7:0] key_data;
    reg key_valid;
    reg lcd_busy;
    reg lcd_done;

    wire lcd_req;
    wire [1:0] lcd_row;
    wire [3:0] lcd_col;
    wire [7:0] lcd_char;
    wire change_req;
    wire [3:0] next_ui_id;

    // 캡처 변수
    reg captured_req;
    reg [3:0] captured_uuid;

    // DUT 연결 (일반화 테스트용 파라미터)
    SelectUI #(
        .MENU_COUNT(3),
        .STR_LEN(7),
        .MENU_STR_FLAT("SETTINGENCODEDECODE "),
        .NEXT_UUID_FLAT({4'd3, 4'd2, 4'd4}) // {Dec, Enc, Set}
    ) uut (
        .clk(clk), .rst_n(rst_n), .is_active(is_active),
        .key_data(key_data), .key_valid(key_valid),
        .lcd_busy(lcd_busy), .lcd_done(lcd_done),
        .lcd_req(lcd_req), .lcd_row(lcd_row), .lcd_col(lcd_col), .lcd_char(lcd_char),
        .change_req(change_req), .next_ui_id(next_ui_id)
    );

    initial clk = 0;
    always #5000 clk = ~clk;

    // --- 캡처 로직 ---
    always @(posedge clk) begin
        if (change_req) begin
            captured_req <= 1;
            captured_uuid <= next_ui_id;
        end
    end

    // --- LCD Driver Sim (Background) ---
    always begin
        wait(lcd_req == 1);
        @(posedge clk);
        lcd_busy = 1;
        #50000;
        lcd_busy = 0;
        lcd_done = 1;
        @(posedge clk);
        lcd_done = 0;
        wait(lcd_req == 0);
    end

    // --- [중요] 안정적인 키 입력 Task ---
    task press_key(input [7:0] k_data);
        begin
            captured_req = 0;
            captured_uuid = 0;
            
            // 1. 데이터 세팅
            key_data = k_data;
            key_valid = 1;
            
            // 2. [수정] 2클럭 동안 꾹 눌러줌 (놓침 방지)
            @(posedge clk); 
            @(posedge clk);
            
            // 3. 뗌
            key_valid = 0;
            
            // 4. 처리 대기
            #200000; 
        end
    endtask

    initial begin
        $display("=== SelectUI Fixed Test Start ===");
        
        rst_n = 0; is_active = 0; key_data = 0; key_valid = 0; lcd_busy = 0; lcd_done = 0;
        captured_req = 0; captured_uuid = 0;

        #20000; rst_n = 1; is_active = 1; 
        
        // 초기 렌더링 대기
        #5000000; 

        // 1. DOWN Key
        $display("[Test 1] Key DOWN (Select 2nd Item)");
        press_key(8'h81); 
        
        // 2. ENTER Key
        $display("[Test 2] Key ENTER");
        press_key(8'h0D); 
        
        // 2번째(Index 1) 메뉴의 UUID는 2 (ENCODE)여야 함
        if (captured_req == 1 && captured_uuid == 2) 
            $display(" -> PASS: Change Request to UUID 2");
        else 
            $display(" -> FAIL: Req=%b, UUID=%d (Expected 2)", captured_req, captured_uuid);

        $finish;
    end

endmodule