module morse_ui_controller (
    input wire clk,
    input wire rst_n,
    
    // Key Interface
    input wire key_valid,
    input wire [10:0] key_cmd,
    output reg [1:0] current_mode, // To KeyMapping
    
    // Output Interface
    output reg [127:0] lcd_line1,
    output reg [127:0] lcd_line2,
    output reg piezo_en,
    output reg [31:0] piezo_freq,
    output reg led_red_en
);
    // UI States
    localparam UI_SELECT = 0;
    localparam UI_ENCODE = 1;
    localparam UI_DECODE = 2;
    
    reg [1:0] ui_state;
    reg [1:0] menu_cursor; // 0:Setting, 1:Encode, 2:Decode
    
    // Buffer for Processing
    reg [7:0] buffer [0:127];
    reg [6:0] buf_head;

    // Command Decoding
    wire [2:0] cmd_type = key_cmd[10:8];
    wire [7:0] cmd_data = key_cmd[7:0];
    
    localparam TYPE_CTRL_SINGLE = 3'b100;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ui_state <= UI_SELECT;
            current_mode <= 2; // Setting
            menu_cursor <= 1;
            lcd_line1 <= ">> SETTING      ";
            lcd_line2 <= "   ENCODE       ";
            piezo_en <= 0;
        end else begin
            piezo_en <= 0; // Default off
            
            case(ui_state)
                // --- SELECT UI (Setting Mode) ---
                UI_SELECT: begin
                    current_mode <= 2; // Setting Mode
                    // Display Logic
                    case(menu_cursor)
                        0: begin lcd_line1 <= ">> SETTING      "; lcd_line2 <= "   ENCODE       "; end
                        1: begin lcd_line1 <= ">> ENCODE       "; lcd_line2 <= "   DECODE       "; end
                        2: begin lcd_line1 <= ">> DECODE       "; lcd_line2 <= "   SETTING      "; end
                    endcase
                    
                    if(key_valid) begin
                        // UP (0000 0100)
                        if(cmd_data == 8'b00000100) begin 
                            if(menu_cursor > 0) menu_cursor <= menu_cursor - 1;
                            else menu_cursor <= 2;
                        end
                        // DOWN (0000 1000)
                        else if(cmd_data == 8'b00001000) begin
                            if(menu_cursor < 2) menu_cursor <= menu_cursor + 1;
                            else menu_cursor <= 0;
                        end
                        // ENTER (0100 0000)
                        else if(cmd_data == 8'b01000000) begin
                            if(menu_cursor == 1) begin 
                                ui_state <= UI_ENCODE; 
                                buf_head <= 0;
                                lcd_line1 <= "ENTER THE CODE..";
                                lcd_line2 <= "                ";
                            end
                            else if(menu_cursor == 2) begin
                                ui_state <= UI_DECODE;
                                buf_head <= 0;
                                lcd_line1 <= "ENTER THE CODE..";
                                lcd_line2 <= "                ";
                            end
                        end
                    end
                end
                
                // --- ENCODE UI (Text -> Morse) ---
                UI_ENCODE: begin
                    current_mode <= 1; // Morse Mode (Actually Encode uses Alpha input? Prompt says EncodeUI inputs Alphabet)
                    // Wait, EncodeUI inputs Alphabet -> Morse. So Mode should be Alpha.
                    // But Prompt says "showUI(): KeyMapping은 Morse로 합니다" in EncodeUI.txt?
                    // Let's re-read: "EncodeUI는 알파벳을 입력... KeyMapping은 Morse로 합니다" -> This implies using Morse keys to select Alpha?
                    // Or maybe typo in prompt. Usually Encode is Alpha->Morse.
                    // Let's assume KeyMapping is Morse based on text file.
                    
                    if(key_valid) begin
                        if(cmd_type == TYPE_CTRL_SINGLE && cmd_data == 8'b00100000) // BACK
                            ui_state <= UI_SELECT;
                        // Implementation of Text Entry & Translation would go here
                    end
                end
                
                // --- DECODE UI (Morse -> Text) ---
                UI_DECODE: begin
                    current_mode <= 1; // Morse
                    if(key_valid) begin
                        if(cmd_type == TYPE_CTRL_SINGLE && cmd_data == 8'b00100000) // BACK
                            ui_state <= UI_SELECT;
                        // Implementation of Morse Entry (Dit/Dah) & Translation
                    end
                end
            endcase
        end
    end
endmodule