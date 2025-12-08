//==============================================================================
// LCD Controller Module (HD44780 Compatible)
//==============================================================================
module lcd_controller (
    input wire clk,              // 50MHz
    input wire rst_n,
    
    // UI Interface
    input wire write_req,
    input wire [4:0] x_pos,      // 0-15 (16 characters)
    input wire [1:0] y_pos,      // 0-1 (2 lines)
    input wire [127:0] text,     // 16 characters (8-bit each)
    input wire [7:0] text_len,
    
    // LCD Hardware Interface
    output reg lcd_e,
    output reg lcd_rs,
    output reg lcd_rw,
    output reg [7:0] lcd_data
);

//==============================================================================
// Parameters
//==============================================================================
localparam CLK_FREQ = 50_000_000;  // 50MHz
localparam DELAY_15MS = 750_000;   // 15ms @ 50MHz
localparam DELAY_4MS  = 200_000;   // 4.1ms
localparam DELAY_100US = 5_000;    // 100us
localparam DELAY_40US = 2_000;     // 40us

// States
localparam IDLE           = 4'd0;
localparam INIT_WAIT      = 4'd1;
localparam INIT_FUNC_SET1 = 4'd2;
localparam INIT_FUNC_SET2 = 4'd3;
localparam INIT_FUNC_SET3 = 4'd4;
localparam INIT_DISPLAY   = 4'd5;
localparam INIT_CLEAR     = 4'd6;
localparam INIT_ENTRY     = 4'd7;
localparam READY          = 4'd8;
localparam SET_DDRAM      = 4'd9;
localparam WRITE_CHAR     = 4'd10;
localparam WAIT_BUSY      = 4'd11;

//==============================================================================
// Internal Registers
//==============================================================================
reg [3:0] state, next_state;
reg [31:0] delay_counter;
reg [7:0] char_index;
reg [7:0] ddram_addr;
reg [7:0] current_char;

//==============================================================================
// DDRAM Address Calculation
//==============================================================================
function [7:0] get_ddram_addr;
    input [4:0] x;
    input [1:0] y;
    begin
        case (y)
            2'd0: get_ddram_addr = 8'h00 + x;  // Line 1: 0x00-0x0F
            2'd1: get_ddram_addr = 8'h40 + x;  // Line 2: 0x40-0x4F
            default: get_ddram_addr = 8'h00;
        endcase
    end
endfunction

//==============================================================================
// State Machine
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//==============================================================================
// Next State Logic
//==============================================================================
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: next_state = INIT_WAIT;
        
        INIT_WAIT: begin
            if (delay_counter >= DELAY_15MS)
                next_state = INIT_FUNC_SET1;
        end
        
        INIT_FUNC_SET1: begin
            if (delay_counter >= DELAY_4MS)
                next_state = INIT_FUNC_SET2;
        end
        
        INIT_FUNC_SET2: begin
            if (delay_counter >= DELAY_100US)
                next_state = INIT_FUNC_SET3;
        end
        
        INIT_FUNC_SET3: begin
            if (delay_counter >= DELAY_40US)
                next_state = INIT_DISPLAY;
        end
        
        INIT_DISPLAY: begin
            if (delay_counter >= DELAY_40US)
                next_state = INIT_CLEAR;
        end
        
        INIT_CLEAR: begin
            if (delay_counter >= DELAY_4MS)
                next_state = INIT_ENTRY;
        end
        
        INIT_ENTRY: begin
            if (delay_counter >= DELAY_40US)
                next_state = READY;
        end
        
        READY: begin
            if (write_req)
                next_state = SET_DDRAM;
        end
        
        SET_DDRAM: begin
            if (delay_counter >= DELAY_40US)
                next_state = WRITE_CHAR;
        end
        
        WRITE_CHAR: begin
            if (delay_counter >= DELAY_40US) begin
                if (char_index >= text_len)
                    next_state = READY;
                else
                    next_state = WRITE_CHAR;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

