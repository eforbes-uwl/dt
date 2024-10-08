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
 * data types to represent memblocks and lists of memblocks
 */

#ifndef __MEM_H__
#define __MEM_H__

#include <stdint.h>
#include <inttypes.h>

#include "inst.h"

typedef enum {
    ENTRY_INCOMPLETE = 1,
    ENTRY_COMPLETE = 2
} status_t;

typedef enum {
    ENTRY_DEFINITION,
    ENTRY_JOIN_NODE, /* the reconvergence point after an if or if-else or the continuation point after a loop */
    ENTRY_INSTRUCTION,
    ENTRY_BDATA,
    ENTRY_HDATA,
    ENTRY_WDATA,
    ENTRY_LDATA,
    ENTRY_FDATA,
    ENTRY_DDATA,
    ENTRY_SDATA
} type_t;

typedef struct mem_entry_type {
    status_t status;
    type_t type;
    char * name;
    uint64_t address;
    uint32_t size; /* in bytes -- could be zero for definitions */

    instruction_t * inst;

    /* value */
    union {
        uint32_t encoding;
        uint64_t ivalue;
        float    fvalue;
        double   dvalue;
        char    *svalue;
    };

    struct mem_entry_type * next;
} mem_entry_t;

mem_entry_t * new_mem_entry(type_t, uint32_t);
mem_entry_t * new_instruction(uint32_t);
mem_entry_t * append_inst(mem_entry_t*, mem_entry_t*);

typedef struct memblock_list_type {
    uint64_t min_address;
    uint64_t max_address;
    mem_entry_t *head;
    struct memblock_list_type * next;
} memblock_list_t;

void add_memblock(mem_entry_t*);
void check_mem_bounds();

extern  memblock_list_t *block_list;

#endif
