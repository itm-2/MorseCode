module Top(
    input wire clk,
    input wire rst_n,
    
    // 키패드 모듈 대신 직접 입력 받음 (스위치 4개, 버튼 1개 등)
    input wire [3:0] key_val,  // 키 값 (예: 스위치)
    input wire key_trig,       // 키 입력 신호 (예: 버튼)
    
    output wire lcd_rs,
    output wire lcd_rw,
    output wire lcd_e,
    output wire [7:0] lcd_data,
    
    output wire piezo_out,     // 부저 출력
    output wire [3:0] led      // LED 출력
    );

    // --- UI 모듈 연결 신호 ---
    wire ui_piezo_enable;
    wire [15:0] ui_freq;
    wire ui_req_mode_change;
    wire [3:0] ui_version;
    wire ui_is_error;
    wire [3:0] ui_led_out;

    // --- DecodeUI 인스턴스 ---
    DecodeUI u_ui (
        .clk(clk),
        .rst_n(rst_n),
        .is_active(1'b1),        
        .key_valid(key_trig),    // 버튼 누르면 입력 유효
        .k_data(key_val),        // 스위치 값을 데이터로 사용
        .key_pressed(key_trig),  // 버튼 누름 상태
        
        // LCD
        .lcd_rs(lcd_rs),
        .lcd_rw(lcd_rw),
        .lcd_e(lcd_e),
        .lcd_data(lcd_data),
        
        // Sound & LED & Status (에러 나던 포트들 연결 완료)
        .piezo(ui_piezo_enable), 
        .piezo_freq(ui_freq),    
        .req_mode_change(ui_req_mode_change),
        .ui_version(ui_version),
        .is_error(ui_is_error),  
        .led_out(ui_led_out)     
    );

    // --- LED 출력 ---
    // 에러면 전체 점멸, 아니면 UI에서 준 값 출력
    assign led = ui_is_error ? 4'b1111 : ui_led_out;

    // --- 피에조 소리 발생기 (Tone Generator) ---
    // UI에서 받은 주파수(ui_freq)로 소리 출력
    reg [31:0] tone_cnt;
    reg tone_clk;
    
    // 100MHz 클럭 기준 (보드에 맞게 수정 가능)
    wire [31:0] toggle_value = (ui_freq > 0) ? (100_000_000 / ui_freq) / 2 : 32'd100000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tone_cnt <= 0;
            tone_clk <= 0;
        end else if (ui_piezo_enable) begin
            if (tone_cnt >= toggle_value) begin
                tone_cnt <= 0;
                tone_clk <= ~tone_clk;
            end else begin
                tone_cnt <= tone_cnt + 1;
            end
        end else begin
            tone_cnt <= 0;
            tone_clk <= 0;
        end
    end

    assign piezo_out = tone_clk;

endmodule