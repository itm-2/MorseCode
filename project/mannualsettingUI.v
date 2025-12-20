module ManualTimingSettingUI #(
    parameter CLK_HZ = 50_000_000
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // UI 활성화 신호
    input  wire        ui_active,
    
    // 버튼 입력 (edge-detected)
    input  wire        btn1_pressed,   // 난이도 DOWN
    input  wire        btn2_pressed,   // 난이도 UP
    input  wire        btn11_pressed,  // BACK
    input  wire        btn12_pressed,  // ENTER
    
    // 외부에서 난이도 강제 설정 (초기화 등)
    input  wire        ext_level_set,
    input  wire [1:0]  ext_level,
    
    // 디스플레이 출력
    output reg  [127:0] display_text,  // ASCII 문자열
    output reg         text_valid,
    
    // 타이밍 파라미터 출력
    output reg  [31:0] long_key_cycles,
    output reg  [31:0] dit_gap_cycles,
    output reg  [31:0] timeout_cycles,
    output reg  [31:0] space_cycles,
    output reg  [31:0] dit_time,
    output reg  [31:0] dah_time,
    output reg  [31:0] dit_gap,
    output reg  [15:0] tone_freq,
    
    // 설정 적용 완료 신호
    output reg         settings_applied,
    
    // BACK 신호
    output reg         back_requested,
    
    // 피에조 출력
    output wire        piezo_out
);

    // ========== 난이도 레벨 정의 ==========
    localparam [1:0] LEVEL_BEGINNER     = 2'd0;
    localparam [1:0] LEVEL_INTERMEDIATE = 2'd1;
    localparam [1:0] LEVEL_ADVANCED     = 2'd2;
    localparam [1:0] LEVEL_EXPERT       = 2'd3;
    
    // ========== 기준값 (BEGINNER) ==========
    localparam [31:0] BASE_LONG_KEY = 32'd25_000_000;  // 500ms
    localparam [31:0] BASE_DIT_GAP  = 32'd12_500_000;  // 250ms
    localparam [31:0] BASE_DIT_TIME = 32'd12_500_000;  // 250ms
    localparam [31:0] BASE_DAH_TIME = 32'd37_500_000;  // 750ms
    localparam [15:0] BASE_TONE_FREQ = 16'd440;        // 440Hz
    
    // ========== "CQ DE 123" 비트스트림 ==========
    localparam [127:0] DEMO_BITSTREAM = {
        // C: 10 0 10 0 11
        2'b10, 1'b0, 2'b10, 1'b0, 2'b11,
        // Q: 10 10 0 10 11
        2'b10, 2'b10, 1'b0, 2'b10, 2'b11,
        // SPACE: 1111
        4'b1111,
        // D: 10 0 0 11
        2'b10, 1'b0, 1'b0, 2'b11,
        // E: 0 11
        1'b0, 2'b11,
        // SPACE: 1111
        4'b1111,
        // 1: 0 10 10 10 10 11
        1'b0, 2'b10, 2'b10, 2'b10, 2'b10, 2'b11,
        // 2: 0 0 10 10 10 11
        1'b0, 1'b0, 2'b10, 2'b10, 2'b10, 2'b11,
        // 3: 0 0 0 10 10 11
        1'b0, 1'b0, 1'b0, 2'b10, 2'b10, 2'b11,
        // 나머지 패딩
        56'b0
    };
    
    localparam [8:0] DEMO_BIT_LENGTH = 9'd72;
    
    // ========== 내부 레지스터 ==========
    reg [1:0] current_level;
    reg [1:0] saved_level;
    reg [1:0] prev_level;
    
    // ========== 난이도별 문자열 (ASCII) ==========
    localparam [127:0] STR_BEGINNER     = "BEGINNER";
    localparam [127:0] STR_INTERMEDIATE = "INTERMEDIATE";
    localparam [127:0] STR_ADVANCED     = "ADVANCED";
    localparam [127:0] STR_EXPERT       = "EXPERT";
    
    // ========== 타이밍 계산 ==========
    reg [31:0] multiplier_num;
    reg [31:0] multiplier_den;
    
    always @(*) begin
        case (current_level)
            LEVEL_BEGINNER:     begin multiplier_num = 32'd2;  multiplier_den = 32'd2; end
            LEVEL_INTERMEDIATE: begin multiplier_num = 32'd3;  multiplier_den = 32'd2; end
            LEVEL_ADVANCED:     begin multiplier_num = 32'd6;  multiplier_den = 32'd2; end
            LEVEL_EXPERT:       begin multiplier_num = 32'd12; multiplier_den = 32'd2; end
            default:            begin multiplier_num = 32'd2;  multiplier_den = 32'd2; end
        endcase
    end
    
    wire [31:0] calc_long_key = (BASE_LONG_KEY * multiplier_num) / multiplier_den;
    wire [31:0] calc_dit_gap  = (BASE_DIT_GAP  * multiplier_num) / multiplier_den;
    wire [31:0] calc_dit_time = (BASE_DIT_TIME * multiplier_num) / multiplier_den;
    wire [31:0] calc_dah_time = (BASE_DAH_TIME * multiplier_num) / multiplier_den;
    wire [31:0] calc_timeout  = calc_dit_gap * 32'd6;
    wire [31:0] calc_space    = calc_timeout * 32'd2;
    
    // ========== 피에조 플레이어 제어 신호 ==========
    reg        player_start;
    wire       player_busy;
    wire       player_done;
    reg        playback_enabled;
    
    // ========== 재생 상태 FSM ==========
    localparam ST_IDLE    = 2'd0;
    localparam ST_WAIT    = 2'd1;
    localparam ST_PLAYING = 2'd2;
    
    reg [1:0]  play_state;
    reg [31:0] wait_counter;
    localparam RESTART_DELAY = 32'd2_500_000; // 50ms
    
    // ========== 초기화 및 외부 설정 ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saved_level <= LEVEL_BEGINNER;
            current_level <= LEVEL_BEGINNER;
            prev_level <= LEVEL_BEGINNER;
        end else if (ext_level_set) begin
            saved_level <= ext_level;
            if (ui_active)
                current_level <= ext_level;
        end else if (ui_active && btn12_pressed) begin
            saved_level <= current_level;
        end
    end
    
    // ========== UI 활성화 시 초기화 ==========
    reg ui_active_prev;
    wire ui_just_activated = ui_active && !ui_active_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ui_active_prev <= 1'b0;
        end else begin
            ui_active_prev <= ui_active;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_level <= LEVEL_BEGINNER;
        end else if (ui_just_activated) begin
            current_level <= saved_level;
            prev_level <= saved_level;
        end
    end
    
    // ========== 버튼 입력 처리 ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_level <= LEVEL_BEGINNER;
        end else if (ui_active) begin
            if (btn2_pressed && current_level != LEVEL_EXPERT) begin
                current_level <= current_level + 1'b1;
            end
            
            if (btn1_pressed && current_level != LEVEL_BEGINNER) begin
                current_level <= current_level - 1'b1;
            end
        end
    end
    
    // ========== 레벨 변경 감지 ==========
    wire level_changed = (current_level != prev_level) && ui_active;
    
    // ========== 재생 제어 FSM ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            play_state <= ST_IDLE;
            player_start <= 1'b0;
            wait_counter <= 32'd0;
            prev_level <= LEVEL_BEGINNER;
            playback_enabled <= 1'b0;
        end else if (ui_active) begin
            player_start <= 1'b0;
            playback_enabled <= 1'b1;
            
            case (play_state)
                ST_IDLE: begin
                    if (level_changed) begin
                        prev_level <= current_level;
                        wait_counter <= 32'd0;
                        play_state <= ST_WAIT;
                    end
                end
                
                ST_WAIT: begin
                    if (wait_counter >= RESTART_DELAY) begin
                        player_start <= 1'b1;
                        play_state <= ST_PLAYING;
                    end else begin
                        wait_counter <= wait_counter + 32'd1;
                    end
                end
                
                ST_PLAYING: begin
                    if (level_changed) begin
                        prev_level <= current_level;
                        wait_counter <= 32'd0;
                        play_state <= ST_WAIT;
                    end else if (player_done) begin
                        player_start <= 1'b1; // 반복 재생
                    end else if (btn11_pressed || btn12_pressed) begin
                        play_state <= ST_IDLE;
                    end
                end
                
                default: play_state <= ST_IDLE;
            endcase
        end else begin
            play_state <= ST_IDLE;
            prev_level <= current_level;
            playback_enabled <= 1'b0;
        end
    end
    
    // ========== 디스플레이 텍스트 출력 ==========
    always @(*) begin
        text_valid = ui_active;
        case (current_level)
            LEVEL_BEGINNER:     display_text = STR_BEGINNER;
            LEVEL_INTERMEDIATE: display_text = STR_INTERMEDIATE;
            LEVEL_ADVANCED:     display_text = STR_ADVANCED;
            LEVEL_EXPERT:       display_text = STR_EXPERT;
            default:            display_text = STR_BEGINNER;
        endcase
    end
    
    // ========== ENTER 시 파라미터 적용 ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            long_key_cycles <= BASE_LONG_KEY;
            dit_gap_cycles  <= BASE_DIT_GAP;
            timeout_cycles  <= BASE_DIT_GAP * 32'd6;
            space_cycles    <= BASE_DIT_GAP * 32'd12;
            dit_time        <= BASE_DIT_TIME;
            dah_time        <= BASE_DAH_TIME;
            dit_gap         <= BASE_DIT_GAP;
            tone_freq       <= BASE_TONE_FREQ;
            settings_applied <= 1'b0;
        end else if (ui_active && btn12_pressed) begin
            long_key_cycles <= calc_long_key;
            dit_gap_cycles  <= calc_dit_gap;
            timeout_cycles  <= calc_timeout;
            space_cycles    <= calc_space;
            dit_time        <= calc_dit_time;
            dah_time        <= calc_dah_time;
            dit_gap         <= calc_dit_gap;
            tone_freq       <= BASE_TONE_FREQ;
            settings_applied <= 1'b1;
        end else begin
            settings_applied <= 1'b0;
        end
    end
    
    // ========== BACK 처리 ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            back_requested <= 1'b0;
        end else if (ui_active && btn11_pressed) begin
            back_requested <= 1'b1;
        end else begin
            back_requested <= 1'b0;
        end
    end
    
    // ========== 피에조 플레이어 인스턴스 ==========
    wire piezo_internal;
    
    EncoderPiezoPlayer #(
        .CLK_FREQ(CLK_HZ),
        .TONE_FREQ(BASE_TONE_FREQ)
    ) demo_player (
        .clk(clk),
        .rst_n(rst_n),
        .start(player_start),
        .bitstream(DEMO_BITSTREAM),
        .bit_length(DEMO_BIT_LENGTH),
        .DitTime(calc_dit_time),
        .DahTime(calc_dah_time),
        .DitGap(calc_dit_gap),
        .busy(player_busy),
        .done(player_done),
        .piezo_out(piezo_internal)
    );
    
    // ========== 피에조 출력 게이팅 ==========
    assign piezo_out = (ui_active && playback_enabled) ? piezo_internal : 1'b0;

endmodule