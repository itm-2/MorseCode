module servo_driver (
    input wire clk,
    input wire rst_n,
    input wire [2:0] angle_idx, // 0~4
    output wire pwm_out
);
    reg [19:0] cnt;
    reg [19:0] high_time;
    // 0:0deg, 1:45deg, 2:90deg, 3:135deg, 4:180deg
    // 50MHz, 20ms period (1,000,000 ticks)
    // 0.5ms ~ 2.5ms (25,000 ~ 125,000)
    
    always @(*) begin
        case(angle_idx)
            3'd0: high_time = 25_000;
            3'd1: high_time = 50_000;
            3'd2: high_time = 75_000;
            3'd3: high_time = 100_000;
            3'd4: high_time = 125_000;
            default: high_time = 25_000;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) cnt <= 0;
        else begin
            if(cnt < 1_000_000) cnt <= cnt + 1;
            else cnt <= 0;
        end
    end
    assign pwm_out = (cnt < high_time);
endmodule