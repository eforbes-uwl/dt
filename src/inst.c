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
 * functions for encoding the intermediate representation into 
 * machine language instructions
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>

#include <elf.h>

#include "riscvarch.h"
#include "inst.h"
#include "mem.h"
#include "symtab.h"
#include "util.h"

/* look into this again, this probably needs to get re-coded */
void calculate_offsets(){
    memblock_list_t *list = block_list;

    while (list){
        mem_entry_t *working = list->head;
        while (working){
            if ((working->type == ENTRY_INSTRUCTION) && (working->status == ENTRY_INCOMPLETE)){
                char buff[100];
                int64_t target_address = symtab_lookup(working->inst->target_name);
                if (target_address < 0){
                    sprintf(buff,"Symbol table lookup failed on label \"%s\" -- name not found.",
                                 working->inst->target_name);
                    yyerror(buff);
                }
                else if (symtab_type(working->inst->target_name) != SYMTAB_MEM) {
                    sprintf(buff,"Symbol table lookup failed on label \"%s\" --"
                                 " label refers to a register.",
                                 working->inst->target_name);
                    yyerror(buff);
                }
                else {
                    if (working->inst->inst_id == RISCV_JAL || working->inst->inst_id == RISCV_J){
                        working->inst->imm = (target_address - working->address);
                        working->status = ENTRY_COMPLETE;
                    }
                    else if ((working->inst->inst_id == RISCV_BEQ) ||
                             (working->inst->inst_id == RISCV_BNE) ||
                             (working->inst->inst_id == RISCV_BLT) ||
                             (working->inst->inst_id == RISCV_BGE) ||
                             (working->inst->inst_id == RISCV_BLTU) ||
                             (working->inst->inst_id == RISCV_BGEU)){
                        working->inst->imm = (target_address - working->address) & 0x1fff;
                        working->status = ENTRY_COMPLETE;
                    }
                    else if (working->inst->inst_id == RISCV_LUI){
                        /* from the address-of operator */
                        working->inst->imm = (((uint64_t)(target_address+sizeof(Elf64_Ehdr)+sizeof(Elf64_Phdr)) >> 12)) & 0xfffff; // TODO need to fix this header size nonsense
                        working->status = ENTRY_COMPLETE;
                    }
                    else if (working->inst->inst_id == RISCV_ORI){
                        /* from the address-of operator */
                        working->inst->imm = (target_address+sizeof(Elf64_Ehdr)+sizeof(Elf64_Phdr)) & 0xfff; // TODO need to fix this header size nonsense
                        working->status = ENTRY_COMPLETE;
                    }
                    else {

                        sprintf(buff,"Unexpected incomplete instruction at address 0x%12" PRIx64 ", id: %d",
                                     working->address, working->inst->inst_id);
                        yyerror(buff);
                    }
                }
            }
            working = working->next;
        }
        list = list->next;
    }
}

void encode_instructions(){
    memblock_list_t *list = block_list;

    while (list){
        mem_entry_t *working = list->head;
        while (working){
            if (working->type == ENTRY_INSTRUCTION){
                working->encoding = encode_instruction(working->inst);
            }
            working = working->next;
        }
        list = list->next;
    }
}

uint32_t encode_instruction(instruction_t *inst){
    uint32_t encoding = 0;
    switch(inst->inst_id) {
        case RISCV_LUI:
            encoding = encode_u_type(inst);
            break;
        case RISCV_AUIPC:
            encoding = encode_u_type(inst);
            break;
        case RISCV_JAL:
            encoding = encode_j_type(inst);
            break;
        case RISCV_JALR:
            encoding = encode_i_type(inst);
            break;
        case RISCV_BEQ:
            encoding = encode_b_type(inst);
            break;
        case RISCV_BNE:
            encoding = encode_b_type(inst);
            break;
        case RISCV_BLT:
            encoding = encode_b_type(inst);
            break;
        case RISCV_BGE:
            encoding = encode_b_type(inst);
            break;
        case RISCV_BLTU:
            encoding = encode_b_type(inst);
            break;
        case RISCV_BGEU:
            encoding = encode_b_type(inst);
            break;
        case RISCV_LB:
            encoding = encode_i_type(inst);
            break;
        case RISCV_LH:
            encoding = encode_i_type(inst);
            break;
        case RISCV_LW:
            encoding = encode_i_type(inst);
            break;
        case RISCV_LBU:
            encoding = encode_i_type(inst);
            break;
        case RISCV_LHU:
            encoding = encode_i_type(inst);
            break;
        case RISCV_SB:
            encoding = encode_s_type(inst);
            break;
        case RISCV_SH:
            encoding = encode_s_type(inst);
            break;
        case RISCV_SW:
            encoding = encode_s_type(inst);
            break;
        case RISCV_ADDI:
            encoding = encode_i_type(inst);
            break;
        case RISCV_SLTI:
            encoding = encode_i_type(inst);
            break;
        case RISCV_SLTIU:
            encoding = encode_i_type(inst);
            break;
        case RISCV_XORI:
            encoding = encode_i_type(inst);
            break;
        case RISCV_ORI:
            encoding = encode_i_type(inst);
            break;
        case RISCV_ANDI:
            encoding = encode_i_type(inst);
            break;
        case RISCV_SLLI:
            encoding = encode_r_type(inst);
            //rsrc2 is shamt
            break;        
        case RISCV_SRLI:
            encoding = encode_r_type(inst);
            //rsrc2 is shamt
            break;        
        case RISCV_SRAI:
            encoding = encode_r_type(inst);
            //rsrc2 is shamt
            break;        
        case RISCV_ADD:
            encoding = encode_r_type(inst);
            break;
        case RISCV_SUB:
            encoding = encode_r_type(inst);
            break;
        case RISCV_MUL:
            encoding = encode_r_type(inst);
            break;
        case RISCV_DIV:
            encoding = encode_r_type(inst);
            break;
        case RISCV_SLL:
            encoding = encode_r_type(inst);
            break;
        case RISCV_SLT:
            encoding = encode_r_type(inst);
            break;
        case RISCV_SLTU:
            encoding = encode_r_type(inst);
            break;
        case RISCV_XOR:
            encoding = encode_r_type(inst);
            break;
        case RISCV_SRL:
            encoding = encode_r_type(inst);
            break;
        case RISCV_SRA:
            encoding = encode_r_type(inst);
            break;
        case RISCV_OR: 
            encoding = encode_r_type(inst);
            break;
        case RISCV_AND:
            encoding = encode_r_type(inst);
            break;
        case RISCV_ECALL:
            encoding = encode_i_type(inst);
            break;
        case RISCV_EBREAK:
            encoding = encode_i_type(inst);
            break;
        case RISCV_J:
            encoding = encode_j_type(inst);
            break;
        case RISCV_JR:
            encoding = encode_i_type(inst);
            break;
        case RISCV_RET:
            encoding = encode_i_type(inst);
            break;
    }
    return encoding;
}

