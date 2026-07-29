`timescale 1ns/100ps
// -----------------------------------------------------------------------------
// CO2070 Computer Architecture - Lab 07
// 1024 x 8-bit instruction memory, read as 16-byte blocks.
//
// The cache supplies a 6-bit block address. A block read therefore accesses
// bytes {address, 4'b0000} through {address, 4'b1111}. Each byte takes five
// CPU clock cycles (40 ns with the testbench clock), making a full block fetch
// take 16 x 5 = 80 cycles as specified in the lab handout.
// -----------------------------------------------------------------------------

module instruction_memory(
    clock,
    read,
    address,
    readinst,
    busywait
);

input               clock;
input               read;
input      [5:0]    address;
output reg [127:0]  readinst;
output reg          busywait;

reg readaccess;
reg [7:0] memory_array [0:1023];
integer i;

initial begin
    busywait   = 1'b0;
    readaccess = 1'b0;
    readinst   = 128'b0;

    for (i = 0; i < 1024; i = i + 1) begin
        memory_array[i] = 8'b0;
    end

    // The complete factorial demonstration program occupies 17 instructions
    // (68 bytes), exercising five instruction-cache blocks. File bytes are
    // little-endian: the first byte is instruction[7:0].
    $readmemb("programmer/instr_mem.mem", memory_array, 0, 67);
end

// A new cache request starts a block read. The cache holds READ high until the
// memory deasserts BUSYWAIT, so readaccess records the outstanding request.
always @(read) begin
    if (read) begin
        busywait   = 1'b1;
        readaccess = 1'b1;
    end
end

always @(posedge clock) begin
    if (readaccess) begin
        // Blocking delayed assignments intentionally serialize the sixteen
        // byte transfers: 16 x #40 = #640 = 80 clock cycles.
        readinst[7:0]     = #40 memory_array[{address, 4'b0000}];
        readinst[15:8]    = #40 memory_array[{address, 4'b0001}];
        readinst[23:16]   = #40 memory_array[{address, 4'b0010}];
        readinst[31:24]   = #40 memory_array[{address, 4'b0011}];
        readinst[39:32]   = #40 memory_array[{address, 4'b0100}];
        readinst[47:40]   = #40 memory_array[{address, 4'b0101}];
        readinst[55:48]   = #40 memory_array[{address, 4'b0110}];
        readinst[63:56]   = #40 memory_array[{address, 4'b0111}];
        readinst[71:64]   = #40 memory_array[{address, 4'b1000}];
        readinst[79:72]   = #40 memory_array[{address, 4'b1001}];
        readinst[87:80]   = #40 memory_array[{address, 4'b1010}];
        readinst[95:88]   = #40 memory_array[{address, 4'b1011}];
        readinst[103:96]  = #40 memory_array[{address, 4'b1100}];
        readinst[111:104] = #40 memory_array[{address, 4'b1101}];
        readinst[119:112] = #40 memory_array[{address, 4'b1110}];
        readinst[127:120] = #40 memory_array[{address, 4'b1111}];
        busywait   = 1'b0;
        readaccess = 1'b0;
    end
end

endmodule
