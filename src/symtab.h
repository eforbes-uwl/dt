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
 * data types to implement the symbol table
 */

#ifndef __SYMTAB_H__
#define __SYMTAB_H__

#include <stdint.h>
#include <inttypes.h>

typedef enum {
    SYMTAB_IREG,
    SYMTAB_FREG, // floating-point regs, once implemented
    SYMTAB_MEM
} symtab_type_t;

typedef struct symtab_entry_type {
    char * name;
    symtab_type_t type;
    uint64_t value; /* either address or reg no */
    struct symtab_entry_type * next;
} symtab_entry_t;

void symtab_new(char*, symtab_type_t);
void symtab_update(char*, uint64_t);
int64_t symtab_lookup(char*);
symtab_type_t symtab_type(char*);
void dump_symtab();
char *internal_name();


#endif
