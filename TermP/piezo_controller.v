//==============================================================================
// Piezo Controller Module (PWM Generator)
//==============================================================================
module piezo_controller (
    input wire clk,              // 50MHz
    input wire rst_n,
    
    // Control Interface
    input wire enable,           // Piezo 활성화
    input wire [15:0] duration,  // 지속 시간 (ms 단위)
    input wire [15:0] frequency, // 주파수 (Hz 단위)
    
    // PWM Output
    output reg pwm_out
);

//==============================================================================
// Parameters
//==============================================================================
localparam CLK_FREQ = 50_000_000;  // 50MHz

//==============================================================================
// Internal Registers
//==============================================================================
reg [31:0] duration_counter;   // 지속 시간 카운터 (클럭 사이클)
reg [31:0] period_counter;     // PWM 주기 카운터
reg [31:0] half_period;        // 반주기 (클럭 사이클)
reg [31:0] total_duration;     // 총 지속 시간 (클럭 사이클)
reg active;                    // 현재 활성 상태

//==============================================================================
// Duration & Period Calculation
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        half_period <= 32'd25000;      // 기본값: 1kHz (50MHz / 2000)
        total_duration <= 32'd50000;   // 기본값: 1ms
    end else if (enable && !active) begin
        // 반주기 계산: CLK_FREQ / (2 * frequency)
        half_period <= CLK_FREQ / (frequency << 1);
        
        // 총 지속 시간 계산: duration(ms) * CLK_FREQ / 1000
        total_duration <= (duration * (CLK_FREQ / 1000));
    end
end

//==============================================================================
// PWM Generation Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwm_out <= 1'b0;
        duration_counter <= 32'b0;
        period_counter <= 32'b0;
        active <= 1'b0;
        
    end else begin
        if (enable && !active) begin
            // 새로운 톤 시작
            active <= 1'b1;
            duration_counter <= 32'b0;
            period_counter <= 32'b0;
            pwm_out <= 1'b1;
            
        end else if (active) begin
            // 지속 시간 체크
            if (duration_counter >= total_duration) begin
                // 지속 시간 종료
                active <= 1'b0;
                pwm_out <= 1'b0;
                duration_counter <= 32'b0;
                period_counter <= 32'b0;
                
            end else begin
                // PWM 토글
                if (period_counter >= half_period) begin
                    pwm_out <= ~pwm_out;
                    period_counter <= 32'b0;
                end else begin
                    period_counter <= period_counter + 1;
                end
                
                duration_counter <= duration_counter + 1;
            end
        end else begin
            pwm_out <= 1'b0;
        end
    end
end

endmodule