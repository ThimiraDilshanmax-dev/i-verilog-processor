// -----------------------------------------------------------------------------
// CO2070 Lab 07 demonstration program: factorial calculation
//
// This program calculates 5! = 120 (0x78) without a multiply instruction.
// Multiplication is implemented as repeated addition in the inner loop:
//
//       result = 1
//       for (n = 5; n > 0; n--) {
//           product = 0;
//           repeat n times: product = product + result;
//           result = product;
//       }
//
// Register allocation:
//   r0 = 0, used for all zero comparisons
//   r1 = n, the descending factorial counter (5, 4, 3, 2, 1, 0)
//   r2 = result (1, 5, 20, 60, 120)
//   r3 = product accumulator during one multiplication
//   r4 = repeated-addition counter
//   r5 = constant 1
//
// The 17 instructions span five 16-byte instruction-cache blocks. This makes
// the first pass show five instruction-cache misses, after which the nested
// loops use cache hits. The final result is written to data memory address 0x40.
// A conflicting store to 0xC0 then evicts that dirty cache line, making the
// 0x78 result visible in main memory and demonstrating a data-cache write-back.
// -----------------------------------------------------------------------------

loadi 0 0x00    // r0 = 0
loadi 1 0x05    // r1 = n = 5
loadi 2 0x01    // r2 = result = 1
loadi 5 0x01    // r5 = constant 1

// outer_loop:
loadi 3 0x00    // r3 = product = 0
mov   4 1       // r4 = n (number of additions in this multiplication)

// multiply_loop:
beq   3 4 0     // if r4 == 0, jump forward 3 instructions to multiply_done
add   3 3 2     // r3 = r3 + r2
sub   4 4 5     // r4 = r4 - 1
j     0xFC      // jump back four instructions to multiply_loop

// multiply_done:
mov   2 3       // result = product
sub   1 1 5     // n = n - 1
beq   1 1 0     // if n == 0, jump forward one instruction to done
j     0xF6      // jump back ten instructions to outer_loop

// done:
swi   2 0x40    // memory[0x40] = 120 (0x78)
swi   0 0xC0    // conflict with 0x40: forces its dirty line to write back
j     0xFF      // final self-loop for GTKWave
