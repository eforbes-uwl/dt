/* This file is part of the DuctTape (dt) high-level assembler for 
 * RISC-V. The dt project was written by Justin Severeid and Elliott 
 * Forbes, University of Wisconsin-La Crosse, copyright 2020-2024.
 *
 * DuctTape is free software: you can redistribute it and/or modify 
 * it under the terms of the GNU General Public License as published 
 * by the Free Software Foundation, either version 3 of the License, 
 * or (at your option) any later version.
 *
 * DuctTape is distributed in the hope that it will be useful, but 
 * WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License 
 * along with DuctTape. If not, see <https://www.gnu.org/licenses/>. 
 *
 *
 *
 * The dt project can be found at https://cs.uwlax.edu/~eforbes/dt/
 *
 * If you use dt in your published research, please consider 
 * citing the following:
 *
 * Severeid, J. and Forbes, E., "dt: A High-level Assembler for RISC-V," 
 * Proceedings of the 53rd Midwest Instruction and Computing Symposium, 
 * April 2020. 
 *
 * If you found dt helpful, please let us know! Email eforbes@uwlax.edu
 *
 * There are bound to be bugs, let us know those too.
 */

/*
 * constants for opcodes and function codes for instructions, also 
 * a flattened numbering for the internal representation of each 
 * instruction type
 */

#ifndef __RISCVARCH_H__
#define __RISCVARCH_H__

/* arbitrary indexed defines for each instruction */

#define RISCV_LUI        0
#define RISCV_AUIPC      1   
#define RISCV_JAL        2
#define RISCV_JALR       3
#define RISCV_BEQ        4
#define RISCV_BNE        5
#define RISCV_BLT        6
#define RISCV_BGE        7
#define RISCV_BLTU       8
#define RISCV_BGEU       9 
#define RISCV_LB        10
#define RISCV_LH        11
#define RISCV_LW        12
#define RISCV_LBU       13
#define RISCV_LHU       14
#define RISCV_SB        15
#define RISCV_SH        16
#define RISCV_SW        17
#define RISCV_ADDI      18
#define RISCV_SLTI      19
#define RISCV_SLTIU     20
#define RISCV_XORI      21
#define RISCV_ORI       22
#define RISCV_ANDI      23
#define RISCV_SLLI      24
#define RISCV_SRLI      25
#define RISCV_SRAI      26
#define RISCV_ADD       27
#define RISCV_SUB       28
#define RISCV_SLL       29
#define RISCV_SLT       30
#define RISCV_SLTU      31
#define RISCV_XOR       32
#define RISCV_SRL       33
#define RISCV_SRA       34
#define RISCV_OR        35
#define RISCV_AND       36
#define RISCV_FENCE     37
#define RISCV_FENCE_I   38
#define RISCV_ECALL     39
#define RISCV_EBREAK    40
#define RISCV_CSRRW     41
#define RISCV_CSRRS     42
#define RISCV_CSRRC     43
#define RISCV_CSRRWI    44
#define RISCV_CSRRSI    45
#define RISCV_CSRRCI    46 

/*psuedo instructions*/
#define RISCV_J         47
#define RISCV_JR        48
#define RISCV_RET       50

#define RISCV_MUL       51
#define RISCV_DIV       52

/* opcode */
#define OP_LUI          0x37
#define OP_AUIPC        0x17
#define OP_JAL          0x6f
#define OP_JALR         0x67
#define OP_BEQ          0x63
#define OP_BNE          0x63
#define OP_BLT          0x63
#define OP_BGE          0x63
#define OP_BLTU         0x63
#define OP_BGEU         0x63
#define OP_LB           0x3
#define OP_LH           0x3
#define OP_LW           0x3
#define OP_LBU          0x3
#define OP_LHU          0x3
#define OP_SB           0x23
#define OP_SH           0x23
#define OP_SW           0x23
#define OP_ADDI         0x13
#define OP_SLTI         0x13
#define OP_SLTIU        0x13
#define OP_XORI         0x13
#define OP_ORI          0x13
#define OP_ANDI         0x13
#define OP_SLLI         0x13
#define OP_SRLI         0x13
#define OP_SRAI         0x13
#define OP_ADD          0x33
#define OP_SUB          0x33
#define OP_SLL          0x33
#define OP_SLT          0x33
#define OP_SLTU         0x33
#define OP_XOR          0x33
#define OP_SRL          0x33
#define OP_SRA          0x33
#define OP_OR           0x33
#define OP_AND          0x33
#define OP_ECALL        0x73
#define OP_EBREAK       0x73
#define OP_MUL          0x33
#define OP_DIV          0x33


/* funct3 defines */
#define F3_JALR         0x0
#define F3_BEQ          0x0
#define F3_BNE          0x1
#define F3_BLT          0x4
#define F3_BGE          0x5
#define F3_BLTU         0x6
#define F3_BGEU         0x7
#define F3_LB           0x0
#define F3_LH           0x1
#define F3_LW           0x2
#define F3_LBU          0x4
#define F3_LHU          0x5
#define F3_SB           0x0
#define F3_SH           0x1
#define F3_SW           0x2
#define F3_ADDI         0x0
#define F3_SLTI         0x2
#define F3_SLTIU        0x3
#define F3_XORI         0x4
#define F3_ORI          0x6
#define F3_ANDI         0x7
#define F3_SLLI         0x1
#define F3_SRLI         0x5
#define F3_SRAI         0x5
#define F3_ADD          0x0
#define F3_SUB          0x0
#define F3_SLL          0x1
#define F3_SLT          0x2
#define F3_SLTU         0x3
#define F3_XOR          0x4
#define F3_SRL          0x5
#define F3_SRA          0x5
#define F3_OR           0x6
#define F3_AND          0x7
#define F3_ECALL        0x0
#define F3_EBREAK       0x0
#define F3_MUL          0x0
#define F3_DIV          0x4

/* funct7 defines */
#define F7_ANDI         0x0
#define F7_SLLI         0x0
#define F7_SRLI         0x0
#define F7_SRAI         0x20
#define F7_ADD          0x0
#define F7_SUB          0x20
#define F7_SLL          0x0
#define F7_SLT          0x0
#define F7_SLTU         0x0
#define F7_XOR          0x0
#define F7_SRL          0x0
#define F7_SRA          0x20
#define F7_OR           0x0
#define F7_AND          0x0
#define F7_MUL          0x1
#define F7_DIV          0x1

#endif
