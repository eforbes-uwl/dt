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
 * functions to access the symbol table 
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>

#include "symtab.h"
#include "util.h"

static symtab_entry_t * symtab_head = NULL;

/* this is used to generate random labels/names for the join nodes */
char *internal_name(){
    int i;
    char *retval = (char*)malloc(sizeof(char)*20);
    sprintf(retval,"__internal_");
    for (i=11;i<20;i++){
        retval[i] = 'a' + (random()%26); // generates a random character from a-z
    }
    return retval;
}

void symtab_new(char* name, symtab_type_t entry_type){
    int found = 0;
    symtab_entry_t * working = symtab_head;
    while (working){
        if (strcmp(name, working->name) == 0)
            found = 1;
        working = working->next;
    }

    if (found){
        char buff[100];
        sprintf(buff,"Duplicate label declaration: %s.",name);
        yyerror(buff);
    }
    else{
        symtab_entry_t *new_entry = (symtab_entry_t*) malloc(sizeof(symtab_entry_t));
        new_entry->name = strdup(name);
        new_entry->type = entry_type;
        new_entry->next = symtab_head;
        symtab_head = new_entry;
    }
}

void symtab_update(char* name, uint64_t value){
    symtab_entry_t * working = symtab_head;
    symtab_entry_t * entry = NULL;
    while (working){
        if (strcmp(name, working->name) == 0){
            entry = working;
            break;
        }
        working = working->next;
    }

    if (!entry){
        char buff[100];
        sprintf(buff,"Label not declared: %s",name);
        yyerror(buff);
    }
    else{
        entry->value = value;
    }
}

int64_t symtab_lookup(char* name){
    symtab_entry_t * working = symtab_head;
    symtab_entry_t * entry = NULL;
    while (working){
        if (strcmp(name, working->name) == 0){
            entry = working;
            break;
        }
        working = working->next;
    }

    if (!entry){
        return -1;
    }
    else{
        return entry->value;
    }
}

symtab_type_t symtab_type(char* name){
    symtab_entry_t * working = symtab_head;
    symtab_entry_t * entry = NULL;
    while (working){
        if (strcmp(name, working->name) == 0){
            entry = working;
            break;
        }
        working = working->next;
    }

    if (!entry){
        return -1;
    }
    else{
        return entry->type;
    }
}

void dump_symtab(){
    int i = 0;
    symtab_entry_t * working = symtab_head;
    printf("\nSymbol table entries: \n");
    while (working){
        if (working->type == SYMTAB_MEM)
            printf("entry[%d]: %s\tmem\t0x%012" PRIx64 "\n", i,
                                                          working->name,
                                                          working->value);
        else
            printf("entry[%d]: %s\treg\t$x%" PRIu64 "\n", i,
                                                        working->name,
                                                        working->value);

        i++;
        working = working->next;
    }
}

