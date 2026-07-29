CO2070 Lab 7 - Instruction Cache and Memory
=============================================

This submission extends the supplied Lab 6 processor with a direct-mapped
instruction cache and a 1024-byte block instruction memory. It runs a complete
factorial program that calculates 5! = 120 (0x78) using nested loops and
repeated addition, then stores the result at data-memory address 0x40.

Compile and run
---------------
iverilog -g2012 -Wall -o cpu_sim cpu_tb.v cpu.v alu.v reg_file.v data_cache.v data_memory.v instruction_cache.v instruction_memory.v
vvp cpu_sim

Open the timing diagram
-----------------------
gtkwave cpu_wavedata.vcd lab7_waveform.gtkw

The simulation generates cpu_wavedata.vcd automatically. The included
lab7_waveform.gtkw selects the CPU and instruction-cache control signals for
inspection in GTKWave.

Expected final console values
-----------------------------
R1=00 R2=78 R3=78 R4=00 R5=01 R6=00 R7=00
Memory[40]=78

Instruction cache implementation
--------------------------------
* Cache size: 128 bytes, direct mapped
* Block size: 16 bytes / 4 instructions
* Lines: 8, each with a 128-bit data block, a 3-bit tag and a valid bit
* Address fields: tag=PC[9:7], index=PC[6:4], word offset=PC[3:2]
* Instruction memory: 1024 bytes, addressed by a 6-bit block address
* Hit delays: #1 cache indexing, #0.9 tag check, #1 word select
* Miss service: the block memory returns 16 bytes over 80 CPU cycles; the CPU
  remains stalled through INST_BUSYWAIT until the filled line becomes a hit.

Factorial program and waveform explanation
------------------------------------------
The full 17-instruction program is documented in programmer/sample_program.s.
It spans five instruction-cache blocks, so the first execution of each block
produces a visible 80-cycle instruction-memory fetch. After all four lines are
filled, the nested factorial loops run from instruction-cache hits.

In GTKWave, follow these values to explain the algorithm:
* PC loops through the multiply body while r4 counts down to zero.
* r1 changes 5, 4, 3, 2, 1, 0 across outer-loop iterations.
* r2 changes 1, 5, 20, 60, 120 (hex 01, 05, 14, 3c, 78).
* INST_BUSYWAIT and IMEM_BUSYWAIT are high for the five initial cache misses.
* The final swi requests write 78 to 0x40, then access 0xC0. Both addresses map
  to data-cache index 0, so the second access evicts and writes back 0x40.

Useful GTKWave signals
----------------------
cpu_tb.PC
cpu_tb.INSTRUCTION
cpu_tb.INST_BUSYWAIT
cpu_tb.my_instruction_cache.hit
cpu_tb.my_instruction_cache.state
cpu_tb.IMEM_READ
cpu_tb.IMEM_ADDRESS
cpu_tb.IMEM_BUSYWAIT
cpu_tb.MEM_BUSYWAIT
cpu_tb.my_data_cache.state
cpu_tb.mycpu.my_reg_file.R1_DEBUG
cpu_tb.mycpu.my_reg_file.R2_DEBUG
cpu_tb.mycpu.my_reg_file.R3_DEBUG
cpu_tb.mycpu.my_reg_file.R4_DEBUG
