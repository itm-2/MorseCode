module piezo_driver (
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [31:0] freq_div, // 50MHz / Frequency / 2
    output wire piezo_out
);
    reg [31:0] cnt;
    reg out_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin cnt <= 0; out_reg <= 0; end
        else if(en && freq_div > 0) begin
            if(cnt >= freq_div) begin
                cnt <= 0;
                out_reg <= ~out_reg;
            end else cnt <= cnt + 1;
        end else begin
            cnt <= 0; out_reg <= 0;
        end
    end
    assign piezo_out = out_reg;
endmodule