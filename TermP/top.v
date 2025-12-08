module morse_code_converter_top (
    input wire clk,              // 50MHz Clock
    input wire rst_n,
    input wire [11:0] button_pressed,
    
    // LCD Interface
    output wire lcd_e,
    output wire lcd_rs,
    output wire lcd_rw,
    output wire [7:0] lcd_data,
    
    // LED Interface
    output wire [7:0] led_enable,
    
    // RGB LED
    output wire rgb_r,
    output wire rgb_g,
    output wire rgb_b,
    
    // Piezo Interface
    output wire piezo_out,
    
    // Servo Motor
    output wire servo_pwm
);

//==============================================================================
// Internal Signals
//==============================================================================
wire piezo_enable;
wire [15:0] piezo_duration;
wire [15:0] piezo_frequency;
wire [7:0] servo_angle;

// LCD Interface Signals
wire lcd_write_req;
wire [4:0] lcd_x_pos;
wire [1:0] lcd_y_pos;
wire [127:0] lcd_text;
wire [7:0] lcd_text_len;

//==============================================================================
// Parameters & Settings (CORRECTED WIDTHS)
//==============================================================================
localparam UUID_MAIN     = 4'b0000;
localparam UUID_DECODE   = 4'b0001;
localparam UUID_ENCODE   = 4'b0010;
localparam UUID_SETTING  = 4'b0011;

// CHANGED: Widen to 32-bit to hold large counter values for 50MHz
reg [31:0] dit_time;
reg [31:0] dah_time;
reg [31:0] space_time;
reg [31:0] long_key_threshold;

// UI Control
reg [3:0] current_uuid;
wire main_active, decode_active, encode_active, setting_active;

assign main_active    = (current_uuid == UUID_MAIN);
assign decode_active  = (current_uuid == UUID_DECODE);
assign encode_active  = (current_uuid == UUID_ENCODE);
assign setting_active = (current_uuid == UUID_SETTING);

//==============================================================================
// UI State Machine & Timing Initialization
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_uuid <= UUID_MAIN;
        
        // CHANGED: Updated timing constants for 50MHz Clock
        // Calculation: Time(s) * 50,000,000 Hz
        
        dit_time <= 32'd5_000_000;            // 100ms (Standard Morse unit)
        dah_time <= 32'd15_000_000;           // 300ms (3 units)
        space_time <= 32'd35_000_000;         // 700ms (7 units for word gap)
        long_key_threshold <= 32'd25_000_000; // 500ms (Threshold for long press)
        
    end else begin
        if (main_active && main_ui_update) begin
            current_uuid <= main_next_uuid;
        end else if (decode_active && decode_ui_update) begin
            current_uuid <= decode_next_uuid;
        end else if (encode_active && encode_ui_update) begin
            current_uuid <= encode_next_uuid;
        end
    end
end

//==============================================================================
// Shared Interfaces (Buffer, Translator, Mux)
//==============================================================================
// Shared Buffer Interface
wire ibuffer_push, ibuffer_pop, ibuffer_full, ibuffer_empty;
wire [7:0] ibuffer_data_in, ibuffer_data_out;

// Translator Interface
wire translate_req, translate_done, translate_error;
wire [39:0] morse_out;
wire [5:0] morse_out_len;
wire [7:0] char_out;

// UI Outputs
wire main_lcd_write_req, decode_lcd_write_req, encode_lcd_write_req;
wire [4:0] main_lcd_x_pos, decode_lcd_x_pos, encode_lcd_x_pos;
wire [1:0] main_lcd_y_pos, decode_lcd_y_pos, encode_lcd_y_pos;
wire [127:0] main_lcd_text, decode_lcd_text, encode_lcd_text;
wire [7:0] main_lcd_text_len, decode_lcd_text_len, encode_lcd_text_len;
wire main_rgb_r, main_rgb_g, main_rgb_b;
wire decode_rgb_r, decode_rgb_g, decode_rgb_b;
wire encode_rgb_r, encode_rgb_g, encode_rgb_b;
wire [3:0] main_next_uuid, decode_next_uuid, encode_next_uuid;
wire main_ui_update, decode_ui_update, encode_ui_update;
wire [7:0] decode_led_enable;
wire decode_ibuffer_push, encode_ibuffer_push;
wire [7:0] decode_ibuffer_data_in, encode_ibuffer_data_in;
wire decode_translate_req, encode_translate_req;
wire encode_piezo_enable;
wire [15:0] encode_piezo_duration, encode_piezo_frequency;
wire [7:0] encode_servo_angle;

// Buffer Pop Logic
assign ibuffer_pop = translate_req && !ibuffer_empty;

// Output Multiplexer
assign lcd_write_req = main_active ? main_lcd_write_req : 
                       decode_active ? decode_lcd_write_req : 
                       encode_active ? encode_lcd_write_req : 1'b0;
assign lcd_x_pos     = main_active ? main_lcd_x_pos : 
                       decode_active ? decode_lcd_x_pos : 
                       encode_active ? encode_lcd_x_pos : 5'b0;
assign lcd_y_pos     = main_active ? main_lcd_y_pos : 
                       decode_active ? decode_lcd_y_pos : 
                       encode_active ? encode_lcd_y_pos : 2'b0;
assign lcd_text      = main_active ? main_lcd_text : 
                       decode_active ? decode_lcd_text : 
                       encode_active ? encode_lcd_text : 128'b0;
assign lcd_text_len  = main_active ? main_lcd_text_len : 
                       decode_active ? decode_lcd_text_len : 
                       encode_active ? encode_lcd_text_len : 8'b0;

