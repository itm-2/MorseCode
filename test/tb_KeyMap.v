`timescale 1ns / 1ps

module tb_KeyMap;

    // 입력
    reg [1:0] mode;
    reg [2:0] state;
    reg [3:0] key_idx;

    // 출력
    wire [7:0] key_data;

    // DUT 인스턴스
    KeyMap uut (
        .mode(mode),
        .state(state),
        .key_idx(key_idx),
        .key_data(key_data)
    );

    initial begin
        $display("=== KeyMap Look-up Test Start ===");

        // 1. Alphabet Mode Test
        mode = 0; // ALPHABET
        
        // State 0, Key 1 -> Expected '1'
        state = 0; key_idx = 1; #10;
        if (key_data == "1") $display("Alpha State 0 Key 1: PASS ('1')");
        else                 $display("Alpha State 0 Key 1: FAIL (%c)", key_data);

        // State 1, Key 3 -> Expected 'A'
        state = 1; key_idx = 3; #10;
        if (key_data == "A") $display("Alpha State 1 Key 3: PASS ('A')");
        else                 $display("Alpha State 1 Key 3: FAIL (%c)", key_data);

        // State 4, Key 4 -> Expected 'Z'
        state = 4; key_idx = 4; #10;
        if (key_data == "Z") $display("Alpha State 4 Key 4: PASS ('Z')");
        else                 $display("Alpha State 4 Key 4: FAIL (%c)", key_data);

        // Space Key (Key 9)
        state = 2; key_idx = 9; #10;
        if (key_data == 8'h20) $display("Alpha Key 9 (Space): PASS");
        else                   $display("Alpha Key 9 (Space): FAIL");

        // 2. Control Keys Test (Mode 무관)
        mode = 1; // Morse Mode
        key_idx = 12; // ENTER
        #10;
        if (key_data == 8'h0D) $display("Control Key 12 (ENTER): PASS");
        else                   $display("Control Key 12 (ENTER): FAIL");

        // 3. Morse Mode Test
        mode = 1; state = 0; key_idx = 1; #10;
        if (key_data == "-") $display("Morse Key 1 (-): PASS");
        
        key_idx = 2; #10;
        if (key_data == ".") $display("Morse Key 2 (.): PASS");

        // 4. Setting Mode Test
        mode = 2; key_idx = 1; #10;
        if (key_data == 8'h80) $display("Setting Key 1 (UP): PASS");
        else                   $display("Setting Key 1 (UP): FAIL");

        $display("=== Test End ===");
        $finish;
    end

endmodule