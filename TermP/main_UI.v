//==============================================================================
// Main UI Module (Menu Selection) - CORRECTED VERSION
//==============================================================================
module main_ui (
    input wire clk,
    input wire rst_n,
    input wire active,
    
    // Button inputs
    input wire [11:0] button_pressed,
    
    // LCD Interface
    output reg lcd_write_req,
    output reg [4:0] lcd_x_pos,
    output reg [1:0] lcd_y_pos,
    output reg [127:0] lcd_text,
    output reg [7:0] lcd_text_len,
    
    // RGB LED (Menu indicator)
    output reg rgb_r,
    output reg rgb_g,
    output reg rgb_b,
    
    // UI Navigation
    output reg [3:0] next_uuid,
    output reg ui_update,
    
    // Timing Configuration
    input wire [31:0] long_key_threshold
);

//==============================================================================
// Parameters
//==============================================================================
localparam IDLE         = 4'b0000;
localparam MENU_SELECT  = 4'b0001;
localparam LCD_LINE1    = 4'b0010;  // ? 추가
localparam LCD_LINE2    = 4'b0011;  // ? 추가
localparam MENU_ENTER   = 4'b0100;

// UUID Definitions
localparam UUID_MAIN     = 4'b0000;
localparam UUID_DECODE   = 4'b0001;
localparam UUID_ENCODE   = 4'b0010;
localparam UUID_SETTING  = 4'b0011;

// Key Types
localparam TYPE_SINGLE_KEY    = 3'b000;
localparam TYPE_LONG_KEY      = 3'b001;
localparam TYPE_MULTI_KEY     = 3'b010;
localparam TYPE_CTRL_SINGLE   = 3'b100;
localparam TYPE_CTRL_LONG     = 3'b101;
localparam TYPE_CTRL_MULTI    = 3'b110;

//==============================================================================
// Internal Registers
//==============================================================================
reg [3:0] state, next_state;  // ? 4비트로 확장
reg [1:0] menu_index;  // 0: Decode, 1: Encode, 2: Setting
reg [127:0] display_line1;
reg [127:0] display_line2;

// KeyMapping interface
wire [10:0] key_output;
wire key_valid;
wire key_freeze;

