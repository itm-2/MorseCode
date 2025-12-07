`timescale 1ns / 1ps

module tb_KeyMapping;

    reg clk;
    reg rst_n;
    reg [12:1] btn_bus; // Debounced Input 가정
    reg [1:0] mode;
    reg [2:0] state;
    reg [15:0] dit_gap_ms;
    reg freeze;

    wire [10:0] key_packet;
    wire key_valid;

    // DUT 연결
    KeyMapping uut (
        .clk(clk), .rst_n(rst_n),
        .btn_bus(btn_bus), .mode(mode), .state(state),
        .dit_gap_ms(dit_gap_ms), .freeze(freeze),
        .key_packet(key_packet), .key_valid(key_valid)
    );

    always #5000 clk = ~clk; // 100kHz

    // 버튼 누르기 Task
    task press_btn(input integer idx, input integer duration_ms);
        begin
            btn_bus[idx] = 1;
            #(duration_ms * 100_000); // ms -> ns 변환
            btn_bus[idx] = 0;
            #50_000_000; // Gap
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; btn_bus = 0;
        mode = 1; // Morse Mode
        state = 0; dit_gap_ms = 100; freeze = 0;

        #20000; rst_n = 1;
        #20000;

        $display("=== tb_KeyMapping Start ===");

        // 1. Single Key (Btn 1 Short)
        // Expected: Type=0(000), Data=1(00000001) -> Packet=0x001
        $display("[Test 1] Single Key (Btn 1 Short)");
        press_btn(1, 100); // 100ms press

        // 2. Long Key (Btn 1 Long)
        // Expected: Type=1(001), Data=1(00000001) -> Packet=0x101
        $display("[Test 2] Long Key (Btn 1 Long)");
        press_btn(1, 400); // 400ms press (>300ms)

        // 3. Control Key (Btn 12 ENTER)
        // Expected: Type=4(100), Data=32(00100000) -> Packet=0x420
        $display("[Test 3] Control Key (Btn 12)");
        press_btn(12, 100);

        // 4. Auto Repeat (Btn 2 Holding)
        // Expected: Multiple pulses of Type=0, Data=2
        $display("[Test 4] Auto Repeat (Btn 2 Hold)");
        btn_bus[2] = 1;
        #500_000_000; // 500ms Hold
        btn_bus[2] = 0;
        #50_000_000;

        $display("=== tb_KeyMapping Finished ===");
        $stop;
    end
endmodule