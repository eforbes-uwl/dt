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
 * dt parser specification
 */

%glr-parser

%{
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include "riscvarch.h"
#include "mem.h"
#include "pc.h"
#include "inst.h"
#include "output.h"
#include "symtab.h"
#include "util.h"


/* set to 1 to trace the parser when you run dt on a program */
#define YYDEBUG 0
%}

%union {
    char *string;
    int64_t ivalue;
    float fvalue;
    void *mentry;
}

%token INST_LUI
%token INST_AUIPC
%token INST_JAL
%token INST_JALR
%token INST_BEQ
%token INST_BNE
%token INST_BLT
%token INST_BGE
%token INST_BLTU
%token INST_BGEU
%token INST_LB
%token INST_LH
%token INST_LW
%token INST_LBU
%token INST_LHU
%token INST_SB
%token INST_SH
%token INST_SW
%token INST_ADDI
%token INST_SLTI
%token INST_SLTIU
%token INST_XORI
%token INST_ORI
%token INST_ANDI
%token INST_SLLI
%token INST_SRLI
%token INST_SRAI
%token INST_ADD
%token INST_SUB
%token INST_SLL
%token INST_SLT
%token INST_SLTU
%token INST_XOR
%token INST_SRL
%token INST_SRA
%token INST_OR
%token INST_AND
%token INST_FENCE
%token INST_FENCE_I
%token INST_ECALL
%token INST_EBREAK
%token INST_CSRRW
%token INST_CSRRS
%token INST_CSRRC
%token INST_CSRRWI
%token INST_CSRRSI
%token INST_CSRRCI
%token INST_J
%token INST_JR
%token INST_RET
%token INST_NOP
%token INST_MUL
%token INST_DIV

%token MEMBLOCK IFBLOCK ELSEBLOCK WHILEBLOCK DOBLOCK UNTILBLOCK

%token PLUS MINUS MULTIPLY DIVIDE
%token AND OR NOT XOR
%token LSHIFT RSHIFT
%token ADDRESSOF
%token LT GT LTE GTE EQ NEQ
%token ASSIGN

%token LBRACKET RBRACKET
%token LBRACE RBRACE
%token LPAREN RPAREN
%token COLON 

%token BYTEFILL HALFFILL WORDFILL LONGFILL
%token FLOATFILL DOUBLEFILL
%token STRINGZFILL

%token UNKNOWN

%token <string> LABEL

%token <ivalue> IREG FREG
%token PCREG

%token <ivalue> IIMM 
%token <fvalue> FIMM 
%token <string> STRING

%type <ivalue> validireg validfreg
%type <mentry> instlist fill inst definition memblock 

%%

/* add the memblocks to a list of instlists */
program: memblock           {
                                add_memblock((mem_entry_t*)$1);
                                /*dump_instlist($1);*/
                            }
    | program memblock      {
                                add_memblock((mem_entry_t*)$2);
                                /*dump_instlist($2);*/
                            }
    | program PCREG ASSIGN IIMM {
                                set_pc($4);
                            }
    | PCREG ASSIGN IIMM     {
                                set_pc($3);
                            }
    ;

memblock: MEMBLOCK LPAREN IIMM RPAREN LBRACE instlist RBRACE { /* at this point, all instructions/etc can get an address */
                                uint64_t current_address = $3;
                                mem_entry_t *list = (mem_entry_t*) $6;
                                mem_entry_t * working = list;
                                while (working){
                                    /* correct for alignment, depending on data type */
                                    if (((working->type == ENTRY_LDATA) || 
                                       (working->type == ENTRY_DDATA)) && 
                                       (current_address & 0x7)){ // 8 byte types
                                        while (current_address & 0x7)
                                            current_address++;
                                    }
                                    else if (((working->type == ENTRY_INSTRUCTION) || 
                                            (working->type == ENTRY_WDATA) || 
                                            (working->type == ENTRY_FDATA)) && 
                                            (current_address & 0x3)){ // 4 byte types
                                        while (current_address & 0x3)
                                            current_address++;
                                    }
                                    else if ((working->type == ENTRY_HDATA) && 
                                            (current_address & 0x1)){ // 2 byte types
                                        while (current_address & 0x1)
                                            current_address++;
                                    }
                                    // 1 byte types (byte, string) do not need alignment

                                    // now save the finalized address, and update the symbol table
                                    working->address = current_address;
                                    if (working->name && (working->type != ENTRY_DEFINITION)){
                                        /* update symbol table w/ the new address */
                                        symtab_update(working->name,working->address);
                                    }
                                    current_address += working->size;
                                    working = working->next;
                                }
                                $$=list;
                            }
    ;

