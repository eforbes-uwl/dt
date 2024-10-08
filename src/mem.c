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
 * functions to handle memblocks and lists of memblocks
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>

#include "mem.h"
#include "inst.h"
#include "util.h"


mem_entry_t * new_mem_entry(type_t type, uint32_t size){
    mem_entry_t * new_entry = (mem_entry_t *) malloc(sizeof(mem_entry_t));
    new_entry->status = ENTRY_INCOMPLETE;
    new_entry->type = type;
    new_entry->name = NULL;
    new_entry->address = 0;
    new_entry->size = size;
    new_entry->inst = NULL;
    new_entry->ivalue = 0;
    new_entry->next = NULL;

    return new_entry;
}

mem_entry_t * new_instruction(uint32_t opcode){
    instruction_t * new_inst = (instruction_t*)malloc(sizeof(instruction_t));
    mem_entry_t * new_entry = (mem_entry_t*)malloc(sizeof(mem_entry_t));
    new_inst->inst_id = -1;
    new_inst->opcode = opcode;
    new_inst->funct3 = 0;
    new_inst->funct7 = 0;
    new_inst->rdst = 0;
    new_inst->rsrc1 = 0;
    new_inst->rsrc2 = 0;
    new_inst->imm = 0;
    new_inst->target_name = NULL;

    new_entry->status = ENTRY_INCOMPLETE;
    new_entry->type = ENTRY_INSTRUCTION;
    new_entry->name = NULL;
    new_entry->address = 0;
    new_entry->size = 4;
    new_entry->inst = new_inst;
    new_entry->encoding = 0;
    new_entry->next = NULL;

    return new_entry;
}

mem_entry_t *append_inst(mem_entry_t *list, mem_entry_t *inst){
    if (list){
        mem_entry_t *working = list;
        while (working){
            if (working->next == NULL){
                /* found the end of the existing list */
                working->next = inst;
                break;
            }
            working = working->next;
        }
        return list;
    }
    else{
        return inst;
    }
}

memblock_list_t *block_list = NULL;

void add_memblock(mem_entry_t* list){
    mem_entry_t *working;
    memblock_list_t *new_node = (memblock_list_t*)malloc(sizeof(memblock_list_t));

    new_node->head = list;
    new_node->next = NULL;
    if (list){
        working = list;
        while (working){
            if (working->next == NULL)
                break;
            working = working->next;
        }
        if (list->address < working->address){
            /* the typical case where there is at least one instruction or fill in a mem() block */
            new_node->min_address = list->address;
            new_node->max_address = (working->address + working->size) - 1;
        }
        else if (list->address == working->address){
            /* the rare case that a mem() block has only definitions */
            new_node->min_address = list->address;
            new_node->max_address = working->address;
        }
        else {
            /* the case where the last element has a lower address than the first 
               cannot happen normally -- something is seriously screwed up */
            printf("list: %12" PRIx64 " working: %12" PRIx64 "\n",list->address,working->address);
            yyerror("mem() block addresses are corrupt");
        }
    }
    else {
        /* another rare case in which the list was empty -- 
           must be an empty mem() block in the source code */
        new_node->min_address = 0;
        new_node->max_address = 0;
    }

    if (block_list){
        memblock_list_t *working_list = block_list;
        while (working_list){
            if (working_list->next == NULL)
                break;
            working_list = working_list->next;
        }
        working_list->next = new_node;
    }
    else {
        block_list = new_node;
    }
}

void check_mem_bounds(){
    memblock_list_t *check = block_list;

    while (check){
        memblock_list_t *working = block_list;
        while (working){
            if ((check != working) && (check->min_address != check->max_address) && (working->min_address != working->max_address)){
                if (check->min_address <= working->min_address){
                    if (check->max_address >= working->min_address){
                        char buff[200];
                        sprintf(buff,"The memory block starting at address 0x%012" PRIx64 " "
                                     "overlaps the memory block starting at address 0x%012" PRIx64,
                                     check->min_address,working->min_address);
                        yyerror(buff);
                    }
                }
            }
            working = working->next;
        }
        check = check->next;
    }
}

