`timescale 1ns / 1ps

module SelectUI #(
    parameter MENU_COUNT = 3,
    parameter STR_LEN    = 7,
    parameter [(8*STR_LEN*MENU_COUNT)-1:0] MENU_STR_FLAT = 0,
    parameter [(4*MENU_COUNT)-1:0] NEXT_UUID_FLAT = 0,
    parameter [3:0] BACK_UUID = 4'h0
)(
    input wire clk, 
    input wire rst_n,
    input wire is_active,  
    
    // [수정] 11비트 패킷 입력 (8비트 아님!)
    input wire [10:0] key_packet,
    input wire key_valid,

    input wire lcd_busy,      
    input wire lcd_done,      
    output reg lcd_req,       
    output reg [1:0] lcd_row, 
    output reg [3:0] lcd_col, 
    output reg [7:0] lcd_char,

    output reg change_req,
    output reg [3:0] next_ui_id 
);

    // 파라미터 Unpacking
    reg [7:0] menu_str [0:MENU_COUNT-1][0:STR_LEN-1];
    reg [3:0] uuid_table [0:MENU_COUNT-1];
    
    integer i, j;
    initial begin
        for (i = 0; i < MENU_COUNT; i = i + 1) begin
            for (j = 0; j < STR_LEN; j = j + 1) begin
                menu_str[i][j] = MENU_STR_FLAT[((MENU_COUNT-1-i)*STR_LEN*8) + ((STR_LEN-1-j)*8) +: 8];
            end
            uuid_table[i] = NEXT_UUID_FLAT[((MENU_COUNT-1-i)*4) +: 4];
        end
    end

    // Key Packet Decoding
    wire [2:0] key_type = key_packet[10:8];
    wire [7:0] key_data = key_packet[7:0];

    // [명세 기준 키 정의]
    localparam TYPE_SINGLE = 3'b000;
    localparam TYPE_CTRL_S = 3'b100;
    
    // Setting Mode UP/DOWN (One-Hot)
    localparam DATA_UP   = 8'b0000_0100; // Btn 1
    localparam DATA_DOWN = 8'b0000_1000; // Btn 2
    
    // Control Keys (One-Hot)
    localparam DATA_ENTER = 8'b0010_0000; // Btn 12
    localparam DATA_BACK  = 8'b0001_0000; // Btn 11

    // 내부 변수
    reg [1:0] cursor;
    reg [1:0] top_item;
    reg ui_version, rendered_version;  
    localparam S_IDLE=0, S_RENDER_LINE=1, S_SEND_CHAR=2, S_WAIT_DONE=3, S_NEXT_CHAR=4;
    reg [3:0] state;
    reg rendering_row;
    reg [3:0] char_idx;

    // Block 1: 네비게이션
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cursor <= 0; top_item <= 0;
            change_req <= 0; next_ui_id <= 0; ui_version <= 0;
        end else if (is_active) begin
            change_req <= 0;
            
            if (key_valid) begin
                ui_version <= ~ui_version;

                // [수정] 패킷 해석 로직
                // UP (Single Type + Data 00000100)
                if (key_type == TYPE_SINGLE && key_data == DATA_UP) begin
                    if (cursor > 0) begin
                        cursor <= cursor - 1;
                        if (cursor <= top_item) top_item <= cursor - 1;
                    end
                end
                // DOWN (Single Type + Data 00001000)
                else if (key_type == TYPE_SINGLE && key_data == DATA_DOWN) begin
                    if (cursor < MENU_COUNT - 1) begin
                        cursor <= cursor + 1;
                        if (cursor >= top_item + 1) top_item <= cursor;
                    end
                end
                // ENTER (Ctrl Type + Data 00100000)
                else if (key_type == TYPE_CTRL_S && key_data == DATA_ENTER) begin
                    change_req <= 1;
                    next_ui_id <= uuid_table[cursor];
                end
                // BACK (Ctrl Type + Data 00010000)
                else if (key_type == TYPE_CTRL_S && key_data == DATA_BACK) begin
                    change_req <= 1;
                    next_ui_id <= BACK_UUID;
                end
            end
        end
    end

    // Block 2: LCD 렌더링 (이전과 동일하지만 문법 준수)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; lcd_req <= 0; rendered_version <= 1;
            lcd_row <= 0; lcd_col <= 0; lcd_char <= 0; rendering_row <= 0; char_idx <= 0;
        end else if (is_active) begin
            case (state)
                S_IDLE: begin
                    lcd_req <= 0;
                    if ((ui_version != rendered_version) && !lcd_busy) begin
                        rendered_version <= ui_version;
                        rendering_row <= 0; char_idx <= 0; state <= S_RENDER_LINE;
                    end
                end
                S_RENDER_LINE: state <= S_SEND_CHAR;
                S_SEND_CHAR: begin
                    if (!lcd_busy) begin
                        lcd_req <= 1;
                        lcd_row <= rendering_row; lcd_col <= char_idx;       
                        if (char_idx == 0 || char_idx == 1) begin
                            if ((top_item + rendering_row) == cursor) lcd_char <= ">";
                            else lcd_char <= " ";
                        end
                        else if (char_idx == 2) lcd_char <= " ";
                        else begin
                            if ((top_item + rendering_row) < MENU_COUNT) begin
                                if ((char_idx - 3) < STR_LEN)
                                    lcd_char <= menu_str[top_item + rendering_row][char_idx - 3];
                                else lcd_char <= " ";
                            end else lcd_char <= " ";
                        end
                        state <= S_WAIT_DONE;
                    end
                end
                S_WAIT_DONE: begin
                    lcd_req <= 0;
                    if (lcd_done) state <= S_NEXT_CHAR;
                end
                S_NEXT_CHAR: begin
                    if (char_idx >= 15) begin
                        if (rendering_row == 0) begin
                            rendering_row <= 1; char_idx <= 0; state <= S_RENDER_LINE;
                        end else state <= S_IDLE;
                    end else begin
                        char_idx <= char_idx + 1; state <= S_SEND_CHAR;
                    end
                end
            endcase
        end else begin
            state <= S_IDLE; lcd_req <= 0;
        end
    end
endmodule