//==============================================================================
// KeyMapping Instance (Setting Mode for UP/DOWN)
//==============================================================================
key_mapping key_map_inst (
    .clk(clk),
    .rst_n(rst_n),
    .button_pressed(button_pressed),
    .current_mode(2'b10),  // Setting mode (UP/DOWN buttons)
    .current_state(3'b000),
    .long_key_threshold(long_key_threshold),
    .key_output(key_output),
    .key_valid(key_valid),
    .freeze(key_freeze)
);

//==============================================================================
// Menu Text Generator
//==============================================================================
function [127:0] get_menu_text;
    input [1:0] index;
    begin
        case (index)
            2'd0: get_menu_text = {"> DECODE       ", 112'b0};
            2'd1: get_menu_text = {"> ENCODE       ", 112'b0};
            2'd2: get_menu_text = {"> SETTING      ", 112'b0};
            default: get_menu_text = {"> DECODE       ", 112'b0};
        endcase
    end
endfunction

function [127:0] get_menu_desc;
    input [1:0] index;
    begin
        case (index)
            2'd0: get_menu_desc = {"Morse -> Text  ", 112'b0};
            2'd1: get_menu_desc = {"Text -> Morse  ", 112'b0};
            2'd2: get_menu_desc = {"Configure      ", 112'b0};
            default: get_menu_desc = {"               ", 112'b0};
        endcase
    end
endfunction

//==============================================================================
// RGB LED Color by Menu
//==============================================================================
always @(*) begin
    case (menu_index)
        2'd0: begin  // Decode - Blue
            rgb_r = 1'b0;
            rgb_g = 1'b0;
            rgb_b = 1'b1;
        end
        2'd1: begin  // Encode - Green
            rgb_r = 1'b0;
            rgb_g = 1'b1;
            rgb_b = 1'b0;
        end
        2'd2: begin  // Setting - Yellow
            rgb_r = 1'b1;
            rgb_g = 1'b1;
            rgb_b = 1'b0;
        end
        default: begin
            rgb_r = 1'b0;
            rgb_g = 1'b0;
            rgb_b = 1'b0;
        end
    endcase
end

//==============================================================================
// State Machine
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else if (active) begin
        state <= next_state;
    end else begin
        state <= IDLE;
    end
end

//==============================================================================
// Next State Logic
//==============================================================================
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: next_state = MENU_SELECT;
        
        MENU_SELECT: begin
            if (key_valid) begin
                if (key_output[10:8] == TYPE_CTRL_SINGLE && key_output[5]) begin
                    // ENTER pressed
                    next_state = MENU_ENTER;
                end else begin
                    // ? 키 입력 후 LCD 업데이트
                    next_state = LCD_LINE1;
                end
            end else begin
                // ? 주기적으로 LCD 업데이트
                next_state = LCD_LINE1;
            end
        end
        
        // ? 새로운 State
        LCD_LINE1: next_state = LCD_LINE2;
        LCD_LINE2: next_state = MENU_SELECT;
        
        MENU_ENTER: next_state = IDLE;
        
        default: next_state = IDLE;
    endcase
end

//==============================================================================
// Output Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lcd_write_req <= 1'b0;
        lcd_x_pos <= 5'b0;
        lcd_y_pos <= 2'b0;
        lcd_text <= 128'b0;
        lcd_text_len <= 8'b0;
        
        next_uuid <= UUID_MAIN;
        ui_update <= 1'b0;
        
        menu_index <= 2'b0;
        
        display_line1 <= {"> DECODE       ", 112'b0};
        display_line2 <= {"Morse -> Text  ", 112'b0};
        
    end else if (active) begin
        // Default values
        lcd_write_req <= 1'b0;
        ui_update <= 1'b0;
        
        case (state)
            IDLE: begin
                menu_index <= 2'b0;
                display_line1 <= {"> DECODE       ", 112'b0};
                display_line2 <= {"Morse -> Text  ", 112'b0};
            end
            
            MENU_SELECT: begin
                if (key_valid && !key_freeze) begin
                    case (key_output[10:8])
                        TYPE_SINGLE_KEY: begin
                            // UP button (Button 1)
                            if (key_output[2]) begin
                                if (menu_index > 0) begin
                                    menu_index <= menu_index - 1;
                                end else begin
                                    menu_index <= 2'd2;  // Wrap to last menu
                                end
                            end
                            // DOWN button (Button 2)
                            else if (key_output[3]) begin
                                if (menu_index < 2) begin
                                    menu_index <= menu_index + 1;
                                end else begin
                                    menu_index <= 2'd0;  // Wrap to first menu
                                end
                            end
                        end
                    endcase
                end
                
                // ? display 레지스터 업데이트 (LCD 쓰기는 다음 state에서)
                display_line1 <= get_menu_text(menu_index);
                display_line2 <= get_menu_desc(menu_index);
            end
            
            // ? 새로운 State: LCD Line 1 표시
            LCD_LINE1: begin
                lcd_text <= display_line1;
                lcd_text_len <= 8'd16;
                lcd_x_pos <= 5'd0;
                lcd_y_pos <= 2'd0;
                lcd_write_req <= 1'b1;  // ? Line 1만 쓰기
            end
            
            // ? 새로운 State: LCD Line 2 표시
            LCD_LINE2: begin
                lcd_text <= display_line2;
                lcd_text_len <= 8'd16;
                lcd_x_pos <= 5'd0;
                lcd_y_pos <= 2'd1;
                lcd_write_req <= 1'b1;  // ? Line 2만 쓰기 (다음 클럭)
            end
            
            MENU_ENTER: begin
                // Navigate to selected UI
                case (menu_index)
                    2'd0: next_uuid <= UUID_DECODE;
                    2'd1: next_uuid <= UUID_ENCODE;
                    2'd2: next_uuid <= UUID_SETTING;
                    default: next_uuid <= UUID_MAIN;
                endcase
                ui_update <= 1'b1;
            end
        endcase
    end
end

endmodule