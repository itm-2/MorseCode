module lcd_driver (
    input wire clk,
    input wire rst_n,
    input wire [127:0] line1,
    input wire [127:0] line2,
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_e,
    output reg [7:0] lcd_data
);
    // 50MHz Clock 기준 타이밍
    localparam CNT_CMD = 2_500;   
    localparam CNT_INIT = 2_000_000;

    reg [3:0] state;
    reg [31:0] cnt;
    reg [3:0] char_idx; 
    reg line_sel;       

    localparam S_INIT = 0, S_FUNC = 1, S_ON = 2, S_CLR = 3, S_MODE = 4, S_ADDR = 5, S_WRITE = 6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_INIT;
            cnt <= 0; char_idx <= 0; line_sel <= 0;
            lcd_e <= 0; lcd_rs <= 0; lcd_rw <= 0;
        end else begin
            case (state)
                S_INIT: if (cnt > CNT_INIT) begin cnt<=0; state<=S_FUNC; end else cnt<=cnt+1;
                S_FUNC: begin 
                    lcd_rs<=0; lcd_rw<=0; lcd_data<=8'h38;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin cnt<=0; state<=S_ON; end else cnt<=cnt+1;
                end
                S_ON: begin 
                    lcd_rs<=0; lcd_rw<=0; lcd_data<=8'h0C;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin cnt<=0; state<=S_CLR; end else cnt<=cnt+1;
                end
                S_CLR: begin 
                    lcd_rs<=0; lcd_rw<=0; lcd_data<=8'h01;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>100000+22) begin cnt<=0; state<=S_MODE; end else cnt<=cnt+1;
                end
                S_MODE: begin 
                    lcd_rs<=0; lcd_rw<=0; lcd_data<=8'h06;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin cnt<=0; state<=S_ADDR; end else cnt<=cnt+1;
                end
                S_ADDR: begin
                    lcd_rs<=0; lcd_rw<=0;
                    if(!line_sel) lcd_data <= 8'h80 + char_idx; else lcd_data <= 8'hC0 + char_idx;
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin cnt<=0; state<=S_WRITE; end else cnt<=cnt+1;
                end
                S_WRITE: begin
                    lcd_rs<=1; lcd_rw<=0;
                    if(!line_sel) lcd_data <= line1[127 - char_idx*8 -: 8];
                    else          lcd_data <= line2[127 - char_idx*8 -: 8];
                    if(cnt==2) lcd_e<=1; else if(cnt==22) lcd_e<=0;
                    if(cnt>CNT_CMD+22) begin 
                        cnt<=0; 
                        if(char_idx==15) begin char_idx<=0; line_sel<=~line_sel; end 
                        else char_idx<=char_idx+1;
                        state<=S_ADDR; 
                    end else cnt<=cnt+1;
                end
            endcase
        end
    end
endmodule