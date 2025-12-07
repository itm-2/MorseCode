`timescale 1ns / 1ps

module KeyMap (
    // 입력: 현재 시스템 상태
    input wire [1:0] mode,    // 0: Alphabet, 1: Morse, 2: Setting
    input wire [2:0] state,   // Page Index (0 ~ 4)
    input wire [3:0] key_idx, // 눌린 버튼 번호 (1 ~ 12)

    // 출력: 매핑된 데이터
    output reg [7:0] key_data // ASCII 문자 또는 명령어 코드
);

    // =========================================================================
    // 1. 파라미터 정의 (명세서 기준)
    // =========================================================================
    // Mode 정의
    localparam MODE_ALPHABET = 2'd0;
    localparam MODE_MORSE    = 2'd1;
    localparam MODE_SETTING  = 2'd2;

    // 제어 문자 정의 (ASCII 표준 활용)
    localparam KEY_SPACE = 8'h20; // Space
    localparam KEY_BS    = 8'h08; // Backspace (BACK)
    localparam KEY_CR    = 8'h0D; // Carriage Return (ENTER)
    localparam KEY_ESC   = 8'h1B; // Escape (CLEAR 등으로 사용)
    
    // 커스텀 명령 (Setting 모드 등)
    localparam CMD_UP    = 8'h80; // MSB를 1로 두어 일반 문자와 구분
    localparam CMD_DOWN  = 8'h81;
    localparam CMD_PAUSE = 8'h82;

    // =========================================================================
    // 2. 매핑 로직 (Combinational Logic)
    // =========================================================================
    always @(*) begin
        // 기본값 (매핑 안 된 경우 0)
        key_data = 8'h00; 

        // ---------------------------------------------------------------------
        // 공통 제어 키 (10, 11, 12번 버튼) - 모든 모드 공통
        // [명세] 10: CLEAR, 11: BACK, 12: ENTER
        // ---------------------------------------------------------------------
        if (key_idx == 4'd10)      key_data = KEY_ESC; // CLEAR
        else if (key_idx == 4'd11) key_data = KEY_BS;  // BACK
        else if (key_idx == 4'd12) key_data = KEY_CR;  // ENTER
        
        else begin
            case (mode)
                // =============================================================
                // Case 1: Alphabet Mode
                // =============================================================
                MODE_ALPHABET: begin
                    // 9번 버튼은 SPACE (State 무관)
                    if (key_idx == 4'd9) key_data = KEY_SPACE;
                    else begin
                        case (state)
                            // State 0: 1~8 -> '1'~'8'
                            3'd0: begin
                                if (key_idx >= 1 && key_idx <= 8) 
                                    key_data = "0" + key_idx; // ASCII '1' ~ '8'
                            end
                            
                            // State 1: 9, 0, A~F
                            3'd1: begin
                                case (key_idx)
                                    4'd1: key_data = "9";
                                    4'd2: key_data = "0";
                                    4'd3: key_data = "A";
                                    4'd4: key_data = "B";
                                    4'd5: key_data = "C";
                                    4'd6: key_data = "D";
                                    4'd7: key_data = "E";
                                    4'd8: key_data = "F";
                                endcase
                            end

                            // State 2: G ~ N
                            3'd2: begin
                                if (key_idx >= 1 && key_idx <= 8)
                                    key_data = "G" + (key_idx - 1);
                            end

                            // State 3: O ~ V
                            3'd3: begin
                                if (key_idx >= 1 && key_idx <= 8)
                                    key_data = "O" + (key_idx - 1);
                            end

                            // State 4: W ~ Z
                            3'd4: begin
                                case (key_idx)
                                    4'd1: key_data = "W";
                                    4'd2: key_data = "X";
                                    4'd3: key_data = "Y";
                                    4'd4: key_data = "Z";
                                endcase
                            end
                        endcase
                    end
                end

                // =============================================================
                // Case 2: Morse Mode (State 0만 존재)
                // =============================================================
                MODE_MORSE: begin
                    case (key_idx)
                        4'd1: key_data = "-";       // Dash (나중에 Long/Short 판별은 상위에서 함)
                        4'd2: key_data = ".";       // Dot
                        4'd9: key_data = CMD_PAUSE; // PAUSE 명령
                        // 3~8은 Macro (상위 모듈에서 처리, 여기서는 0 반환하거나 Macro ID 반환)
                        // 필요 시 여기에 Macro 매핑 추가 가능
                    endcase
                end

                // =============================================================
                // Case 3: Setting Mode
                // =============================================================
                MODE_SETTING: begin
                    case (key_idx)
                        4'd1: key_data = CMD_UP;   // UP
                        4'd2: key_data = CMD_DOWN; // DOWN
                    endcase
                end
            endcase
        end
    end

endmodule