`timescale 1ns/100ps
// -----------------------------------------------------------------------------
// CO2070 Computer Architecture - Lab 07
// Testbench for the Simple Processor with data and instruction cache hierarchies
//
// The test program in programmer/instr_mem.mem exercises:
//   - write allocate on a clean miss
//   - read/write hits within the same 4-byte block
//   - dirty write-back on a conflict miss
//   - refetching a previously evicted block
//
// The wave dump includes CPU, cache, and memory internals so GTKWave can show
// cache hit/miss behavior and BUSYWAIT control clearly.
// -----------------------------------------------------------------------------

module cpu_tb;

    reg CLK, RESET;
    wire [31:0] PC;
    wire [31:0] INSTRUCTION;
    wire        INST_BUSYWAIT;
    wire        IMEM_READ;
    wire [5:0]  IMEM_ADDRESS;
    wire [127:0] IMEM_READDATA;
    wire        IMEM_BUSYWAIT;

    wire        MEM_READ;
    wire        MEM_WRITE;
    wire [7:0]  MEM_ADDRESS;
    wire [7:0]  MEM_WRITEDATA;
    wire [7:0]  MEM_READDATA;
    wire        MEM_BUSYWAIT;

    wire        DMEM_READ;
    wire        DMEM_WRITE;
    wire [5:0]  DMEM_ADDRESS;
    wire [31:0] DMEM_WRITEDATA;
    wire [31:0] DMEM_READDATA;
    wire        DMEM_BUSYWAIT;

    // CPU, data cache, instruction cache, and block memories.
    cpu mycpu(
        PC,
        INSTRUCTION,
        CLK,
        RESET,
        MEM_READ,
        MEM_WRITE,
        MEM_ADDRESS,
        MEM_WRITEDATA,
        MEM_READDATA,
        MEM_BUSYWAIT,
        INST_BUSYWAIT
    );

    // The instruction cache continuously fetches the instruction at the PC.
    // It stalls the CPU during the first lookup and on each block miss.
    instruction_cache my_instruction_cache(
        CLK,
        RESET,
        1'b1,
        PC[9:0],
        INSTRUCTION,
        INST_BUSYWAIT,
        IMEM_READ,
        IMEM_ADDRESS,
        IMEM_READDATA,
        IMEM_BUSYWAIT
    );

    instruction_memory my_instruction_memory(
        CLK,
        IMEM_READ,
        IMEM_ADDRESS,
        IMEM_READDATA,
        IMEM_BUSYWAIT
    );

    data_cache my_data_cache(
        CLK,
        RESET,
        MEM_READ,
        MEM_WRITE,
        MEM_ADDRESS,
        MEM_WRITEDATA,
        MEM_READDATA,
        MEM_BUSYWAIT,
        DMEM_READ,
        DMEM_WRITE,
        DMEM_ADDRESS,
        DMEM_WRITEDATA,
        DMEM_READDATA,
        DMEM_BUSYWAIT
    );

    data_memory my_data_memory(
        CLK,
        RESET,
        DMEM_READ,
        DMEM_WRITE,
        DMEM_ADDRESS,
        DMEM_WRITEDATA,
        DMEM_READDATA,
        DMEM_BUSYWAIT
    );

    initial begin
        $dumpfile("cpu_wavedata.vcd");
        $dumpvars(0, cpu_tb);

        CLK   = 1'b0;
        RESET = 1'b0;

        // Reset PC, register file, and data memory.
        #1;
        RESET = 1'b1;
        #8;
        RESET = 1'b0;

        // The 17-instruction factorial program fills five instruction-cache
        // lines, executes nested loops, then performs a dirty-line write-back.
        #8000;

        $display("Factorial(5) demonstration final register values:");
        $display("R1=%h R2=%h R3=%h R4=%h R5=%h R6=%h R7=%h",
                 mycpu.my_reg_file.reg_array[1],
                 mycpu.my_reg_file.reg_array[2],
                 mycpu.my_reg_file.reg_array[3],
                 mycpu.my_reg_file.reg_array[4],
                 mycpu.my_reg_file.reg_array[5],
                 mycpu.my_reg_file.reg_array[6],
                 mycpu.my_reg_file.reg_array[7]);
        $display("Expected factorial result: R2=78 and Memory[40]=78");
        $display("Memory[40]=%h", my_data_memory.memory_array[8'h40]);
        $display("Data cache line 0: valid=%b dirty=%b tag=%b data=%h",
                 my_data_cache.valid_array[0],
                 my_data_cache.dirty_array[0],
                 my_data_cache.tag_array[0],
                 my_data_cache.data_array[0]);
        $display("Instruction cache line 0: valid=%b tag=%b data=%h",
                 my_instruction_cache.valid_array[0],
                 my_instruction_cache.tag_array[0],
                 my_instruction_cache.data_array[0]);

        $finish;
    end

    // Clock period = 8 time units.
    always begin
        #4 CLK = ~CLK;
    end

endmodule
