module morse_system_top (
    input wire clk,
    input wire rst_n,
    input wire [12:1] btn_key, // 12-key Input
    
    output wire [3:0] led_debug,
    output wire piezo_out,
    output wire servo_pwm,
    output wire lcd_rs, lcd_rw, lcd_e,
    output wire [7:0] lcd_data
);
    // Internal Signals
    wire key_valid;
    wire [10:0] key_cmd;
    wire [1:0] current_mode;
    wire [2:0] servo_state;
    
    wire piezo_en;
    wire [31:0] piezo_freq;
    wire [127:0] lcd_l1, lcd_l2;

    // 1. Key Mapping & Detection
    morse_key_mapping u_keymap (
        .clk(clk), .rst_n(rst_n),
        .btn_in(btn_key),
        .mode(current_mode),
        .timer_threshold(32'd10_000_000), // 200ms
        .cmd_valid(key_valid),
        .cmd_out(key_cmd),
        .current_state(servo_state)
    );
    
    // 2. UI Controller
    morse_ui_controller u_ui (
        .clk(clk), .rst_n(rst_n),
        .key_valid(key_valid), .key_cmd(key_cmd),
        .current_mode(current_mode),
        .lcd_line1(lcd_l1), .lcd_line2(lcd_l2),
        .piezo_en(piezo_en), .piezo_freq(piezo_freq),
        .led_red_en()
    );

    // 3. Drivers
    lcd_driver u_lcd (
        .clk(clk), .rst_n(rst_n),
        .line1(lcd_l1), .line2(lcd_l2),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_e(lcd_e), .lcd_data(lcd_data)
    );
    
    piezo_driver u_piezo (
        .clk(clk), .rst_n(rst_n),
        .en(piezo_en),
        .freq_div(piezo_freq),
        .piezo_out(piezo_out)
    );
    
    servo_driver u_servo (
        .clk(clk), .rst_n(rst_n),
        .angle_idx(servo_state),
        .pwm_out(servo_pwm)
    );

    assign led_debug = {key_valid, current_mode[1:0], 1'b0};

endmodule