uint32_t encode_r_type(instruction_t *inst)
{
    uint32_t encoding = 0;
    encoding |= (inst->opcode);     /* op */
    encoding |= (inst->rdst<<7);    /* rd */
    encoding |= (inst->funct3<<12); /*funct3 */
    encoding |= (inst->rsrc1<<15);  /* rs1 */
    encoding |= (inst->rsrc2<<20);  /* rs2 */
    encoding |= (inst->funct7<<25); /* funct7 */
    return encoding;
}

uint32_t encode_i_type(instruction_t *inst)
{
    uint32_t encoding = 0;
    encoding |= (inst->opcode);     /* op */
    encoding |= (inst->rdst<<7);    /* rd */
    encoding |= (inst->funct3<<12); /*funct3 */
    encoding |= (inst->rsrc1<<15);  /* rs1 */
    encoding |= (inst->imm<<20);    /* imm */ 
    return encoding;
}

uint32_t encode_s_type(instruction_t *inst)
{
    /* 
        s-type insructions have a split immediate so imm value has some extra
        bit banging 
    */
    uint32_t encoding = 0;
    uint32_t temp_imm_high = 0;
    uint32_t temp_imm_low = 0;
    uint32_t lower_mask = 0x1f;   /* mask for bit positions 0-4 of the imm */
    uint32_t higher_mask = 0xfe0; /* mask for bit positions 5-11 of the imm */

    temp_imm_high = (inst->imm & higher_mask); /* grab bits in higher pos */
    temp_imm_low = (inst->imm & lower_mask);   /* grab bits in lower pos */

    encoding |= (inst->opcode);     /* op */
    encoding |= (inst->funct3<<12); /* funct3 */
    encoding |= (inst->rsrc1<<15);  /* rs1 */
    encoding |= (inst->rsrc2<<20);  /* rs2 */
    encoding |= (temp_imm_high<<20);      /* imm high */
    encoding |= (temp_imm_low<<7);       /* imm low */
    return encoding;
}

uint32_t encode_b_type(instruction_t * inst)
{
    /* 
        b-type insructions have a split immediate so imm value has some extra
        bit banging 
    */
    uint32_t mask = 0;
    uint32_t encoding = 0;
    uint32_t temp_imm = 0;

    mask = 0x800; /* mask for the 11th bit of imm */
    temp_imm = ((mask & inst->imm) >> 4);
    encoding |= temp_imm;

    mask = 0x1E; /* mask for bits 1-4 of the imm */
    temp_imm = ((mask & inst->imm) << 7);
    encoding |= (temp_imm); /* first part of immediate now done */

    mask = 0x7E0; /* mask for bits 5-10 */
    temp_imm = ((inst->imm & mask) << 20);
    encoding |= (temp_imm);

    mask = 0x1000; /* mask for bit 12 */
    temp_imm = ((inst->imm & mask) << 19);
    encoding |= (temp_imm);

    encoding |= (inst->opcode);     /* op */
    encoding |= (inst->funct3<<12); /* funct3 */
    encoding |= (inst->rsrc1<<15);  /* rs1 */
    encoding |= (inst->rsrc2<<20);  /* rs2 */

    return encoding;
}

uint32_t encode_u_type(instruction_t * inst)
{
    uint32_t encoding = 0;
    encoding |= (inst->opcode);
    encoding |= (inst->rdst<<7);
    encoding |= ((inst->imm)<<12);
    return encoding;
}

/* 
 j-type immediates are calculated by taking target address-pc address.
 then theres just a bunch of weird bit shuffling
*/
uint32_t encode_j_type(instruction_t * inst)
{
    uint32_t temp_imm = 0;
    uint32_t encoding = 0;
    uint32_t calculated_imm = 0;
    uint32_t mask = 0;

    calculated_imm = (int)inst->imm;

    mask = 0xff000;
    temp_imm = ((calculated_imm) & mask);
    encoding |= temp_imm;

    mask = 0x800;
    temp_imm = (((calculated_imm) & mask) << 9);
    encoding |= temp_imm;

    mask = 0x7fe;
    temp_imm = (((calculated_imm) & mask) << 20);
    encoding |= temp_imm;

    mask = 0x100000;
    temp_imm = (((calculated_imm) & mask) << 11);
    encoding |= temp_imm;

    encoding |= (inst->opcode);
    encoding |= (inst->rdst<<7);
    return encoding;
}

