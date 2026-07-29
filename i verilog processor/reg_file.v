`timescale 1ns/100ps
// -----------------------------------------------------------------------------
// CO2070 Computer Architecture - Lab 04
// Register File: 8 x 8-bit
//
// This is the same Lab 02 register file, reused in Lab 04.
// It stores eight 8-bit registers: r0 to r7.
//
// Behavior required by the lab:
//   - Read is asynchronous with artificial delay #2.
//   - Write is synchronous at the positive clock edge with artificial delay #1.
//   - Reset is synchronous at the positive clock edge with artificial delay #1.
//
// Extra debug wires R0_DEBUG to R7_DEBUG are included only to make the internal
// register values easy to observe in GTKWave. They do not change the processor's
// functional behavior.
// -----------------------------------------------------------------------------

module reg_file(
    IN,
    OUT1,
    OUT2,
    INADDRESS,
    OUT1ADDRESS,
    OUT2ADDRESS,
    WRITE,
    CLK,
    RESET
);

    // Data input written into the selected destination register.
    input [7:0] IN;

    // Register addresses. 3 bits are enough because 2^3 = 8 registers.
    input [2:0] INADDRESS;
    input [2:0] OUT1ADDRESS;
    input [2:0] OUT2ADDRESS;

    // Control and synchronization signals.
    input WRITE;
    input CLK;
    input RESET;

    // Two read output ports.
    output reg [7:0] OUT1;
    output reg [7:0] OUT2;

    // Internal register array: 8 registers, each 8 bits wide.
    reg [7:0] reg_array [0:7];

    integer i;

    // -------------------------------------------------------------------------
    // GTKWave debug wires.
    // Add these signals in GTKWave to show final register values clearly.
    // -------------------------------------------------------------------------
    wire [7:0] R0_DEBUG;
    wire [7:0] R1_DEBUG;
    wire [7:0] R2_DEBUG;
    wire [7:0] R3_DEBUG;
    wire [7:0] R4_DEBUG;
    wire [7:0] R5_DEBUG;
    wire [7:0] R6_DEBUG;
    wire [7:0] R7_DEBUG;

    assign R0_DEBUG = reg_array[0];
    assign R1_DEBUG = reg_array[1];
    assign R2_DEBUG = reg_array[2];
    assign R3_DEBUG = reg_array[3];
    assign R4_DEBUG = reg_array[4];
    assign R5_DEBUG = reg_array[5];
    assign R6_DEBUG = reg_array[6];
    assign R7_DEBUG = reg_array[7];

    // -------------------------------------------------------------------------
    // Synchronous reset and write.
    // RESET has priority over WRITE.
    // -------------------------------------------------------------------------
    always @(posedge CLK) begin
        if (RESET == 1'b1) begin
            #1;
            for (i = 0; i < 8; i = i + 1) begin
                reg_array[i] <= 8'b00000000;
            end
        end
        else if (WRITE == 1'b1) begin
            #1;
            reg_array[INADDRESS] <= IN;
        end
    end

    // -------------------------------------------------------------------------
    // Asynchronous read port 1.
    // Whenever the selected address or selected register value changes, OUT1 is
    // updated after the required #2 artificial read delay.
    // -------------------------------------------------------------------------
    always @(*) begin
        #2;
        OUT1 = reg_array[OUT1ADDRESS];
    end

    // -------------------------------------------------------------------------
    // Asynchronous read port 2.
    // -------------------------------------------------------------------------
    always @(*) begin
        #2;
        OUT2 = reg_array[OUT2ADDRESS];
    end

endmodule