//==============================================================================
// Output Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lcd_e <= 1'b0;
        lcd_rs <= 1'b0;
        lcd_rw <= 1'b0;
        lcd_data <= 8'b0;
        delay_counter <= 32'b0;
        char_index <= 8'b0;
        ddram_addr <= 8'b0;
        
    end else begin
        case (state)
            IDLE: begin
                lcd_e <= 1'b0;
                lcd_rs <= 1'b0;
                lcd_rw <= 1'b0;
                lcd_data <= 8'b0;
                delay_counter <= 32'b0;
            end
            
            INIT_WAIT: begin
                delay_counter <= delay_counter + 1;
            end
            
            INIT_FUNC_SET1: begin
                lcd_rs <= 1'b0;
                lcd_rw <= 1'b0;
                lcd_data <= 8'h38;  // Function Set: 8-bit, 2-line, 5x8
                lcd_e <= (delay_counter < 100) ? 1'b1 : 1'b0;
                delay_counter <= delay_counter + 1;
            end
            
            INIT_FUNC_SET2: begin
                lcd_rs <= 1'b0;
                lcd_rw <= 1'b0;
                lcd_data <= 8'h38;
                lcd_e <= (delay_counter < 100) ? 1'b1 : 1'b0;
                delay_counter <= delay_counter + 1;
            end
            
            INIT_FUNC_SET3: begin
                lcd_rs <= 1'b0;
                lcd_rw <= 1'b0;
                lcd_data <= 8'h38;
                lcd_e <= (delay_counter < 100) ? 1'b1 : 1'b0;
                delay_counter <= delay_counter + 1;
            end
            
            INIT_DISPLAY: begin
                lcd_rs <= 1'b0;
                lcd_rw <= 1'b0;
                lcd_data <= 8'h0C;  // Display ON, Cursor OFF
                lcd_e <= (delay_counter < 100) ? 1'b1 : 1'b0;
                delay_counter <= delay_counter + 1;
            end
            
            INIT_CLEAR: begin
                lcd_rs <= 1'b0;
                lcd_rw <= 1'b0;
                lcd_data <= 8'h01;  // Clear Display
                lcd_e <= (delay_counter < 100) ? 1'b1 : 1'b0;
                delay_counter <= delay_counter + 1;
            end
            
            INIT_ENTRY: begin
                lcd_rs <= 1'b0;
                lcd_rw <= 1'b0;
                lcd_data <= 8'h06;  // Entry Mode: Increment, No Shift
                lcd_e <= (delay_counter < 100) ? 1'b1 : 1'b0;
                delay_counter <= delay_counter + 1;
            end
            
            READY: begin
                lcd_e <= 1'b0;
                delay_counter <= 32'b0;
                char_index <= 8'b0;
                
                if (write_req) begin
                    ddram_addr <= get_ddram_addr(x_pos, y_pos);
                end
            end
            
            SET_DDRAM: begin
                lcd_rs <= 1'b0;
                lcd_rw <= 1'b0;
                lcd_data <= {1'b1, ddram_addr[6:0]};  // Set DDRAM Address
                lcd_e <= (delay_counter < 100) ? 1'b1 : 1'b0;
                delay_counter <= delay_counter + 1;
            end
            
            WRITE_CHAR: begin
                if (delay_counter == 0) begin
                    current_char <= text[127 - char_index*8 -: 8];
                end
                
                lcd_rs <= 1'b1;  // Data mode
                lcd_rw <= 1'b0;
                lcd_data <= current_char;
                lcd_e <= (delay_counter < 100) ? 1'b1 : 1'b0;
                
                if (delay_counter >= DELAY_40US) begin
                    char_index <= char_index + 1;
                    delay_counter <= 32'b0;
                end else begin
                    delay_counter <= delay_counter + 1;
                end
            end
        endcase
    end
end

endmodule