instlist:                   {$$=NULL;}
    | instlist inst         {$$=(void*)append_inst((mem_entry_t*)$1,(mem_entry_t*)$2);}
    | instlist definition   {$$=(void*)append_inst((mem_entry_t*)$1,(mem_entry_t*)$2);}
    | instlist fill         {$$=(void*)append_inst((mem_entry_t*)$1,(mem_entry_t*)$2);}
    | instlist IFBLOCK LPAREN validireg RPAREN LBRACE instlist RBRACE {
                                mem_entry_t *top_node;
                                mem_entry_t *branch;
                                mem_entry_t *join_node;
                                /* generate the branch that will test the condition reg */
                                branch = new_instruction(OP_BEQ);
                                branch->inst->inst_id=RISCV_BEQ; 
                                branch->inst->rsrc1=$4; 
                                branch->inst->rsrc2=0; // compare to $r0
                                /* generate the join node that will be the target of the branch */
                                join_node = new_mem_entry(ENTRY_JOIN_NODE,0);
                                /* name the join node */
                                join_node->name = internal_name();
                                symtab_new(join_node->name,SYMTAB_MEM);
                                /* set the target of the branch to the join node name */
                                branch->inst->target_name = strdup(join_node->name);
                                /* link the branch to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,branch);
                                /* link the second instlist to the branch */
                                top_node = append_inst(top_node,(mem_entry_t*)$7);
                                /* link the join node to the end of the second instlist */
                                top_node = append_inst(top_node,join_node);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist LABEL COLON IFBLOCK LPAREN validireg RPAREN LBRACE instlist RBRACE {
                                mem_entry_t *top_node;
                                mem_entry_t *branch;
                                mem_entry_t *join_node;
                                /* generate the branch that will test the condition reg */
                                branch = new_instruction(OP_BEQ);
                                branch->inst->inst_id=RISCV_BEQ; 
                                branch->inst->rsrc1=$6;
                                branch->inst->rsrc2=0; // compare to $r0
                                /* name the branch */
                                branch->name = strdup($2);
                                symtab_new(branch->name,SYMTAB_MEM);
                                /* generate the join node that will be the target of the branch */
                                join_node = new_mem_entry(ENTRY_JOIN_NODE,0);
                                /* name the join node */
                                join_node->name = internal_name();
                                symtab_new(join_node->name,SYMTAB_MEM);
                                /* set the target of the branch to the join node name */
                                branch->inst->target_name = strdup(join_node->name);
                                /* link the branch to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,branch);
                                /* link the second instlist to the branch */
                                top_node = append_inst(top_node,(mem_entry_t*)$9);
                                /* link the join node to the end of the second instlist */
                                top_node = append_inst(top_node,join_node);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist IFBLOCK LPAREN validireg RPAREN LBRACE instlist RBRACE ELSEBLOCK LBRACE instlist RBRACE {
                                mem_entry_t *top_node;
                                mem_entry_t *branch;
                                mem_entry_t *jump;
                                mem_entry_t *join_else;
                                mem_entry_t *join_done;
                                /* generate branch to else clause */
                                branch = new_instruction(OP_BEQ); 
                                branch->inst->inst_id=RISCV_BEQ; 
                                branch->inst->rsrc1=$4; 
                                branch->inst->rsrc2=0; // compare to $r0
                                /* generate and name join node for the beginning of else clause */
                                join_else = new_mem_entry(ENTRY_JOIN_NODE,0);
                                join_else->name = internal_name();
                                symtab_new(join_else->name,SYMTAB_MEM);
                                /* set the branch target to the join node name */
                                branch->inst->target_name = strdup(join_else->name);
                                /* generate jump to skip over else clause */
                                jump = new_instruction(OP_JAL);
                                jump->inst->inst_id=RISCV_J; 
                                /* generate and name join node that goes after the else clause */
                                join_done = new_mem_entry(ENTRY_JOIN_NODE,0);
                                join_done->name = internal_name();
                                symtab_new(join_done->name,SYMTAB_MEM);
                                /* set the jump target to the join node name */
                                jump->inst->target_name = strdup(join_done->name);
                                /* link the branch to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,branch);
                                /* link the second instlist (if clause) to the branch */
                                top_node = append_inst(top_node,(mem_entry_t*)$7);
                                /* link the jump to the end of the second instlist (if clause) */
                                top_node = append_inst(top_node,jump);
                                /* link the else join node to the end of the jump */
                                top_node = append_inst(top_node,join_else);
                                /* link the third instlist to the end of the first join node */
                                top_node = append_inst(top_node,(mem_entry_t*)$11);
                                /* link the second join node to the end of the third instlist */
                                top_node = append_inst(top_node,join_done);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist LABEL COLON IFBLOCK LPAREN validireg RPAREN LBRACE instlist RBRACE ELSEBLOCK LBRACE instlist RBRACE {
                                mem_entry_t *top_node;
                                mem_entry_t *branch;
                                mem_entry_t *jump;
                                mem_entry_t *join_else;
                                mem_entry_t *join_done;
                                /* generate branch to else clause */
                                branch = new_instruction(OP_BEQ);
                                branch->inst->inst_id=RISCV_BEQ; 
                                branch->inst->rsrc1=$6;
                                branch->inst->rsrc2=0; // compare to $r0
                                /* name the branch */
                                branch->name = strdup($2);
                                symtab_new(branch->name,SYMTAB_MEM);
                                /* generate and name join node for the beginning of else clause */
                                join_else = new_mem_entry(ENTRY_JOIN_NODE,0);
                                join_else->name = internal_name();
                                symtab_new(join_else->name,SYMTAB_MEM);
                                /* set the branch target to the join node name */
                                branch->inst->target_name = strdup(join_else->name);
                                /* generate jump to skip over else clause */
                                jump = new_instruction(OP_JAL);
                                jump->inst->inst_id=RISCV_J; 
                                /* generate and name join node that goes after the else clause */
                                join_done = new_mem_entry(ENTRY_JOIN_NODE,0);
                                join_done->name = internal_name();
                                symtab_new(join_done->name,SYMTAB_MEM);
                                /* set the jump target to the join node name */
                                jump->inst->target_name = strdup(join_done->name);
                                /* link the branch to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,branch);
                                /* link the second instlist (if clause) to the branch */
                                top_node = append_inst(top_node,(mem_entry_t*)$9);
                                /* link the jump to the end of the second instlist (if clause) */
                                top_node = append_inst(top_node,jump);
                                /* link the else join node to the end of the jump */
                                top_node = append_inst(top_node,join_else);
                                /* link the third instlist to the end of the first join node */
                                top_node = append_inst(top_node,(mem_entry_t*)$13);
                                /* link the second join node to the end of the third instlist */
                                top_node = append_inst(top_node,join_done);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist WHILEBLOCK LPAREN validireg RPAREN LBRACE instlist RBRACE {
                                mem_entry_t *top_node;
                                mem_entry_t *top_branch;
                                mem_entry_t *bottom_branch;
                                mem_entry_t *join_node;
                                char *target;
                                /* generate branch to skip over loop body */
                                top_branch = new_instruction(OP_BEQ); 
                                top_branch->inst->inst_id=RISCV_BEQ; 
                                top_branch->inst->rsrc1=$4; 
                                top_branch->inst->rsrc2=0; // compare to $r0
                                /* generate and name join node after loop body */
                                join_node = new_mem_entry(ENTRY_JOIN_NODE,0);
                                join_node->name = internal_name();
                                symtab_new(join_node->name,SYMTAB_MEM);
                                /* set the branch target to the join node name */
                                top_branch->inst->target_name = strdup(join_node->name);
                                /* generate branch that will target the top of loop body */
                                bottom_branch = new_instruction(OP_BNE); 
                                bottom_branch->inst->inst_id=RISCV_BNE;
                                bottom_branch->inst->funct3=F3_BNE;
                                bottom_branch->inst->rsrc1=$4; 
                                bottom_branch->inst->rsrc2=0; // compare to $r0
                                /* check the name of the top of the loop body -- create name if necessary */
                                if ($7){
                                    /* find the first non-definition */
                                    mem_entry_t *working = (mem_entry_t*)$7;
                                    while (working){
                                        if (working->type != ENTRY_DEFINITION)
                                            break;
                                        working = working->next;
                                    }
                                    if (working){
                                        /* check for a name -- if none, then name it */
                                        if (!working->name){
                                            working->name = internal_name();
                                            symtab_new(working->name,SYMTAB_MEM);
                                        }
                                        target = working->name;
                                    }
                                    else {
                                        /* loop body was only defs, bottom branch should target itself */
                                        bottom_branch->name = internal_name();
                                        symtab_new(bottom_branch->name,SYMTAB_MEM);
                                        target = bottom_branch->name;
                                    }
                                }
                                else {
                                    /* empty loop body target should be branch itself */
                                    bottom_branch->name = internal_name();
                                    symtab_new(bottom_branch->name,SYMTAB_MEM);
                                    target = bottom_branch->name;
                                }
                                /* set the bottom branch target to the top of the loop body */
                                bottom_branch->inst->target_name = strdup(target);
                                /* link the branch to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,top_branch);
                                /* link the second instlist (loop body) to the end of the branch */
                                top_node = append_inst(top_node,(mem_entry_t*)$7);
                                /* link the bottom branch to the end of the loop body */
                                top_node = append_inst(top_node,bottom_branch);
                                /* link the join node to the end of the jump */
                                top_node = append_inst(top_node,join_node);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist LABEL COLON WHILEBLOCK LPAREN validireg RPAREN LBRACE instlist RBRACE {
                                mem_entry_t *top_node;
                                mem_entry_t *top_branch;
                                mem_entry_t *bottom_branch;
                                mem_entry_t *join_node;
                                char *target;
                                /* generate branch to skip over loop body */
                                top_branch = new_instruction(OP_BEQ); 
                                top_branch->inst->inst_id=RISCV_BEQ; 
                                top_branch->inst->rsrc1=$6; 
                                top_branch->inst->rsrc2=0; // compare to $r0
                                /* name the branch */
                                top_branch->name = strdup($2);
                                symtab_new(top_branch->name,SYMTAB_MEM);
                                /* generate and name join node after loop body */
                                join_node = new_mem_entry(ENTRY_JOIN_NODE,0);
                                join_node->name = internal_name();
                                symtab_new(join_node->name,SYMTAB_MEM);
                                /* set the branch target to the join node name */
                                top_branch->inst->target_name = strdup(join_node->name);
                                /* generate branch that will target the top of loop body */
                                bottom_branch = new_instruction(OP_BNE); 
                                bottom_branch->inst->inst_id=RISCV_BNE;
                                bottom_branch->inst->funct3=F3_BNE;
                                bottom_branch->inst->rsrc1=$6; 
                                bottom_branch->inst->rsrc2=0; // compare to $r0
                                /* check the name of the top of the loop body -- create name if necessary */
                                if ($9){
                                    /* find the first non-definition */
                                    mem_entry_t *working = (mem_entry_t*)$9;
                                    while (working){
                                        if (working->type != ENTRY_DEFINITION)
                                            break;
                                        working = working->next;
                                    }
                                    if (working){
                                        /* check for a name -- if none, then name it */
                                        if (!working->name){
                                            working->name = internal_name();
                                            symtab_new(working->name,SYMTAB_MEM);
                                        }
                                        target = working->name;
                                    }
                                    else {
                                        /* loop body was only defs, bottom branch should target itself */
                                        bottom_branch->name = internal_name();
                                        symtab_new(bottom_branch->name,SYMTAB_MEM);
                                        target = bottom_branch->name;
                                    }
                                }
                                else {
                                    /* empty loop body target should be branch itself */
                                    bottom_branch->name = internal_name();
                                    symtab_new(bottom_branch->name,SYMTAB_MEM);
                                    target = bottom_branch->name;
                                }
                                /* set the bottom branch target to the top of the loop body */
                                bottom_branch->inst->target_name = strdup(target);
                                /* link the branch to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,top_branch);
                                /* link the second instlist (loop body) to the end of the branch */
                                top_node = append_inst(top_node,(mem_entry_t*)$9);
                                /* link the bottom branch to the end of the loop body */
                                top_node = append_inst(top_node,bottom_branch);
                                /* link the join node to the end of the jump */
                                top_node = append_inst(top_node,join_node);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist DOBLOCK LBRACE instlist RBRACE WHILEBLOCK LPAREN validireg RPAREN { 
                                mem_entry_t *top_node;
                                mem_entry_t *branch;
                                char *target;
                                /* generate and branch to restart loop body */
                                branch = new_instruction(OP_BNE); 
                                branch->inst->inst_id=RISCV_BNE;
                                branch->inst->funct3=F3_BNE;
                                branch->inst->rsrc1=$8; 
                                branch->inst->rsrc2=0; // compare to $r0
                                /* check the name of the top of the loop body -- create name if necessary */
                                if ($4){
                                    /* find the first non-definition */
                                    mem_entry_t *working = (mem_entry_t*)$4;
                                    while (working){
                                        if (working->type != ENTRY_DEFINITION)
                                            break;
                                        working = working->next;
                                    }
                                    if (working){
                                        /* check for a name -- if none, then name it */
                                        if (!working->name){
                                            working->name = internal_name();
                                            symtab_new(working->name,SYMTAB_MEM);
                                        }
                                        target = working->name;
                                    }
                                    else {
                                        /* loop body was only defs, branch should target itself */
                                        branch->name = internal_name();
                                        symtab_new(branch->name,SYMTAB_MEM);
                                        target = branch->name;
                                    }
                                }
                                else {
                                    /* empty loop body target should be branch itself */
                                    branch->name = internal_name();
                                    symtab_new(branch->name,SYMTAB_MEM);
                                    target = branch->name;
                                }
                                /* set the branch target to the top of the loop body */
                                branch->inst->target_name = strdup(target);
                                /* link the second instlist (loop body) to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,(mem_entry_t*)$4);
                                /* link the branch to the end of the loop body */
                                top_node = append_inst(top_node,branch);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist LABEL COLON DOBLOCK LBRACE instlist RBRACE WHILEBLOCK LPAREN validireg RPAREN { 
                                mem_entry_t *top_node;
                                mem_entry_t *branch;
                                char *target;
                                /* generate and branch to restart loop body */
                                branch = new_instruction(OP_BNE); 
                                branch->inst->inst_id=RISCV_BNE;
                                branch->inst->funct3=F3_BNE;
                                branch->inst->rsrc1=$10; 
                                branch->inst->rsrc2=0; // compare to $r0
                                /* check the name of the top of the loop body -- create name if necessary */
                                if ($6){
                                    /* find the first non-definition */
                                    mem_entry_t *working = (mem_entry_t*)$6;
                                    while (working){
                                        if (working->type != ENTRY_DEFINITION)
                                            break;
                                        working = working->next;
                                    }
                                    if (working){
                                        /* check for a name -- if none, then name it */
                                        if (!working->name){
                                            working->name = strdup($2);
                                            symtab_new(working->name,SYMTAB_MEM);
                                        }
                                        else {
                                            /* this inst will have two names */
                                            symtab_new($2,SYMTAB_MEM);
                                        }
                                        target = working->name;
                                    }
                                    else {
                                        /* loop body was only defs, branch should target itself */
                                        branch->name = strdup($2);
                                        symtab_new(branch->name,SYMTAB_MEM);
                                        target = branch->name;
                                    }
                                }
                                else {
                                    /* empty loop body target should be branch itself */
                                    branch->name = strdup($2);
                                    symtab_new(branch->name,SYMTAB_MEM);
                                    target = branch->name;
                                }
                                /* set the branch target to the top of the loop body */
                                branch->inst->target_name = strdup(target);
                                /* link the second instlist (loop body) to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,(mem_entry_t*)$6);
                                /* link the branch to the end of the loop body */
                                top_node = append_inst(top_node,branch);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist UNTILBLOCK LPAREN validireg RPAREN LBRACE instlist RBRACE {
                                mem_entry_t *top_node;
                                mem_entry_t *top_branch;
                                mem_entry_t *bottom_branch;
                                mem_entry_t *join_node;
                                char *target;
                                /* generate branch to skip over loop body */
                                top_branch = new_instruction(OP_BNE);
                                top_branch->inst->inst_id=RISCV_BNE; 
                                top_branch->inst->funct3=F3_BNE;
                                top_branch->inst->rsrc1=$4;
                                top_branch->inst->rsrc2=0; // compare to $r0
                                /* generate and name join node after loop body */
                                join_node = new_mem_entry(ENTRY_JOIN_NODE,0);
                                join_node->name = internal_name();
                                symtab_new(join_node->name,SYMTAB_MEM);
                                /* set the branch target to the join node name */
                                top_branch->inst->target_name = strdup(join_node->name);
                                /* generate branch that will target the top of loop body */
                                bottom_branch = new_instruction(OP_BEQ);
                                bottom_branch->inst->inst_id=RISCV_BEQ; 
                                bottom_branch->inst->rsrc1=$4;
                                bottom_branch->inst->rsrc2=0; // compare to $r0
                                /* check the name of the top of the loop body -- create name if necessary */
                                if ($7){
                                    /* find the first non-definition */
                                    mem_entry_t *working = (mem_entry_t*)$7;
                                    while (working){
                                        if (working->type != ENTRY_DEFINITION)
                                            break;
                                        working = working->next;
                                    }
                                    if (working){
                                        /* check for a name -- if none, then name it */
                                        if (!working->name){
                                            working->name = internal_name();
                                            symtab_new(working->name,SYMTAB_MEM);
                                        }
                                        target = working->name;
                                    }
                                    else {
                                        /* loop body was only defs, bottom branch should target itself */
                                        bottom_branch->name = internal_name();
                                        symtab_new(bottom_branch->name,SYMTAB_MEM);
                                        target = bottom_branch->name;
                                    }
                                }
                                else {
                                    /* empty loop body target should be branch itself */
                                    bottom_branch->name = internal_name();
                                    symtab_new(bottom_branch->name,SYMTAB_MEM);
                                    target = bottom_branch->name;
                                }
                                /* set the bottom branch target to the top of the loop body */
                                bottom_branch->inst->target_name = strdup(target);
                                /* link the branch to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,top_branch);
                                /* link the second instlist (loop body) to the end of the branch */
                                top_node = append_inst(top_node,(mem_entry_t*)$7);
                                /* link the bottom branch to the end of the loop body */
                                top_node = append_inst(top_node,bottom_branch);
                                /* link the join node to the end of the jump */
                                top_node = append_inst(top_node,join_node);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist LABEL COLON UNTILBLOCK LPAREN validireg RPAREN LBRACE instlist RBRACE {
                                mem_entry_t *top_node;
                                mem_entry_t *top_branch;
                                mem_entry_t *bottom_branch;
                                mem_entry_t *join_node;
                                char *target;
                                /* generate branch to skip over loop body */
                                top_branch = new_instruction(OP_BNE);
                                top_branch->inst->inst_id=RISCV_BNE; 
                                top_branch->inst->funct3=F3_BNE;
                                top_branch->inst->rsrc1=$6;
                                top_branch->inst->rsrc2=0; // compare to $r0
                                /* name the branch */
                                top_branch->name = strdup($2);
                                symtab_new(top_branch->name,SYMTAB_MEM);
                                /* generate and name join node after loop body */
                                join_node = new_mem_entry(ENTRY_JOIN_NODE,0);
                                join_node->name = internal_name();
                                symtab_new(join_node->name,SYMTAB_MEM);
                                /* set the branch target to the join node name */
                                top_branch->inst->target_name = strdup(join_node->name);
                                /* generate branch that will target the top of loop body */
                                bottom_branch = new_instruction(OP_BEQ);
                                bottom_branch->inst->inst_id=RISCV_BEQ; 
                                bottom_branch->inst->rsrc1=$6;
                                bottom_branch->inst->rsrc2=0; // compare to $r0
                                /* check the name of the top of the loop body -- create name if necessary */
                                if ($9){
                                    /* find the first non-definition */
                                    mem_entry_t *working = (mem_entry_t*)$9;
                                    while (working){
                                        if (working->type != ENTRY_DEFINITION)
                                            break;
                                        working = working->next;
                                    }
                                    if (working){
                                        /* check for a name -- if none, then name it */
                                        if (!working->name){
                                            working->name = internal_name();
                                            symtab_new(working->name,SYMTAB_MEM);
                                        }
                                        target = working->name;
                                    }
                                    else {
                                        /* loop body was only defs, bottom branch should target itself */
                                        bottom_branch->name = internal_name();
                                        symtab_new(bottom_branch->name,SYMTAB_MEM);
                                        target = bottom_branch->name;
                                    }
                                }
                                else {
                                    /* empty loop body target should be branch itself */
                                    bottom_branch->name = internal_name();
                                    symtab_new(bottom_branch->name,SYMTAB_MEM);
                                    target = bottom_branch->name;
                                }
                                /* set the bottom branch target to the top of the loop body */
                                bottom_branch->inst->target_name = strdup(target);
                                /* link the branch to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,top_branch);
                                /* link the second instlist (loop body) to the end of the branch */
                                top_node = append_inst(top_node,(mem_entry_t*)$9);
                                /* link the bottom branch to the end of the loop body */
                                top_node = append_inst(top_node,bottom_branch);
                                /* link the join node to the end of the jump */
                                top_node = append_inst(top_node,join_node);
                                $$=(void*)top_node;
                            }

    /* tested */
    | instlist DOBLOCK LBRACE instlist RBRACE UNTILBLOCK LPAREN validireg RPAREN { 
                                mem_entry_t *top_node;
                                mem_entry_t *branch;
                                char *target;
                                /* generate and branch to restart loop body */
                                branch = new_instruction(OP_BEQ);
                                branch->inst->inst_id=RISCV_BEQ; 
                                branch->inst->rsrc1=$8;
                                branch->inst->rsrc2=0; // compare to $r0
                                /* check the name of the top of the loop body -- create name if necessary */
                                if ($4){
                                    /* find the first non-definition */
                                    mem_entry_t *working = (mem_entry_t*)$4;
                                    while (working){
                                        if (working->type != ENTRY_DEFINITION)
                                            break;
                                        working = working->next;
                                    }
                                    if (working){
                                        /* check for a name -- if none, then name it */
                                        if (!working->name){
                                            working->name = internal_name();
                                            symtab_new(working->name,SYMTAB_MEM);
                                        }
                                        target = working->name;
                                    }
                                    else {
                                        /* loop body was only defs, branch should target itself */
                                        branch->name = internal_name();
                                        symtab_new(branch->name,SYMTAB_MEM);
                                        target = branch->name;
                                    }
                                }
                                else {
                                    /* empty loop body target should be branch itself */
                                    branch->name = internal_name();
                                    symtab_new(branch->name,SYMTAB_MEM);
                                    target = branch->name;
                                }
                                /* set the branch target to the top of the loop body */
                                branch->inst->target_name = strdup(target);
                                /* link the second instlist (loop body) to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,(mem_entry_t*)$4);
                                /* link the branch to the end of the loop body */
                                top_node = append_inst(top_node,branch);
                                $$=(void*)top_node;
                            }
    /* tested */
    | instlist LABEL COLON DOBLOCK LBRACE instlist RBRACE UNTILBLOCK LPAREN validireg RPAREN { 
                                mem_entry_t *top_node;
                                mem_entry_t *branch;
                                char *target;
                                /* generate and branch to restart loop body */
                                branch = new_instruction(OP_BEQ);
                                branch->inst->inst_id=RISCV_BEQ; 
                                branch->inst->rsrc1=$10;
                                branch->inst->rsrc2=0; // compare to $r0
                                /* check the name of the top of the loop body -- create name if necessary */
                                if ($6){
                                    /* find the first non-definition */
                                    mem_entry_t *working = (mem_entry_t*)$6;
                                    while (working){
                                        if (working->type != ENTRY_DEFINITION)
                                            break;
                                        working = working->next;
                                    }
                                    if (working){
                                        /* check for a name -- if none, then name it */
                                        if (!working->name){
                                            working->name = strdup($2);
                                            symtab_new(working->name,SYMTAB_MEM);
                                        }
                                        else {
                                            /* this inst will have two names */
                                            symtab_new($2,SYMTAB_MEM);
                                        }
                                        target = working->name;
                                    }
                                    else {
                                        /* loop body was only defs, branch should target itself */
                                        branch->name = strdup($2);
                                        symtab_new(branch->name,SYMTAB_MEM);
                                        target = branch->name;
                                    }
                                }
                                else {
                                    /* empty loop body target should be branch itself */
                                    branch->name = strdup($2);
                                    symtab_new(branch->name,SYMTAB_MEM);
                                    target = branch->name;
                                }
                                /* set the branch target to the top of the loop body */
                                branch->inst->target_name = strdup(target);
                                /* link the second instlist (loop body) to the end of the first instlist */
                                top_node = append_inst((mem_entry_t*)$1,(mem_entry_t*)$6);
                                /* link the branch to the end of the loop body */
                                top_node = append_inst(top_node,branch);
                                $$=(void*)top_node;
                            }
    ;

/* TODO check the ranges for immediates and offsets */
/* TODO handle GT, LTE, GTE, EQ, NEQ, etc. */

    /* tested */
inst: INST_LUI validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_LUI);
                                entry->inst->inst_id=RISCV_LUI;
                                entry->inst->rdst=$2;
                                entry->inst->imm=$3;
                                entry->status = ENTRY_COMPLETE;
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN ADDRESSOF LABEL {
                                mem_entry_t *top;
                                mem_entry_t *upper_entry=new_instruction(OP_LUI); 
                                upper_entry->inst->inst_id=RISCV_LUI;
                                mem_entry_t *lower_entry=new_instruction(OP_ORI);
                                lower_entry->inst->inst_id=RISCV_ORI;
                                lower_entry->inst->funct3 = F3_ORI;
                                upper_entry->inst->rdst=$1;
                                upper_entry->inst->target_name = strdup($4);
                                lower_entry->inst->rdst=$1;
                                lower_entry->inst->rsrc1=$1;
                                lower_entry->inst->target_name = strdup($4);
                                top = append_inst(upper_entry,lower_entry);
                                $$=(void*)top;
                            }
    /* TODO support for 64 bit instructions*/
    | validireg ASSIGN IIMM {
                                mem_entry_t *entry=NULL; 
                                if ($3 & 0xfffff000){
                                    /* upper two bytes */
                                    entry=new_instruction(OP_LUI);
                                    entry->inst->inst_id=RISCV_LUI;
                                    entry->inst->rdst=$1;
                                    entry->inst->imm=($3>>12); 
                                    entry->status = ENTRY_COMPLETE;
                                    if ($3 & 0x00000fff){ /* only do lower two bytes if needed */
                                        mem_entry_t *entry2=new_instruction(OP_ORI);
                                        entry2->inst->inst_id=RISCV_ORI;
                                        entry2->inst->funct3 = F3_ORI;
                                        entry2->inst->rdst=$1;
                                        entry2->inst->rsrc1=$1;
                                        entry2->inst->imm=($3&0xfff);
                                        entry2->status = ENTRY_COMPLETE;
                                        entry=append_inst(entry,entry2);
                                    }
                                }
                                else{
                                    /* only an ORI */
                                    entry=new_instruction(OP_ORI);
                                    entry->inst->inst_id=RISCV_ORI;
                                    entry->inst->funct3 = F3_ORI;
                                    entry->inst->rdst=$1;
                                    entry->inst->rsrc1=0; /* just addi to $r0 */
                                    entry->inst->imm=$3;
                                    entry->status = ENTRY_COMPLETE;
                                }
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_AUIPC validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_AUIPC);
                                entry->inst->inst_id=RISCV_AUIPC;
                                entry->inst->rdst=$2;
                                entry->inst->imm=$3;
                                entry->status = ENTRY_COMPLETE;
                                $$=(void*)entry;
                            }
    /* tested */               
    | INST_JAL validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_JAL); 
                                entry->inst->inst_id=RISCV_JAL;
                                entry->inst->rdst=$2;
                                entry->inst->target_address=$3;
                                entry->status = ENTRY_COMPLETE;
                                $$=(void*)entry;
    }
    /* tested */
    | INST_JAL IIMM          {
                                mem_entry_t *entry=new_instruction(OP_JAL); 
                                entry->inst->inst_id=RISCV_JAL;
                                entry->inst->rdst=0x1; // always this reg
                                entry->inst->target_address=$2;
                                entry->status = ENTRY_COMPLETE;
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_JAL LABEL          {
                                mem_entry_t *entry=new_instruction(OP_JAL); 
                                entry->inst->inst_id=RISCV_JAL;
                                entry->inst->rdst=0x1; // always this reg
                                entry->inst->target_name=strdup($2);
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_JALR validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_JALR);
                                entry->inst->inst_id=RISCV_JALR;
                                entry->inst->rdst=$2;
                                entry->inst->rsrc1=$3;
                                entry->inst->imm=$4;
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BEQ validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_BEQ);
                                entry->inst->inst_id=RISCV_BEQ;
                                entry->inst->rsrc1=$2;
                                entry->inst->rsrc2=$3; 
                                entry->inst->imm=$4;
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BEQ validireg validireg LABEL {
                                mem_entry_t *entry=new_instruction(OP_BEQ); 
                                entry->inst->inst_id=RISCV_BEQ;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->target_name=strdup($4); 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BNE validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_BNE);
                                entry->inst->inst_id=RISCV_BNE;
                                entry->inst->funct3=F3_BNE;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BNE validireg validireg LABEL {
                                mem_entry_t *entry=new_instruction(OP_BNE); 
                                entry->inst->inst_id=RISCV_BNE;
                                entry->inst->funct3=F3_BNE;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->target_name=strdup($4); 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BLT validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_BLT);
                                entry->inst->inst_id=RISCV_BLT;
                                entry->inst->funct3=F3_BLT;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BLT validireg validireg LABEL {
                                mem_entry_t *entry=new_instruction(OP_BLT); 
                                entry->inst->inst_id=RISCV_BLT;
                                entry->inst->funct3=F3_BLT;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->target_name=strdup($4); 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BGE validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_BGE);
                                entry->inst->inst_id=RISCV_BGE;
                                entry->inst->funct3=F3_BGE;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BGE validireg validireg LABEL {
                                mem_entry_t *entry=new_instruction(OP_BGE); 
                                entry->inst->inst_id=RISCV_BGE;
                                entry->inst->funct3=F3_BGE;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->target_name=strdup($4); 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BLTU validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_BLTU);
                                entry->inst->inst_id=RISCV_BLTU;
                                entry->inst->funct3=F3_BLTU;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BLTU validireg validireg LABEL {
                                mem_entry_t *entry=new_instruction(OP_BLTU); 
                                entry->inst->inst_id=RISCV_BLTU;
                                entry->inst->funct3=F3_BLTU;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->target_name=strdup($4); 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BGEU validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_BGEU);
                                entry->inst->inst_id=RISCV_BGEU;
                                entry->inst->funct3=F3_BGEU;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_BGEU validireg validireg LABEL {
                                mem_entry_t *entry=new_instruction(OP_BGEU); 
                                entry->inst->inst_id=RISCV_BGEU;
                                entry->inst->funct3=F3_BGEU;
                                entry->inst->rsrc1=$2; 
                                entry->inst->rsrc2=$3; 
                                entry->inst->target_name=strdup($4); 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_LB validireg IIMM LBRACKET validireg RBRACKET {
                                mem_entry_t *entry=new_instruction(OP_LB); 
                                entry->inst->inst_id=RISCV_LB;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$5; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_LH validireg IIMM LBRACKET validireg RBRACKET {
                                mem_entry_t *entry=new_instruction(OP_LH); 
                                entry->inst->inst_id=RISCV_LH;
                                entry->inst->rdst=$2; 
                                entry->inst->funct3=F3_LH;
                                entry->inst->rsrc1=$5; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_LW validireg IIMM LBRACKET validireg RBRACKET {
                                mem_entry_t *entry=new_instruction(OP_LW); 
                                entry->inst->inst_id=RISCV_LW;
                                entry->inst->rdst=$2; 
                                entry->inst->funct3=F3_LW;
                                entry->inst->rsrc1=$5; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_LBU validireg IIMM LBRACKET validireg RBRACKET {
                                mem_entry_t *entry=new_instruction(OP_LBU); 
                                entry->inst->inst_id=RISCV_LBU;
                                entry->inst->rdst=$2;
                                entry->inst->funct3=F3_LBU;
                                entry->inst->rsrc1=$5; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_LHU validireg IIMM LBRACKET validireg RBRACKET {
                                mem_entry_t *entry=new_instruction(OP_LHU); 
                                entry->inst->inst_id=RISCV_LHU;
                                entry->inst->rdst=$2; 
                                entry->inst->funct3=F3_LHU;
                                entry->inst->rsrc1=$5; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* TODO */
    | INST_SB validireg IIMM LBRACKET validireg RBRACKET {
                                mem_entry_t *entry=new_instruction(OP_SB);
                                entry->inst->inst_id=RISCV_SB;
                                entry->inst->funct3=F3_SB;
                                entry->inst->rsrc1=$5; 
                                entry->inst->rsrc2=$2; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* TODO */
    | INST_SH validireg IIMM LBRACKET validireg RBRACKET {
                                mem_entry_t *entry=new_instruction(OP_SH);
                                entry->inst->inst_id=RISCV_SH;
                                entry->inst->funct3=F3_SH;
                                entry->inst->rsrc1=$5; 
                                entry->inst->rsrc2=$2; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* TODO */
    | INST_SW validireg IIMM LBRACKET validireg RBRACKET {
                                mem_entry_t *entry=new_instruction(OP_SW);
                                entry->inst->inst_id=RISCV_SW;
                                entry->inst->funct3=F3_SW;
                                entry->inst->rsrc1=$5; 
                                entry->inst->rsrc2=$2; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* TODO */
    | validireg ASSIGN validireg {
                                mem_entry_t *entry=new_instruction(OP_ADDI); 
                                entry->inst->inst_id=RISCV_ADDI;
                                entry->inst->funct3=F3_ADDI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->imm=0; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_ADDI validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_ADDI);
                                entry->inst->inst_id=RISCV_ADDI;
                                entry->inst->funct3=F3_ADDI;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg PLUS IIMM {
                                mem_entry_t *entry=new_instruction(OP_ADDI); 
                                entry->inst->inst_id=RISCV_ADDI;
                                entry->inst->funct3=F3_ADDI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->imm=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg MINUS IIMM {
                                mem_entry_t *entry=new_instruction(OP_ADDI); 
                                entry->inst->inst_id=RISCV_ADDI;
                                entry->inst->funct3=F3_ADDI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->imm=-($5); 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN IIMM PLUS validireg {
                                mem_entry_t *entry=new_instruction(OP_ADDI); 
                                entry->inst->inst_id=RISCV_ADDI;
                                entry->inst->funct3=F3_ADDI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$5; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SLTI validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_SLTI);
                                entry->inst->inst_id=RISCV_SLTI;
                                entry->inst->funct3=F3_SLTI; 
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg LT IIMM {
                                mem_entry_t *entry=new_instruction(OP_SLTI);
                                entry->inst->inst_id=RISCV_SLTI;
                                entry->inst->funct3=F3_SLTI; 
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->imm=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN IIMM GT validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator > not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg GT validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator > not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg GT IIMM {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator > not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN IIMM LT validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("this version of operator < not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg LTE validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator <= not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg LTE IIMM {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator <= not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg GTE validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator <= not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg GTE IIMM {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator <= not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg EQ validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator == not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg EQ IIMM {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator == not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN IIMM EQ validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator == not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg NEQ validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator != not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN validireg NEQ IIMM {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator != not yet implemented"); 
                                $$=(void*)entry;
                            }
    | validireg ASSIGN IIMM NEQ validireg {
                                mem_entry_t *entry=NULL; 
                                yyerror("operator != not yet implemented"); 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SLTIU validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_SLTIU); 
                                entry->inst->inst_id=RISCV_SLTIU;
                                entry->inst->rdst=$2; 
                                entry->inst->funct3=F3_SLTIU;
                                entry->inst->rsrc1=$3; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_XORI validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_XORI); 
                                entry->inst->inst_id=RISCV_XORI;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_XORI;
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg XOR IIMM {
                                mem_entry_t *entry=new_instruction(OP_XORI); 
                                entry->inst->inst_id=RISCV_XORI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_XORI;
                                entry->inst->imm=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN IIMM XOR validireg {
                                mem_entry_t *entry=new_instruction(OP_XORI); 
                                entry->inst->inst_id=RISCV_XORI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$5; 
                                entry->inst->funct3=F3_XORI;
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN NOT validireg {
                                mem_entry_t *entry=new_instruction(OP_XORI); 
                                entry->inst->inst_id=RISCV_XORI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$4; 
                                entry->inst->funct3=F3_XORI;
                                entry->inst->imm=-1;
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_ORI validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_ORI); 
                                entry->inst->inst_id=RISCV_ORI;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_ORI;
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg OR IIMM {
                                mem_entry_t *entry=new_instruction(OP_ORI); 
                                entry->inst->inst_id=RISCV_ORI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_ORI;
                                entry->inst->imm=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN IIMM OR validireg {
                                mem_entry_t *entry=new_instruction(OP_ORI); 
                                entry->inst->inst_id=RISCV_ORI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$5;
                                entry->inst->funct3=F3_ORI; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_ANDI validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_ANDI); 
                                entry->inst->inst_id=RISCV_ANDI;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_ANDI; 
                                entry->inst->imm=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg AND IIMM {
                                mem_entry_t *entry=new_instruction(OP_ANDI); 
                                entry->inst->inst_id=RISCV_ANDI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_ANDI; 
                                entry->inst->imm=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN IIMM AND validireg {
                                mem_entry_t *entry=new_instruction(OP_ANDI); 
                                entry->inst->inst_id=RISCV_ANDI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$5; 
                                entry->inst->funct3=F3_ANDI; 
                                entry->inst->imm=$3; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SLLI validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_SLLI); 
                                entry->inst->inst_id=RISCV_SLLI;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SLLI; 
                                entry->inst->funct7=F7_SLLI;
                                entry->inst->rsrc2=$4; //shamt 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg LSHIFT IIMM {
                                mem_entry_t *entry=new_instruction(OP_SLLI); 
                                entry->inst->inst_id=RISCV_SLLI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SLLI; 
                                entry->inst->funct7=F7_SLLI;
                                entry->inst->rsrc2=$5; //shamt 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SRLI validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_SRLI); 
                                entry->inst->inst_id=RISCV_SRLI;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SRLI; 
                                entry->inst->funct7=F7_SRLI;
                                entry->inst->rsrc2=$4; //shamt
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg RSHIFT IIMM {
                                mem_entry_t *entry=new_instruction(OP_SRLI); 
                                entry->inst->inst_id=RISCV_SRLI;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3;
                                entry->inst->funct3=F3_SRLI; 
                                entry->inst->funct7=F7_SRLI; 
                                entry->inst->rsrc2=$5; //shamt
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SRAI validireg validireg IIMM {
                                mem_entry_t *entry=new_instruction(OP_SRAI); 
                                entry->inst->inst_id=RISCV_SRAI;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SRAI; 
                                entry->inst->funct7=F7_SRAI;
                                entry->inst->rsrc2=$4; //shamt
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_ADD validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_ADD); 
                                entry->inst->inst_id=RISCV_ADD;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg PLUS validireg {
                                mem_entry_t *entry=new_instruction(OP_ADD); 
                                entry->inst->inst_id=RISCV_ADD;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->rsrc2=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SUB validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_ADD); 
                                entry->inst->inst_id=RISCV_SUB;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SUB;
                                entry->inst->funct7=F7_SUB;  
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg MINUS validireg {
                                mem_entry_t *entry=new_instruction(OP_SUB); 
                                entry->inst->inst_id=RISCV_SUB;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SUB; 
                                entry->inst->funct7=F7_SUB;
                                entry->inst->rsrc2=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN MINUS validireg {
                                mem_entry_t *entry=new_instruction(OP_SUB); 
                                entry->inst->inst_id=RISCV_SUB;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=0; 
                                entry->inst->funct3=F3_SUB; 
                                entry->inst->funct7=F7_SUB;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_MUL validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_MUL); 
                                entry->inst->inst_id=RISCV_MUL;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->rsrc2=$4;
                                entry->inst->funct7=F7_MUL;
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg MULTIPLY validireg {
                                mem_entry_t *entry=new_instruction(OP_MUL); 
                                entry->inst->inst_id=RISCV_MUL;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->rsrc2=$5; 
                                entry->inst->funct7=F7_MUL; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_DIV validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_DIV); 
                                entry->inst->inst_id=RISCV_DIV;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->rsrc2=$4;
                                entry->inst->funct7=F7_DIV; 
                                entry->inst->funct3=F3_DIV; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg DIVIDE validireg {
                                mem_entry_t *entry=new_instruction(OP_DIV); 
                                entry->inst->inst_id=RISCV_DIV;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->rsrc2=$5; 
                                entry->inst->funct7=F7_DIV;
                                entry->inst->funct3=F3_DIV; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SLL validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_SLL); 
                                entry->inst->inst_id=RISCV_SLL;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SLL; 
                                entry->inst->funct7=F7_SLL;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SLT validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_SLT); 
                                entry->inst->inst_id=RISCV_SLT;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SLT; 
                                entry->inst->funct7=F7_SLT;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg LT validireg {
                                mem_entry_t *entry=new_instruction(OP_SLT); 
                                entry->inst->inst_id=RISCV_SLT;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SLT;
                                entry->inst->funct7=F7_SLT;
                                entry->inst->rsrc2=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SLTU validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_SLTU); 
                                entry->inst->inst_id=RISCV_SLTU;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SLTU; 
                                entry->inst->funct7=F7_SLTU;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_XOR validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_XOR); 
                                entry->inst->inst_id=RISCV_XOR;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_XOR; 
                                entry->inst->funct7=F7_XOR;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg XOR validireg {
                                mem_entry_t *entry=new_instruction(OP_XOR); 
                                entry->inst->inst_id=RISCV_XOR;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_XOR; 
                                entry->inst->funct7=F7_XOR;
                                entry->inst->rsrc2=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SRL validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_SRL); 
                                entry->inst->inst_id=RISCV_SRL;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SRL; 
                                entry->inst->funct7=F7_SRL;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_SRA validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_SRA); 
                                entry->inst->inst_id=RISCV_SRA;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_SRA; 
                                entry->inst->funct7=F7_SRA;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_OR validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_OR); 
                                entry->inst->inst_id=RISCV_OR;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_OR; 
                                entry->inst->funct7=F7_OR;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg OR validireg {
                                mem_entry_t *entry=new_instruction(OP_OR); 
                                entry->inst->inst_id=RISCV_OR;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_OR; 
                                entry->inst->funct7=F7_OR;
                                entry->inst->rsrc2=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_AND validireg validireg validireg {
                                mem_entry_t *entry=new_instruction(OP_AND); 
                                entry->inst->inst_id=RISCV_AND;
                                entry->inst->rdst=$2; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_AND; 
                                entry->inst->funct7=F7_AND;
                                entry->inst->rsrc2=$4; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | validireg ASSIGN validireg AND validireg {
                                mem_entry_t *entry=new_instruction(OP_AND); 
                                entry->inst->inst_id=RISCV_AND;
                                entry->inst->rdst=$1; 
                                entry->inst->rsrc1=$3; 
                                entry->inst->funct3=F3_AND; 
                                entry->inst->funct7=F7_AND;
                                entry->inst->rsrc2=$5; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    | INST_FENCE {
        mem_entry_t *entry=NULL; 
        yyerror("fence not yet implemented"); 
        $$=(void*)entry;
    }
    | INST_FENCE_I {
        mem_entry_t *entry=NULL; 
        yyerror("fencei not yet implemented"); 
        $$=(void*)entry;
    }
    /* tested */
    | INST_ECALL {
                                mem_entry_t *entry=new_instruction(OP_ECALL); 
                                entry->inst->inst_id=RISCV_ECALL;
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;        
    }
    /* tested */
    | INST_EBREAK {
                                mem_entry_t *entry=new_instruction(OP_EBREAK); 
                                entry->inst->inst_id=RISCV_EBREAK;
                                entry->inst->imm=0x1;
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;        
    }
    | INST_CSRRW validireg validireg validireg {
        mem_entry_t *entry=NULL; 
        yyerror("csrrw not yet implemented"); 
        $$=(void*)entry;
    }
    | INST_CSRRS validireg validireg validireg {
        mem_entry_t *entry=NULL; 
        yyerror("csrrs not yet implemented"); 
        $$=(void*)entry;
    }
    | INST_CSRRC validireg validireg validireg {
        mem_entry_t *entry=NULL; 
        yyerror("csrrc not yet implemented"); 
        $$=(void*)entry;
    }
    | INST_CSRRWI validireg validireg IIMM {
        mem_entry_t *entry=NULL; 
        yyerror("csrrwi not yet implemented"); 
        $$=(void*)entry;
    }
    | INST_CSRRSI validireg validireg IIMM {
        mem_entry_t *entry=NULL; 
        yyerror("csrrsi not yet implemented"); 
        $$=(void*)entry;
    }
    | INST_CSRRCI validireg validireg IIMM {
        mem_entry_t *entry=NULL; 
        yyerror("csrrci not yet implemented"); 
        $$=(void*)entry;
    }
    /* tested */
    | INST_J IIMM             {
                                mem_entry_t *entry=new_instruction(OP_JAL); 
                                entry->inst->inst_id=RISCV_J;
                                entry->inst->rdst=0x0; // always this reg
                                entry->inst->target_address=$2; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_J LABEL            {
                                mem_entry_t *entry=new_instruction(OP_JAL); 
                                entry->inst->inst_id=RISCV_J;
                                entry->inst->rdst=0x0; // always this reg
                                entry->inst->target_name=strdup($2); 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_JR validireg       {
                                mem_entry_t *entry=new_instruction(OP_JALR);
                                entry->inst->inst_id=RISCV_JALR;
                                entry->inst->rdst=0x0;
                                entry->inst->rsrc1=$2;
                                entry->inst->imm=0x0;
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
    }
    /* tested */
    | INST_RET {
                                mem_entry_t *entry=new_instruction(OP_JALR);
                                entry->inst->inst_id=RISCV_RET;
                                entry->inst->rdst=0x0;
                                entry->inst->rsrc1=0x1;
                                entry->inst->imm=0;
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    /* tested */
    | INST_NOP {
                                mem_entry_t *entry=new_instruction(OP_ADDI);
                                entry->inst->inst_id=RISCV_ADDI;
                                entry->inst->funct3=F3_ADDI;
                                entry->inst->rdst=0; 
                                entry->inst->rsrc1=0; 
                                entry->inst->imm=0; 
                                entry->status = ENTRY_COMPLETE; 
                                $$=(void*)entry;
                            }
    ;

validireg : IREG            {
                                if ($1 > 31) {
                                    yyerror("Bad int register number");
                                } 
                                else {
                                    $$ = $1;
                                }
                            }
    | LABEL                 {
                                if ((symtab_lookup($1)!=-1)&&(symtab_type($1)==SYMTAB_IREG)){
                                    $$ = symtab_lookup($1);
                                }
                                else{
                                    char buff[1000];
                                    sprintf(buff,"Label \"%s\" failed, either the label has not "
                                                 "been defined, or the label type is not an integer register.",$1);
                                    yyerror(buff);
                                }
                            }
    ;


validfreg : FREG            {if ($1 > 31) {yyerror("Bad fp register number");} else {$$ = $1;}}
    ;

 /*validfreg : FREG            {if ($1 > 31) {yyerror("Bad fp register number");} else {$$ = $1;}}
    | LABEL                 {
                                if ((symtab_lookup($1)!=-1)&&(symtab_type($1)==SYMTAB_FREG)){
                                    $$ = symtab_lookup($1);
                                }
                                else{
                                    char buff[1000];
                                    sprintf(buff,"Label \"%s\" failed, either the label has not "
                                                 "been defined, or the label type is not a floating-point register.",$1);
                                    yyerror(buff);
                                }
                            }
    ;*/


fill : BYTEFILL IIMM        {mem_entry_t *entry = new_mem_entry(ENTRY_BDATA,1); entry->ivalue=$2&0xff; $$=(void*)entry;}
    | HALFFILL IIMM         {mem_entry_t *entry = new_mem_entry(ENTRY_HDATA,2); entry->ivalue=$2&0xffff; $$=(void*)entry;}
    | WORDFILL IIMM         {mem_entry_t *entry = new_mem_entry(ENTRY_WDATA,4); entry->ivalue=$2&0xffffffff; $$=(void*)entry;}
    | LONGFILL IIMM         {mem_entry_t *entry = new_mem_entry(ENTRY_LDATA,8); entry->ivalue=$2; $$=(void*)entry;}
    | FLOATFILL FIMM        {mem_entry_t *entry = new_mem_entry(ENTRY_FDATA,4); entry->fvalue=(float)$2; $$=(void*)entry;}
    | DOUBLEFILL FIMM       {mem_entry_t *entry = new_mem_entry(ENTRY_DDATA,8); entry->dvalue=$2; $$=(void*)entry;}
    | STRINGZFILL STRING    {
                                char *buff = parse_string($2);
                                mem_entry_t *entry = new_mem_entry(ENTRY_SDATA,strlen(buff)+1); 
                                entry->svalue=buff; 
                                $$=(void*)entry;
                            }
    ;

definition : LABEL COLON validireg {
                                mem_entry_t *entry = new_mem_entry(ENTRY_DEFINITION,0); 
                                symtab_new($1,SYMTAB_IREG);
                                symtab_update($1,$3); 
                                entry->name = strdup($1);
                                $$=(void*)entry;
                            }
    | LABEL COLON validfreg {
                                mem_entry_t *entry = new_mem_entry(ENTRY_DEFINITION,0); 
                                symtab_new($1,SYMTAB_FREG);
                                symtab_update($1,$3); 
                                entry->name = strdup($1);
                                $$=(void*)entry;
                            }
    | LABEL COLON inst      { /* not marked as an ENTRY_DEFINITION -- being an ENTRY_INSTRUCTION over-rides this */
                                symtab_new($1,SYMTAB_MEM);
                                ((mem_entry_t*)$3)->name = strdup($1);
                                $$=$3;
                            }
    | LABEL COLON fill      { /* ditto for ENTRY_xDATA */
                                symtab_new($1,SYMTAB_MEM);
                                ((mem_entry_t*)$3)->name = strdup($1);
                                $$=$3;
                            }
    ;

%%

int yydebug = 1;
extern int yylineno; /* from lexer */
char * current_file;

int main(int argc, char *argv[]){
    int i;
    BOOL valid_input = TRUE;
    int input_file_count = 0;
    char *input_files[100];
    char *file_base = NULL;
    BOOL user_named_output = FALSE;
    BOOL dump_debug = FALSE;
    BOOL elf_mem = FALSE;
    BOOL text_mem = FALSE;
    BOOL bin_mem = FALSE;
    BOOL dump_vers = FALSE;


    for (i=1;i<argc;i++){
        if (argv[i][0] == '-'){
            if (strcmp(argv[i],"-checking") == 0)
                dump_debug = TRUE;
            else if (strcmp(argv[i],"-version") == 0)
                dump_vers = TRUE;
            else if (strcmp(argv[i],"-elf") == 0)
                elf_mem = TRUE;
            else if (strcmp(argv[i],"-text") == 0)
                text_mem = TRUE;
            else if (strcmp(argv[i],"-bin") == 0)
                bin_mem = TRUE;
            else if (strcmp(argv[i],"-out") == 0){
                user_named_output = TRUE;
                if (((i+1)<argc) && (argv[i+1][0] != '-')){
                    file_base = strdup(argv[i+1]);
                    i++;
                }
                else
                    valid_input = FALSE;
            }
            else {
                valid_input = FALSE;
            }
        }
        else {
            input_files[input_file_count++] = strdup(argv[i]);
        }
    }

    if (input_file_count == 0) valid_input = FALSE;
    if (!user_named_output) file_base = strdup("a");

    if (dump_vers){
        fprintf(stderr,"\nDuctTape version %d.%d.%d\n\n",dt_major_vers,dt_minor_vers,dt_patch_vers);
        fprintf(stderr,"Justin Severeid and Elliott Forbes\nUniversity of Wisconsin-La Crosse\n");
        fprintf(stderr,"https://cs.uwlax.edu/~eforbes/dt/\n");
        fprintf(stderr,"Copyright 2020-%d, GNU General Public License, version 3\n\n",dt_year);
    }
    else if (!valid_input){
        fprintf(stderr,"usage: %s [flags] <infile...>\n\n",argv[0]);
        fprintf(stderr,"       -version         Print the dt version number and exit.\n");
        fprintf(stderr,"       -out <outfile>   Output filename will have a base name of <outfile>.\n");
        fprintf(stderr,"                        The default is \"a\" if -out is not used.\n");
        fprintf(stderr,"       -checking        Prints debug info (encodings, addresses, etc) \n");
        fprintf(stderr,"                        for parsed program to stdout.\n");
        fprintf(stderr,"       -elf             Outputs an ELF64 Linux executable. The output\n");
        fprintf(stderr,"                        filename will use a .out extension.\n");
        fprintf(stderr,"       -text            Outputs file to a flat memory image, as an\n");
        fprintf(stderr,"                        ASCII encoded text file. The file extension will be\n");
        fprintf(stderr,"                        .txt.\n");
        fprintf(stderr,"       -bin             Outputs file to a flat memory image, as a\n");
        fprintf(stderr,"                        binary file. The file name will end with a .bin\n");
        fprintf(stderr,"                        extension.\n");
        exit(1);
    }
    else {
        srandom(1);
        for (i=0;i<input_file_count;i++){
            FILE *fd = fopen(input_files[i],"r");
            if (fd){
                current_file = input_files[i];
                yyrestart(fd);
                yylineno = 1;
                yyparse();
            }
            else{
                fprintf(stderr,"Could not open source file: %s\n",input_files[i]);
                exit(1);
            }
            fclose(fd);
        }

        current_file = strdup("<<global>>");
        yylineno = -1;

        check_mem_bounds(); /* makes sure mem() blocks don't have overlapping addresses */
        calculate_offsets(); /* calculate the offset field for any instruction that used a labeled target */
        encode_instructions(); /* do the actual encoding of instructions */

        if(dump_debug){
            dump_pc();
            print_memlist_info();
            dump_symtab();
        }
        if(elf_mem) {
            char *filename = (char*) malloc(strlen(file_base) + strlen(".out"));
            bzero(filename,sizeof(strlen(file_base) + strlen(".out")));
            strcat(filename,file_base);
            strcat(filename,".out");
            write_elf(filename);
        }
        if(text_mem) {
            char *filename = (char*) malloc(strlen(file_base) + strlen(".txt"));
            bzero(filename,sizeof(strlen(file_base) + strlen(".txt")));
            strcat(filename,file_base);
            strcat(filename,".txt");
            write_text(filename);
        }
        if(bin_mem) {
            // only pass the base file name, since binary output 
            // can produce many files, depending on the number of 
            // memblocks
            write_bin(file_base);
        }
    }

    return 0;
}

int yyerror(const char *s){
    fprintf(stderr, "error: %s\n\tfile: %s\n\tline: %d\n", s, current_file, yylineno);
    exit(1);
}
