//==============================================================================
// Servo Controller Module (PWM Generator)
//==============================================================================
module servo_controller (
    input wire clk,              // 50MHz
    input wire rst_n,
    
    // Control Interface
    input wire [7:0] angle,      // 각도 (0-180도)
    
    // PWM Output
    output reg pwm_out
);

//==============================================================================
// Parameters
//==============================================================================
localparam CLK_FREQ = 50_000_000;  // 50MHz
localparam PWM_PERIOD = 1_000_000; // 20ms (50Hz) @ 50MHz

// Servo PWM 범위 (50MHz 기준)
localparam PULSE_MIN = 50_000;     // 1ms (0도)
localparam PULSE_MAX = 100_000;    // 2ms (180도)

//==============================================================================
// Internal Registers
//==============================================================================
reg [31:0] period_counter;
reg [31:0] pulse_width;

//==============================================================================
// Pulse Width Calculation
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pulse_width <= PULSE_MIN;
    end else begin
        // 각도를 펄스 폭으로 변환
        // pulse_width = PULSE_MIN + (angle * (PULSE_MAX - PULSE_MIN) / 180)
        pulse_width <= PULSE_MIN + ((angle * (PULSE_MAX - PULSE_MIN)) / 180);
    end
end

//==============================================================================
// PWM Generation Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        period_counter <= 32'b0;
        pwm_out <= 1'b0;
        
    end else begin
        if (period_counter >= PWM_PERIOD) begin
            // 주기 리셋
            period_counter <= 32'b0;
            pwm_out <= 1'b1;
            
        end else begin
            period_counter <= period_counter + 1;
            
            // 펄스 폭 비교
            if (period_counter >= pulse_width) begin
                pwm_out <= 1'b0;
            end
        end
    end
end

endmodule