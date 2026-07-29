`timescale 1ns/100ps
// -----------------------------------------------------------------------------
// CO2070 Computer Architecture - Lab 07
// Direct-mapped instruction cache: 128 bytes, eight 16-byte blocks
//
// CPU side:
//   - 10-bit byte address from the program counter
//   - one 32-bit instruction returned per access
//
// Instruction-memory side:
//   - 6-bit 16-byte block address
//   - one 128-bit block returned for each cache miss
//
// Address split for a 1 KiB instruction memory and an 8-line, 16-byte cache:
//      ADDRESS[9:7] : tag       (three bits)
//      ADDRESS[6:4] : index     (eight direct-mapped cache lines)
//      ADDRESS[3:0] : offset    (four instruction words per cache line)
// The two least-significant offset bits are always zero for an instruction.
// -----------------------------------------------------------------------------

module instruction_cache(
    clock,
    reset,
    read,
    address,
    instruction,
    busywait,
    mem_read,
    mem_address,
    mem_readdata,
    mem_busywait
);

input               clock;
input               reset;
input               read;
input      [9:0]    address;
output reg [31:0]   instruction;
output reg          busywait;

output reg          mem_read;
output reg [5:0]    mem_address;
input      [127:0]  mem_readdata;
input               mem_busywait;

// Eight cache lines, each holding four 32-bit instructions (16 bytes).
// data_array[line][31:0] is the instruction at offset 0 in that line.
reg [127:0] data_array  [0:7];
reg [2:0]   tag_array   [0:7];
reg         valid_array [0:7];

wire [2:0] tag;
wire [2:0] index;
wire [1:0] word_offset;

assign tag         = address[9:7];
assign index       = address[6:4];
assign word_offset = address[3:2];

// Cache-array indexing has the required #1 artificial latency.
reg [127:0] indexed_block;
reg [2:0]   indexed_tag;
reg         indexed_valid;

always @(*) begin
    #1;
    indexed_block = data_array[index];
    indexed_tag   = tag_array[index];
    indexed_valid = valid_array[index];
end

// Tag validation/comparison has the required #0.9 latency.
// compared_address prevents a result for the previous PC from releasing the
// CPU while a lookup for a new PC is still in progress.
reg hit;
reg [9:0] compared_address;

always @(*) begin
    #0.9;
    hit              = indexed_valid && (indexed_tag == tag);
    compared_address = address;
end

// Selecting the requested 32-bit instruction from the line also takes #1.
// This lookup occurs in parallel with the tag comparison above.
reg [31:0] selected_instruction;

always @(*) begin
    #1;
    case (word_offset)
        2'b00: selected_instruction = indexed_block[31:0];
        2'b01: selected_instruction = indexed_block[63:32];
        2'b10: selected_instruction = indexed_block[95:64];
        2'b11: selected_instruction = indexed_block[127:96];
    endcase
end

// Read hits are handled asynchronously, as required by the lab handout.
always @(*) begin
    if (read && hit && (compared_address == address)) begin
        instruction = selected_instruction;
    end
end

// Miss controller. The CPU holds ADDRESS constant while BUSYWAIT is asserted,
// so the address fields remain valid for the entire memory transaction.
parameter STATE_IDLE         = 2'b00;
parameter STATE_MEM_READ     = 2'b01;
parameter STATE_CACHE_UPDATE = 2'b10;

reg [1:0] state;
reg [1:0] next_state;

wire miss;
assign miss = read && !hit;

// Assert BUSYWAIT immediately when an instruction address changes, before the
// delayed lookup finishes. It is released only after a stable hit in IDLE.
always @(read or address) begin
    if (read) begin
        busywait = 1'b1;
    end
    else begin
        busywait = 1'b0;
    end
end

always @(hit or compared_address or read or state or address) begin
    if (read && hit && (state == STATE_IDLE) &&
        (compared_address == address)) begin
        busywait = 1'b0;
    end
    else if (read) begin
        busywait = 1'b1;
    end
end

always @(*) begin
    case (state)
        STATE_IDLE: begin
            if (miss)
                next_state = STATE_MEM_READ;
            else
                next_state = STATE_IDLE;
        end

        STATE_MEM_READ: begin
            if (mem_busywait == 1'b0)
                next_state = STATE_CACHE_UPDATE;
            else
                next_state = STATE_MEM_READ;
        end

        STATE_CACHE_UPDATE: next_state = STATE_IDLE;
        default:            next_state = STATE_IDLE;
    endcase
end

// Assert READ as soon as a miss appears in IDLE. The instruction memory begins
// the actual block transfer on the next rising edge and READ remains asserted
// throughout STATE_MEM_READ so its address stays stable for the 80-cycle read.
always @(*) begin
    mem_read    = 1'b0;
    mem_address = address[9:4];

    if (!reset && read &&
        ((state == STATE_MEM_READ) || ((state == STATE_IDLE) && miss))) begin
        mem_read    = 1'b1;
        mem_address = address[9:4];
    end
end

integer i;

always @(posedge clock) begin
    if (reset) begin
        state       <= STATE_IDLE;
        instruction <= 32'b0;

        for (i = 0; i < 8; i = i + 1) begin
            data_array[i]  <= 128'b0;
            tag_array[i]   <= 3'b0;
            valid_array[i] <= 1'b0;
        end
    end
    else begin
        state <= next_state;
    end
end

// The supplied instruction memory lowers MEM_BUSYWAIT when its 80-cycle block
// transfer completes. Filling the cache from that completion event gives the
// required #1 write delay, then lets the asynchronous lookup (#1 + #0.9) make
// BUSYWAIT low before the following rising edge: an 81-cycle miss penalty.
always @(negedge mem_busywait) begin
    if (!reset && (state == STATE_MEM_READ)) begin
        state <= STATE_CACHE_UPDATE;
        #1;
        data_array[index]  <= mem_readdata;
        tag_array[index]   <= tag;
        valid_array[index] <= 1'b1;
    end
end

endmodule
