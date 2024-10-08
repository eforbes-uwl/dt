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
 * data types for the intermediate representation
 */

#ifndef __INST_H__
#define __INST_H__

#include <stdint.h>
#include <inttypes.h>

typedef struct {
    int inst_id;
    uint32_t opcode;
    uint32_t funct3;
    uint32_t funct7;
    union {
        uint32_t rdst;
        uint32_t rsrc0;
    };
    union {
        uint32_t rsrc1;
    };
    union {
        uint32_t rsrc2;
    };
    union {
        int32_t imm;
        int32_t shamt;
        uint64_t target_address;
    };
    union {
        char *target_name;
    };
} instruction_t;

void calculate_offsets();
uint32_t encode_instruction(instruction_t *);
void encode_instructions();

uint32_t encode_r_type(instruction_t *);
uint32_t encode_i_type(instruction_t *);
uint32_t encode_s_type(instruction_t *);
uint32_t encode_b_type(instruction_t *);
uint32_t encode_u_type(instruction_t *);
uint32_t encode_j_type(instruction_t *);


#endif
