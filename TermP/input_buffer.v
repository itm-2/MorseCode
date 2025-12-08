//==============================================================================
// Input Buffer Module (FIFO)
//==============================================================================
module input_buffer #(
    parameter DEPTH = 256,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    
    // Write Interface
    input wire push,
    input wire [DATA_WIDTH-1:0] data_in,
    
    // Read Interface
    input wire pop,
    output reg [DATA_WIDTH-1:0] data_out,
    
    // Status
    output wire full,
    output wire empty
);

//==============================================================================
// Internal Registers
//==============================================================================
reg [DATA_WIDTH-1:0] buffer [0:DEPTH-1];
reg [$clog2(DEPTH):0] write_ptr;
reg [$clog2(DEPTH):0] read_ptr;
reg [$clog2(DEPTH):0] count;

//==============================================================================
// Status Signals
//==============================================================================
assign full = (count == DEPTH);
assign empty = (count == 0);

//==============================================================================
// Write Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_ptr <= 0;
    end else if (push && !full) begin
        buffer[write_ptr[$clog2(DEPTH)-1:0]] <= data_in;
        write_ptr <= write_ptr + 1;
    end
end

//==============================================================================
// Read Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_ptr <= 0;
        data_out <= 8'b0;
    end else if (pop && !empty) begin
        data_out <= buffer[read_ptr[$clog2(DEPTH)-1:0]];
        read_ptr <= read_ptr + 1;
    end
end

//==============================================================================
// Count Logic
//==============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 0;
    end else begin
        case ({push && !full, pop && !empty})
            2'b10: count <= count + 1;  // Push only
            2'b01: count <= count - 1;  // Pop only
            default: count <= count;     // Both or neither
        endcase
    end
end

endmodule