assign rgb_r = main_active ? main_rgb_r : decode_active ? decode_rgb_r : encode_active ? encode_rgb_r : 1'b0;
assign rgb_g = main_active ? main_rgb_g : decode_active ? decode_rgb_g : encode_active ? encode_rgb_g : 1'b0;
assign rgb_b = main_active ? main_rgb_b : decode_active ? decode_rgb_b : encode_active ? encode_rgb_b : 1'b0;

assign led_enable = decode_active ? decode_led_enable : 8'b0;
assign piezo_enable = encode_active ? encode_piezo_enable : 1'b0;
assign piezo_duration = encode_active ? encode_piezo_duration : 16'b0;
assign piezo_frequency = encode_active ? encode_piezo_frequency : 16'b0;
assign servo_angle = encode_active ? encode_servo_angle : 8'b0;

assign ibuffer_push = decode_active ? decode_ibuffer_push : encode_active ? encode_ibuffer_push : 1'b0;
assign ibuffer_data_in = decode_active ? decode_ibuffer_data_in : encode_active ? encode_ibuffer_data_in : 8'b0;
assign translate_req = decode_active ? decode_translate_req : encode_active ? encode_translate_req : 1'b0;

//==============================================================================
// Module Instantiations
//==============================================================================

piezo_controller piezo_ctrl (
    .clk(clk), .rst_n(rst_n),
    .enable(piezo_enable), .duration(piezo_duration), .frequency(piezo_frequency),
    .pwm_out(piezo_out)
);

servo_controller servo_ctrl (
    .clk(clk), .rst_n(rst_n),
    .angle(servo_angle),
    .pwm_out(servo_pwm)
);

lcd_controller lcd_ctrl (
    .clk(clk), .rst_n(rst_n),
    .write_req(lcd_write_req), .x_pos(lcd_x_pos), .y_pos(lcd_y_pos),
    .text(lcd_text), .text_len(lcd_text_len),
    .lcd_e(lcd_e), .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_data(lcd_data)
);

main_ui main_ui_inst (
    .clk(clk), .rst_n(rst_n), .active(main_active),
    .button_pressed(button_pressed),
    .lcd_write_req(main_lcd_write_req), .lcd_x_pos(main_lcd_x_pos), .lcd_y_pos(main_lcd_y_pos),
    .lcd_text(main_lcd_text), .lcd_text_len(main_lcd_text_len),
    .rgb_r(main_rgb_r), .rgb_g(main_rgb_g), .rgb_b(main_rgb_b),
    .next_uuid(main_next_uuid), .ui_update(main_ui_update),
    .long_key_threshold(long_key_threshold)
);

decode_ui decode_ui_inst (
    .clk(clk), .rst_n(rst_n), .active(decode_active),
    .button_pressed(button_pressed),
    .ibuffer_push(decode_ibuffer_push), .ibuffer_data_in(decode_ibuffer_data_in), .ibuffer_full(ibuffer_full),
    .translate_req(decode_translate_req), .translate_done(translate_done),
    .char_out(char_out), .translate_error(translate_error),
    .lcd_write_req(decode_lcd_write_req), .lcd_x_pos(decode_lcd_x_pos), .lcd_y_pos(decode_lcd_y_pos),
    .lcd_text(decode_lcd_text), .lcd_text_len(decode_lcd_text_len),
    .led_enable(decode_led_enable),
    .rgb_r(decode_rgb_r), .rgb_g(decode_rgb_g), .rgb_b(decode_rgb_b),
    .next_uuid(decode_next_uuid), .ui_update(decode_ui_update),
    .dit_time(dit_time), .space_time(space_time),
    .long_key_threshold(long_key_threshold)
);

encode_ui encode_ui_inst (
    .clk(clk), .rst_n(rst_n), .active(encode_active),
    .button_pressed(button_pressed),
    .ibuffer_push(encode_ibuffer_push), .ibuffer_data_in(encode_ibuffer_data_in), .ibuffer_full(ibuffer_full),
    .translate_req(encode_translate_req), .translate_done(translate_done),
    .morse_out(morse_out),
    .lcd_write_req(encode_lcd_write_req), .lcd_x_pos(encode_lcd_x_pos), .lcd_y_pos(encode_lcd_y_pos),
    .lcd_text(encode_lcd_text), .lcd_text_len(encode_lcd_text_len),
    .piezo_enable(encode_piezo_enable), .piezo_duration(encode_piezo_duration), .piezo_frequency(encode_piezo_frequency),
    .rgb_r(encode_rgb_r), .rgb_g(encode_rgb_g), .rgb_b(encode_rgb_b),
    .servo_angle(encode_servo_angle),
    .next_uuid(encode_next_uuid), .ui_update(encode_ui_update),
    .dit_time(dit_time), .dah_time(dah_time),
    .long_key_threshold(long_key_threshold)
);

input_buffer ibuffer_inst (
    .clk(clk), .rst_n(rst_n),
    .push(ibuffer_push), .data_in(ibuffer_data_in),
    .pop(ibuffer_pop), .data_out(ibuffer_data_out),
    .full(ibuffer_full), .empty(ibuffer_empty)
);

translator translator_inst (
    .clk(clk), .rst_n(rst_n),
    .req(translate_req), .mode(decode_active ? 1'b0 : 1'b1),
    .data_in(ibuffer_data_out),
    .morse_out(morse_out), .morse_out_len(morse_out_len),
    .char_out(char_out),
    .done(translate_done), .error(translate_error)
);

endmodule