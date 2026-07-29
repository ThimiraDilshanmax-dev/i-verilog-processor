`timescale 1ns/100ps
// -----------------------------------------------------------------------------
// CO2070 Computer Architecture - Lab 06
// Direct-mapped 8-block write-back data cache
//
// CPU side:
//   - 8-bit byte address
//   - one byte read/write data
//   - same READ/WRITE/BUSYWAIT interface used in Lab 05
//
// Memory side:
//   - 6-bit block address
//   - 32-bit block read/write data
//   - slow block-memory BUSYWAIT interface
//
// Address split for an 8-entry cache with 4-byte blocks:
//      ADDRESS[7:5] : TAG
//      ADDRESS[4:2] : INDEX
//      ADDRESS[1:0] : OFFSET
//
// Cache policy:
//   - Direct mapped: each address can use exactly one cache line.
//   - Write back: stores modify the cache first; a dirty block is written to
//     main memory only when it is evicted.
//   - Write allocate: a store miss fetches the missing block first, then the
//     requested byte is written into that newly allocated cache line.
// -----------------------------------------------------------------------------

module data_cache(
    clock,
    reset,

    read,
    write,
    address,
    writedata,
    readdata,
    busywait,

    mem_read,
    mem_write,
    mem_address,
    mem_writedata,
    mem_readdata,
    mem_busywait
);

input             clock;       // Cache state and array updates occur on this edge.
input             reset;       // Clears all valid/dirty bits and controller state.

// CPU-side byte-addressed interface.
input             read;        // High for lwd/lwi operations.
input             write;       // High for swd/swi operations.
input      [7:0]  address;     // Byte address requested by the CPU.
input      [7:0]  writedata;   // One byte to store on a write request.
output reg [7:0]  readdata;    // One byte returned for a successful read hit.
output reg        busywait;    // Stalls the CPU while a request is unresolved.

// Main-memory-side block interface. A 32-bit block contains four bytes.
output reg        mem_read;       // Request one block from main memory.
output reg        mem_write;      // Write one dirty block to main memory.
output reg [5:0]  mem_address;    // Block address, not a byte address.
output reg [31:0] mem_writedata;  // Full dirty cache block for write-back.
input      [31:0] mem_readdata;   // Full block supplied after a memory read.
input             mem_busywait;   // High while main memory handles a block request.

// Cache storage: 8 lines, each line storing one 4-byte block plus metadata.
// Bytes are packed little-endian in data_array: [7:0] is offset 0, [15:8] is
// offset 1, [23:16] is offset 2, and [31:24] is offset 3.
reg [31:0] data_array  [0:7];
reg [2:0]  tag_array   [0:7];  // Tag identifies which memory block is stored.
reg        valid_array [0:7];  // 0 means this line has no usable cached block.
reg        dirty_array [0:7];  // 1 means cache data differs from main memory.

// Break the byte address into the fields used by the direct-mapped cache.
// Example: 0x20 = 8'b001_000_00 -> tag 001, index 000, offset 00.
wire [2:0] tag;
wire [2:0] index;
wire [1:0] offset;

assign tag    = address[7:5];
assign index  = address[4:2];
assign offset = address[1:0];

// Values read from the one cache line selected by INDEX. The artificial #1
// delay models the cache-array lookup time specified for the lab.
reg [31:0] indexed_block;
reg [2:0]  indexed_tag;
reg        indexed_valid;
reg        indexed_dirty;

always @(*) begin
    #1;
    indexed_block = data_array[index];
    indexed_tag   = tag_array[index];
    indexed_valid = valid_array[index];
    indexed_dirty = dirty_array[index];
end

// A hit requires both a valid line and a tag match. The #0.9 delay models tag
// comparison. compared_address records the address used for this comparison,
// preventing a just-arrived CPU address from clearing BUSYWAIT using a stale hit.
reg hit;
reg [7:0] compared_address;

always @(*) begin
    #0.9;
    hit = indexed_valid && (indexed_tag == tag);
    compared_address = address;
end

// Select one byte from the 4-byte cache block using OFFSET. This is named
// selected_word in the original lab design, but it is an 8-bit byte value.
// The #1 delay models byte/word selection from the cache block.
reg [7:0] selected_word;

always @(*) begin
    #1;
    case (offset)
        2'b00: selected_word = indexed_block[7:0];
        2'b01: selected_word = indexed_block[15:8];
        2'b10: selected_word = indexed_block[23:16];
        2'b11: selected_word = indexed_block[31:24];
        default: selected_word = 8'b00000000;
    endcase
end

// Read-hit data is returned asynchronously once the selected cache line has
// passed the valid/tag comparison. A miss is completed later by the FSM.
always @(*) begin
    if (read && hit) begin
        readdata = selected_word;
    end
end

// Cache controller finite-state machine used only to handle misses.
//
// IDLE -> MEM_READ -> CACHE_UPDATE -> IDLE        for a clean miss
// IDLE -> MEM_WRITE -> MEM_READ -> CACHE_UPDATE   for a dirty miss
//
// The original CPU request remains asserted while BUSYWAIT is high, so after
// CACHE_UPDATE it is retried automatically and becomes a normal cache hit.
parameter STATE_IDLE         = 3'b000;
parameter STATE_MEM_READ     = 3'b001; // Waiting for a missing block to arrive.
parameter STATE_MEM_WRITE    = 3'b010; // Writing an evicted dirty block back.
parameter STATE_CACHE_UPDATE = 3'b011; // Installing fetched data into the line.

reg [2:0] state;       // Present controller state, clocked below.
reg [2:0] next_state;  // Combinational state chosen from current conditions.

// A miss is meaningful only while the CPU actually requests a load or store.
wire cpu_access;
wire miss;

assign cpu_access = read || write;
assign miss       = cpu_access && !hit;

// Assert BUSYWAIT immediately whenever a CPU request arrives. This conservative
// initial value stops the CPU before lookup delays finish.
always @(read, write) begin
    if (read || write) begin
        busywait = 1'b1;
    end
    else begin
        busywait = 1'b0;
    end
end

// Once lookup completes, release BUSYWAIT only for a stable hit in IDLE. Any
// miss, any active miss-handling state, or a changed address keeps the CPU
// stalled. A normal cache hit therefore stalls only for the lookup delay.
always @(hit, compared_address, read, write, state) begin
    if ((read || write) && hit && (state == STATE_IDLE) &&
        (compared_address == address)) begin
        busywait = 1'b0;
    end
    else if ((read || write) && (!hit || (state != STATE_IDLE))) begin
        busywait = 1'b1;
    end
end

// Next-state logic for the miss-handling FSM.
// A valid dirty victim must be preserved with a write-back before the cache
// replaces it. A clean or invalid victim can be replaced immediately.
always @(*) begin
    case (state)
        STATE_IDLE: begin
            if (miss && indexed_dirty) begin
                // Same index but different tag, and old data was modified.
                next_state = STATE_MEM_WRITE;
            end
            else if (miss) begin
                // Invalid or clean line: fetch the requested block directly.
                next_state = STATE_MEM_READ;
            end
            else begin
                // Either no request or a hit; no memory transaction is needed.
                next_state = STATE_IDLE;
            end
        end

        STATE_MEM_WRITE: begin
            if (mem_busywait == 1'b0) begin
                // Old dirty block is safely in main memory; fetch the new one.
                next_state = STATE_MEM_READ;
            end
            else begin
                // Keep write request active until main memory acknowledges it.
                next_state = STATE_MEM_WRITE;
            end
        end

        STATE_MEM_READ: begin
            if (mem_busywait == 1'b0) begin
                // Requested 4-byte block is now available on mem_readdata.
                next_state = STATE_CACHE_UPDATE;
            end
            else begin
                // Keep read request active while main memory is busy.
                next_state = STATE_MEM_READ;
            end
        end

        STATE_CACHE_UPDATE: begin
            // The sequential block installs mem_readdata during this cycle.
            next_state = STATE_IDLE;
        end

        default: begin
            // Recover safely if state contains an unknown or unsupported value.
            next_state = STATE_IDLE;
        end
    endcase
end

// Drive the block-memory interface from the current FSM state. Defaults are
// inactive so main memory sees a request only during MEM_READ or MEM_WRITE.
always @(*) begin
    mem_read      = 1'b0;
    mem_write     = 1'b0;
    mem_address   = address[7:2];    // Requested byte address converted to block.
    mem_writedata = indexed_block;   // Default value used for a dirty eviction.

    case (state)
        STATE_MEM_READ: begin
            // Fetch the block containing the byte currently requested by CPU.
            mem_read    = 1'b1;
            mem_address = address[7:2];
        end

        STATE_MEM_WRITE: begin
            // Write the victim's original block address, reconstructed from
            // its stored tag and the currently selected index.
            mem_write     = 1'b1;
            mem_address   = {indexed_tag, index};
            mem_writedata = indexed_block;
        end
    endcase
end

integer i; // Loop variable used only while clearing cache lines at reset.

// Sequential cache state and array updates.
always @(posedge clock) begin
    if (reset) begin
        // Data contents are cleared for neat simulation output; validity bits
        // are what actually make every reset cache line unusable.
        state <= STATE_IDLE;
        readdata <= 8'b0;

        for (i = 0; i < 8; i = i + 1) begin
            data_array[i]  <= 32'b0;
            tag_array[i]   <= 3'b0;
            valid_array[i] <= 1'b0;
            dirty_array[i] <= 1'b0;
        end
    end
    else begin
        // Commit the next FSM state selected by the combinational logic.
        state <= next_state;

        if (state == STATE_CACHE_UPDATE) begin
            // Fill the selected line with the 4-byte block returned by memory.
            // A fetched block is clean because it now matches main memory.
            #1;
            data_array[index]  <= mem_readdata;
            tag_array[index]   <= tag;
            valid_array[index] <= 1'b1;
            dirty_array[index] <= 1'b0;
        end
        else if (write && hit && (state == STATE_IDLE)) begin
            // Write hit: update only the addressed byte, keep the remaining
            // three bytes unchanged, and mark the full line dirty. For a
            // write-allocate miss this executes after CACHE_UPDATE returns
            // the controller to IDLE and the retried store becomes a hit.
            #1;
            case (offset)
                2'b00: data_array[index][7:0]   <= writedata;
                2'b01: data_array[index][15:8]  <= writedata;
                2'b10: data_array[index][23:16] <= writedata;
                2'b11: data_array[index][31:24] <= writedata;
            endcase
            tag_array[index]   <= tag;
            valid_array[index] <= 1'b1;
            dirty_array[index] <= 1'b1;
        end
    end
end

endmodule
