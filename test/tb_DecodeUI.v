`timescale 1ns / 1ps

module DecodeUI_tb;
    reg clk, rst_n;
    reg [10:0] key_mapped;
    reg key_valid;
    reg key_pressed;
    
    wire [7:0] lcd_char_out;
    reg [3:0] lcd_query_addr;
    wire piezo_enable;
    wire [31:0] piezo_freq;
    wire [7:0] led_out;
    wire is_error;
    wire [1:0] req_key_mode;
    wire req_mode_change;
    wire [2:0] ui_version;

    DecodeUI uut (
        .clk(clk),
        .rst_n(rst_n),
        .key_mapped(key_mapped),
        .key_valid(key_valid),
        .key_pressed(key_pressed),
        .dit_gap_lim(32'd10000),
        .req_key_mode(req_key_mode),
        .req_mode_change(req_mode_change),
        .lcd_char_out(lcd_char_out),
        .lcd_query_addr(lcd_query_addr),
        .piezo_enable(piezo_enable),
        .piezo_freq(piezo_freq),
        .led_out(led_out),
        .is_error(is_error),
        .ui_version(ui_version)
    );

    initial clk = 0;
    always #5000 clk = ~clk;  // 10us period

    task send_morse;
        input [2:0] key_type;
        input [7:0] key_data;
        input integer duration_ms;
        begin
            $display("\n[%0t] === Sending %s (%dms) ===", 
                     $time, (key_type == 3'b000) ? "Dit" : "Dah", duration_ms);
            
            @(negedge clk);
            key_mapped = {key_type, key_data};
            key_valid = 1;
            key_pressed = 1;
            
            @(posedge clk);
            $display("[%0t] Key pressed", $time);
            
            @(negedge clk);
            key_valid = 0;
            
            repeat(duration_ms * 100 - 1) @(posedge clk);
            
            @(negedge clk);
            key_pressed = 0;
            $display("[%0t] Key released", $time);
            
            @(posedge clk);
            $display("[%0t] After release: state=%d, ibuffer_len=%d, bits=%05b", 
                     $time, uut.state, uut.ibuffer_len, uut.ibuffer_bits);
        end
    endtask

    initial begin
        $display("\n========================================");
        $display("  DecodeUI Detailed Debug");
        $display("========================================\n");
        
        rst_n = 0;
        key_mapped = 0;
        key_valid = 0;
        key_pressed = 0;
        lcd_query_addr = 0;
        
        repeat(10) @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        $display("[%0t] Reset done. Initial state=%d, obuffer_idx=%d\n", 
                 $time, uut.state, uut.obuffer_idx);
        
        // Dit (.)
        send_morse(3'b000, 8'd1, 100);
        
        // 간격 (50ms)
        $display("\n[%0t] === Gap 50ms ===", $time);
        repeat(5000) @(posedge clk);
        $display("[%0t] After gap: state=%d, silence_timer=%d", 
                 $time, uut.state, uut.silence_timer);
        
        // Dah (-)
        send_morse(3'b001, 8'd1, 300);
        
        // Silence 대기 - 매 1ms마다 체크
        $display("\n[%0t] === Waiting for translation ===", $time);
        $display("Monitoring silence_timer every 1ms...\n");
        
        for (integer i = 0; i < 200; i = i + 1) begin
            repeat(100) @(posedge clk);  // 1ms
            
            if (i % 10 == 0) begin  // 10ms마다 출력
                $display("[%0t] t=%3dms: state=%d, silence_timer=%5d, ibuffer_len=%d", 
                         $time, i, uut.state, uut.silence_timer, uut.ibuffer_len);
            end
            
            // 상태 변화 감지
            if (uut.state == 1) begin  // TRANS
                $display("\n[%0t] ★★★ TRANS state detected! ★★★", $time);
                $display("ibuffer_len=%d, bits=%05b", uut.ibuffer_len, uut.ibuffer_bits);
                break;
            end
        end
        
        repeat(1000) @(posedge clk);  // 추가 대기
        
        $display("\n========================================");
        $display("  Final State");
        $display("========================================");
        $display("state:         %d", uut.state);
        $display("silence_timer: %d", uut.silence_timer);
        $display("ibuffer_len:   %d", uut.ibuffer_len);
        $display("ibuffer_bits:  %05b", uut.ibuffer_bits);
        $display("obuffer_idx:   %d", uut.obuffer_idx);
        
        if (uut.obuffer_idx > 10) begin
            $display("\n? Translation occurred!");
            $display("obuffer[0] = '%c' (0x%02X)", uut.obuffer[0], uut.obuffer[0]);
        end else begin
            $display("\n? No translation!");
            $display("\nDiagnosis:");
            if (uut.silence_timer < 10000) begin
                $display("  → silence_timer (%d) never reached dit_gap_lim (10000)", 
                         uut.silence_timer);
            end else if (uut.ibuffer_len == 0) begin
                $display("  → ibuffer_len is 0 (no morse code stored)");
            end else if (uut.state != 0) begin
                $display("  → Stuck in state %d", uut.state);
            end else begin
                $display("  → Unknown issue");
            end
        end
        
        $display("========================================\n");
        
        $finish;
    end
    
    // 상태 변화 모니터
    always @(posedge clk) begin
        if (uut.state == 1) begin  // TRANS
            $display("[%0t] ★★★ IN TRANS STATE ★★★", $time);
        end
    end
    
    // silence_timer 임계값 모니터
    always @(posedge clk) begin
        if (uut.silence_timer == 10000 && uut.state == 0) begin
            $display("[%0t] ★★★ silence_timer = 10000 but still in INPUT! ★★★", $time);
            $display("    ibuffer_len = %d", uut.ibuffer_len);
        end
    end
endmodule