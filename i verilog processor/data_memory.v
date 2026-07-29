`timescale 1ns/100ps
/*
Module  : 64x32-bit block data memory
Purpose : Main memory used behind the Lab 6 data cache.

The CPU still addresses bytes, but the cache talks to main memory in 4-byte
blocks. Therefore ADDRESS is a 6-bit block address. Each read or write takes
4 x 5 = 20 CPU clock cycles, modelled with an artificial #160 delay because the
testbench uses an 8 ns clock period.
*/

module data_memory(
    clock,
    reset,
    read,
    write,
    address,
    writedata,
    readdata,
    busywait
);

input             clock;
input             reset;
input             read;
input             write;
input      [5:0]  address;
input      [31:0] writedata;
output reg [31:0] readdata;
output reg        busywait;

// 256 bytes of main memory, grouped as 64 blocks of four bytes.
reg [7:0] memory_array [255:0];

reg readaccess;
reg writeaccess;
integer i;

// Detect a new block-memory transaction from the cache.
always @(read, write) begin
    busywait    = (read || write) ? 1'b1 : 1'b0;
    readaccess  = (read && !write) ? 1'b1 : 1'b0;
    writeaccess = (!read && write) ? 1'b1 : 1'b0;
end

// Complete each block transaction after 20 clock cycles.
always @(posedge clock) begin
    if (readaccess) begin
        readdata = #160 {
            memory_array[{address, 2'b11}],
            memory_array[{address, 2'b10}],
            memory_array[{address, 2'b01}],
            memory_array[{address, 2'b00}]
        };
        busywait   = 1'b0;
        readaccess = 1'b0;
    end

    if (writeaccess) begin
        #160;
        memory_array[{address, 2'b00}] = writedata[7:0];
        memory_array[{address, 2'b01}] = writedata[15:8];
        memory_array[{address, 2'b10}] = writedata[23:16];
        memory_array[{address, 2'b11}] = writedata[31:24];
        busywait    = 1'b0;
        writeaccess = 1'b0;
    end
end

// Reset memory contents and transaction state.
always @(posedge reset) begin
    if (reset) begin
        for (i = 0; i < 256; i = i + 1) begin
            memory_array[i] = 8'b00000000;
        end

        readdata    = 32'b0;
        busywait    = 1'b0;
        readaccess  = 1'b0;
        writeaccess = 1'b0;
    end
end

endmodule
