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
 * functions to emit the dt program in a variety of formats
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>

#include <elf.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "riscvarch.h"
#include "output.h"
#include "inst.h"
#include "mem.h"
#include "pc.h"
#include "symtab.h"
#include "util.h"


/* prints the assembly instruction for the -checking flag */
static void sprint_asm(char *buff, instruction_t *inst){
    switch(inst->inst_id) {
        case RISCV_LUI:
            sprintf(buff,"lui x%d, 0x%x",inst->rdst, inst->imm);
            break;
        case RISCV_AUIPC:
            sprintf(buff,"auipc x%d, 0x%x",inst->rdst, inst->imm);
            break;
        case RISCV_JAL:
            sprintf(buff,"jal x%d, 0x%012" PRIx64,inst->rdst, inst->target_address);
            break;
        case RISCV_JALR:
            sprintf(buff,"jalr x%d, x%d, 0x%x",inst->rdst,inst->rsrc1, inst->imm);
            break;
        case RISCV_BEQ:
            sprintf(buff,"beq x%d, x%d, 0x%x",inst->rsrc1,inst->rsrc2,inst->imm);
            break;
        case RISCV_BNE:
            sprintf(buff,"bne x%d, x%d, 0x%x",inst->rsrc1,inst->rsrc2,inst->imm);
            break;
        case RISCV_BLT:
            sprintf(buff,"blt x%d, x%d, 0x%x",inst->rsrc1,inst->rsrc2,inst->imm);
            break;
        case RISCV_BGE:
            sprintf(buff,"bge x%d, x%d, 0x%x",inst->rsrc1,inst->rsrc2,inst->imm);
            break;
        case RISCV_BLTU:
            sprintf(buff,"bltu x%d, x%d, 0x%x",inst->rsrc1,inst->rsrc2,inst->imm);
            break;
        case RISCV_BGEU:
            sprintf(buff,"bgeu x%d, x%d, 0x%x",inst->rsrc1,inst->rsrc2,inst->imm);
            break;
        case RISCV_LB:
            sprintf(buff,"lb x%d, %d[x%d]",inst->rdst, inst->imm,inst->rsrc1);
            break;
        case RISCV_LH:
            sprintf(buff,"lh x%d, %d[x%d]",inst->rdst, inst->imm,inst->rsrc1);
            break;
        case RISCV_LW:
            sprintf(buff,"lw x%d, %d[x%d]",inst->rdst, inst->imm,inst->rsrc1);
            break;
        case RISCV_LBU:
            sprintf(buff,"lbu x%d, %d[x%d]",inst->rdst, inst->imm,inst->rsrc1);
            break;
        case RISCV_LHU:
            sprintf(buff,"lhu x%d, %d[x%d]",inst->rdst, inst->imm,inst->rsrc1);
            break;
        case RISCV_SB:
            sprintf(buff,"sb x%d, %d[x%d]",inst->rsrc2, inst->imm,inst->rsrc1);
            break;
        case RISCV_SH:
            sprintf(buff,"sh x%d, %d[x%d]",inst->rsrc2, inst->imm,inst->rsrc1);
            break;
        case RISCV_SW:
            sprintf(buff,"sw x%d, %d[x%d]",inst->rsrc0, inst->imm,inst->rsrc1);
            break;
        case RISCV_ADDI:
            if (inst->rdst == 0 && inst->rsrc1 == 0 && inst->imm == 0)
                sprintf(buff,"nop");
            else
                sprintf(buff,"addi x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->imm);
            break;
        case RISCV_SLTI:
            sprintf(buff,"slti x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->imm);
            break;
        case RISCV_SLTIU:
            sprintf(buff,"sltiu x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->imm);
            break;
        case RISCV_XORI:
            sprintf(buff,"xori x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->imm);
            break;
        case RISCV_ORI:
            sprintf(buff,"ori x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->imm);
            break;
        case RISCV_ANDI:
            sprintf(buff,"andi x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->imm);
            break;
        case RISCV_SLLI:
            sprintf(buff,"slli x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_SRLI:
            sprintf(buff,"srli x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_SRAI:
            sprintf(buff,"srai x%d, x%d, 0x%x",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_ADD:
            sprintf(buff,"add x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_SUB:
            sprintf(buff,"sub x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_MUL:
            sprintf(buff,"mul x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_DIV:
            sprintf(buff,"div x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_SLL:
            sprintf(buff,"sll x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_SLT:
            sprintf(buff,"slt x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_SLTU:
            sprintf(buff,"sltu x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_XOR:
            sprintf(buff,"xor x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_SRL:
            sprintf(buff,"srl x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_SRA:
            sprintf(buff,"sra x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_OR:
            sprintf(buff,"or x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_AND:
            sprintf(buff,"and x%d, x%d, x%d",inst->rdst,inst->rsrc1,inst->rsrc2);
            break;
        case RISCV_ECALL:
            sprintf(buff, "ecall");
            break;
        case RISCV_EBREAK:
            sprintf(buff,  "ebreak");
            break;
        case RISCV_J:
            sprintf(buff, "j 0x%012" PRIx64, inst->target_address);
            break;
        case RISCV_JR:
            sprintf(buff, "jr 0x%012" PRIx64, inst->target_address);
            break;
        case RISCV_RET:
            sprintf(buff, "ret");
            break;
    }
}

void print_memlist_info(){
    memblock_list_t *list = block_list;

    while (list){
        mem_entry_t *working = list->head;
        printf("\nmem() block: 0x%012" PRIx64 ":\n",list->min_address);
        while (working){
            if (working->type == ENTRY_INSTRUCTION){
                char buff[200];
                sprint_asm(buff,working->inst);
                printf("inst:\t@0x%012" PRIx64 "\t0x%08" PRIx32 "\t%s\n",working->address,working->encoding,buff);
            }
            else if (working->type == ENTRY_BDATA){
                printf("bdata:\t@0x%012" PRIx64 "\t0x%" PRIx8 "\n",working->address,(uint8_t)working->ivalue);
            }
            else if (working->type == ENTRY_HDATA){
                printf("hdata:\t@0x%012" PRIx64 "\t0x%" PRIx16 "\n",working->address,(uint16_t)working->ivalue);
            }
            else if (working->type == ENTRY_WDATA){
                printf("wdata:\t@0x%012" PRIx64 "\t0x%" PRIx32 "\n",working->address,(uint32_t)working->ivalue);
            }
            else if (working->type == ENTRY_LDATA){
                printf("ldata:\t@0x%012" PRIx64 "\t0x%" PRIx64 "\n",working->address,(uint64_t)working->ivalue);
            }
            else if (working->type == ENTRY_FDATA){
                printf("fdata:\t@0x%012" PRIx64 "\t%f\n",working->address,working->fvalue);
            }
            else if (working->type == ENTRY_DDATA){
                printf("ddata:\t@0x%012" PRIx64 "\t%f\n",working->address,working->dvalue);
            }
            else if (working->type == ENTRY_SDATA){
                printf("sdata:\t@0x%012" PRIx64 "\t\"%s\"\n",working->address,working->svalue);
            }
            else if (working->type == ENTRY_DEFINITION){
                if (working->name)
                    printf("def:\t%s skipped\n",working->name);
                else
                    printf("def:\t<<no name>> skipped\n");
            }
            else if (working->type == ENTRY_JOIN_NODE){
                if (working->name)
                    printf("join:\t@0x%012" PRIx64 " %s skipped\n",working->address,working->name);
                else
                    printf("join:\t<<no name>> skipped\n");
            }
            else {
                yyerror("Invalid entry type when emitting instructions");
            }
            working = working->next;
        }
        list = list->next;
    }
}

// fix alignment in ELF files, if needed
static void elf_alignment(int fd, mem_entry_t *working){
    if (working->next){
        if ((working->address + working->size) != working->next->address){
            uint64_t addr = working->address + working->size;
            while (addr < working->next->address){
                uint8_t data = 0;
                if (write(fd, &data, 1) != 1)
                    yyerror("Error in writing padding to output file");
                addr = addr + 1;
            }
        }
    }
}

void write_elf(char * file) {
    int fd;
    int nblocks = 0; // number of memory blocks parsed
    Elf64_Ehdr *elf_header;
    Elf64_Phdr *prog_header;
    memblock_list_t *list;

    fd = open(file, O_CREAT | O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IXUSR);
    if (fd < 0) yyerror("Unable to open output file");

    list = block_list;
    while (list){
        nblocks++;
        list = list->next;
    }

    elf_header = (Elf64_Ehdr*) malloc(sizeof(Elf64_Ehdr));
    if (!elf_header) yyerror("Unable to allocate memory for ELF header");

    elf_header->e_ident[EI_MAG0] = ELFMAG0;
    elf_header->e_ident[EI_MAG1] = ELFMAG1;
    elf_header->e_ident[EI_MAG2] = ELFMAG2;
    elf_header->e_ident[EI_MAG3] = ELFMAG3;
    elf_header->e_ident[EI_CLASS] = ELFCLASS64;
    elf_header->e_ident[EI_DATA] = ELFDATA2LSB;
    elf_header->e_ident[EI_VERSION] = EV_CURRENT;
    elf_header->e_ident[EI_OSABI] = ELFOSABI_SYSV;
    elf_header->e_ident[EI_ABIVERSION] = 0;
    for (int i = EI_PAD; i < EI_NIDENT; i++) elf_header->e_ident[i] = 0;

    elf_header->e_type = ET_EXEC;
    elf_header->e_machine = EM_RISCV;
    elf_header->e_version = EV_CURRENT;
    elf_header->e_entry = pc + sizeof(Elf64_Ehdr) + sizeof(Elf64_Phdr); // FIXME needs to be sizeof(Elf64_Phdr) * number of headers?
    elf_header->e_phoff = sizeof(Elf64_Ehdr);
    elf_header->e_shoff = 0;
    elf_header->e_flags = 0;
    elf_header->e_ehsize = sizeof(Elf64_Ehdr);
    elf_header->e_phentsize = sizeof(Elf64_Phdr);
    elf_header->e_phnum = nblocks;
    elf_header->e_shentsize = 0;
    elf_header->e_shnum = 0;
    elf_header->e_shstrndx = 0;

    if (write(fd, elf_header, sizeof(Elf64_Ehdr)) != sizeof(Elf64_Ehdr))
        yyerror("Error writing ELF header to output file");

    prog_header = (Elf64_Phdr*) malloc(sizeof(Elf64_Phdr) * nblocks);
    if (!prog_header) yyerror("Unable to allocate memory for program headers");
    list = block_list;
    for (int i = 0; i < nblocks; i++){
        prog_header[i].p_type = PT_LOAD; // all segments will be loadable
        prog_header[i].p_flags = PF_X | PF_R | PF_W; // all segments are permitted rwx
        prog_header[i].p_offset = 0;
        prog_header[i].p_vaddr = list->min_address;
        prog_header[i].p_paddr = list->min_address;
        prog_header[i].p_filesz = (list->max_address - list->min_address) + sizeof(Elf64_Ehdr) + sizeof(Elf64_Phdr) + 1; // FIXME needs to be sizeof(Elf64_Phdr) * number of headers?
        prog_header[i].p_memsz = (list->max_address - list->min_address) + sizeof(Elf64_Ehdr) + sizeof(Elf64_Phdr) + 1; // FIXME needs to be sizeof(Elf64_Phdr) * number of headers?
        prog_header[i].p_align = 4096;
        list = list->next;
    }
    if (write(fd, prog_header, sizeof(Elf64_Phdr) * nblocks) != (sizeof(Elf64_Phdr) * nblocks))
        yyerror("Error writing program headers to output file");

    list = block_list;
    while (list){
        mem_entry_t *working = list->head;
        while (working){
            if (working->type == ENTRY_INSTRUCTION){
                if (write(fd, &(working->encoding), sizeof(working->encoding)) != working->size) 
                    yyerror("Error in writing instruction to output file");

                elf_alignment(fd, working);
            }
            else if (working->type == ENTRY_BDATA){
                uint8_t data = (uint8_t)working->ivalue;
                if (write(fd, &(data), sizeof(data)) != working->size) 
                    yyerror("Error in writing integer byte data to output file");

                elf_alignment(fd, working);
            }
            else if (working->type == ENTRY_HDATA){
                uint16_t data = (uint16_t)working->ivalue;
                if (write(fd, &(data), sizeof(data)) != working->size) 
                    yyerror("Error in writing integer half data to output file");

                elf_alignment(fd, working);
            }
            else if (working->type == ENTRY_WDATA){
                uint32_t data = (uint32_t)working->ivalue;
                if (write(fd, &(data), sizeof(data)) != working->size) 
                    yyerror("Error in writing integer word data to output file");

                elf_alignment(fd, working);
            }
            else if (working->type == ENTRY_LDATA){
                uint64_t data = (uint64_t)working->ivalue;
                if (write(fd, &(data), sizeof(data)) != working->size) 
                    yyerror("Error in writing integer long data to output file");

                elf_alignment(fd, working); // probably not needed
            }
            else if (working->type == ENTRY_FDATA){
                float data = (float)working->fvalue;
                if (write(fd, &(data), sizeof(data)) != working->size) 
                    yyerror("Error in writing floating point single data to output file");

                elf_alignment(fd, working);
            }
            else if (working->type == ENTRY_DDATA){
                double data = (double)working->fvalue;
                if (write(fd, &(data), sizeof(data)) != working->size) 
                    yyerror("Error in writing floating point double data to output file");

                elf_alignment(fd, working); // probably not needed
            }
            else if (working->type == ENTRY_SDATA){
                if (write(fd, working->svalue, strlen(working->svalue)+1) != working->size) 
                    yyerror("Error in writing string data to output file");

                elf_alignment(fd, working);
            }
            else if ((working->type == ENTRY_DEFINITION) || (working->type == ENTRY_JOIN_NODE)){
                // skip, do not write anything
            }
            else {
                yyerror("Invalid entry type when emitting instructions");
            }
            working = working->next;
        }
        list = list->next;
    }
    if (close(fd) != 0) yyerror("Error closing output file");
}

void write_text(char * file) {
    FILE *fp = fopen(file,"w");
    if (!fp){
        yyerror("Unable to open file for flat memory text output.");
    }

    memblock_list_t *list = block_list;
    while (list){
        uint64_t adj_start_addr = list->min_address & ~((uint64_t)0xf); // align to 16 bytes
        uint64_t adj_end_addr = (list->max_address + 16) & ~((uint64_t)0xf);
        mem_entry_t *working = list->head;

        // copy all encodings/data into a buffer first,
        // then dump the buffer to the text file. I found 
        // that to be easier and more consistent than 
        // trying to print directly
        unsigned char *buff = (unsigned char *) malloc(adj_end_addr - adj_start_addr);
        bzero(buff, adj_end_addr - adj_start_addr);
        while (working){
            // writes all multibyte values in little-endian order
            if (working->type == ENTRY_INSTRUCTION){
                if ((working->address & 0x3) != 0) yyerror("unaligned instruction encoding");
                int idx = working->address - adj_start_addr;
                buff[idx+0] = (working->encoding>>0)  & 0xff;
                buff[idx+1] = (working->encoding>>8)  & 0xff;
                buff[idx+2] = (working->encoding>>16) & 0xff;
                buff[idx+3] = (working->encoding>>24) & 0xff;
            }
            else if (working->type == ENTRY_BDATA){
                int idx = working->address - adj_start_addr;
                buff[idx+0] = (working->ivalue>>0)  & 0xff;
            }
            else if (working->type == ENTRY_HDATA){
                if ((working->address & 0x1) != 0) yyerror("unaligned half word");
                int idx = working->address - adj_start_addr;
                buff[idx+0] = (working->ivalue>>0)  & 0xff;
                buff[idx+1] = (working->ivalue>>8)  & 0xff;
            }
            else if (working->type == ENTRY_WDATA){
                if ((working->address & 0x3) != 0) yyerror("unaligned word");
                int idx = working->address - adj_start_addr;
                buff[idx+0] = (working->ivalue>>0)  & 0xff;
                buff[idx+1] = (working->ivalue>>8)  & 0xff;
                buff[idx+2] = (working->ivalue>>16) & 0xff;
                buff[idx+3] = (working->ivalue>>24) & 0xff;
            }
            else if (working->type == ENTRY_LDATA){
                yyerror("Writing long data to flat text files not yet supported.");
            }
            else if (working->type == ENTRY_FDATA){
                yyerror("Writing fp data to flat text files not yet supported.");
            }
            else if (working->type == ENTRY_DDATA){
                yyerror("Writing fp data to flat text files not yet supported.");
            }
            else if (working->type == ENTRY_SDATA){
                yyerror("Writing string data to flat text files not yet supported.");
            }
            else if ((working->type == ENTRY_DEFINITION) || (working->type == ENTRY_JOIN_NODE)){
            }
            else {
                yyerror("Invalid entry type when emitting text memory image");
            }
            working = working->next;
        }

        for (int i = 0; i < (adj_end_addr - adj_start_addr); i++){
            if ((i & 0xf) == 0) fprintf(fp,"%012" PRIx64 "  ", adj_start_addr + i);
            fprintf(fp,"%02" PRIx8 " ",buff[i]);
            if ((i & 0xf) == 15) fprintf(fp,"\n");
        }
        fprintf(fp,"\n");
        free(buff);

        list = list->next;
    }

    fclose(fp);
}

void write_bin(char * file_base) {
    int num_memblocks = 0;
    memblock_list_t *list = block_list;
    while (list){
        uint64_t adj_start_addr = list->min_address & ~((uint64_t)0xf); // align to 16 bytes
        uint64_t adj_end_addr = (list->max_address + 16) & ~((uint64_t)0xf);
        mem_entry_t *working = list->head;
        char *filename = (char*) malloc(strlen(file_base) + strlen(".txt") + 10); // extra 10 for the memblock number
        sprintf(filename,"%s-%d.bin",file_base,num_memblocks++);
        int fd = open(filename, O_CREAT | O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR);
        if (fd < 0) yyerror("Unable to open output file for binary output.");


        // copy all encodings/data into a buffer first,
        // similar to text output
        unsigned char *buff = (unsigned char *) malloc(adj_end_addr - adj_start_addr);
        bzero(buff, adj_end_addr - adj_start_addr);
        while (working){
            // writes all multibyte values in little-endian order
            if (working->type == ENTRY_INSTRUCTION){
                if ((working->address & 0x3) != 0) yyerror("unaligned instruction encoding");
                int idx = working->address - adj_start_addr;
                buff[idx+0] = (working->encoding>>0)  & 0xff;
                buff[idx+1] = (working->encoding>>8)  & 0xff;
                buff[idx+2] = (working->encoding>>16) & 0xff;
                buff[idx+3] = (working->encoding>>24) & 0xff;
            }
            else if (working->type == ENTRY_BDATA){
                int idx = working->address - adj_start_addr;
                buff[idx+0] = (working->ivalue>>0)  & 0xff;
            }
            else if (working->type == ENTRY_HDATA){
                if ((working->address & 0x1) != 0) yyerror("unaligned half word");
                int idx = working->address - adj_start_addr;
                buff[idx+0] = (working->ivalue>>0)  & 0xff;
                buff[idx+1] = (working->ivalue>>8)  & 0xff;
            }
            else if (working->type == ENTRY_WDATA){
                if ((working->address & 0x3) != 0) yyerror("unaligned word");
                int idx = working->address - adj_start_addr;
                buff[idx+0] = (working->ivalue>>0)  & 0xff;
                buff[idx+1] = (working->ivalue>>8)  & 0xff;
                buff[idx+2] = (working->ivalue>>16) & 0xff;
                buff[idx+3] = (working->ivalue>>24) & 0xff;
            }
            else if (working->type == ENTRY_LDATA){
                yyerror("Writing long data to flat text files not yet supported.");
            }
            else if (working->type == ENTRY_FDATA){
                yyerror("Writing fp data to flat text files not yet supported.");
            }
            else if (working->type == ENTRY_DDATA){
                yyerror("Writing fp data to flat text files not yet supported.");
            }
            else if (working->type == ENTRY_SDATA){
                yyerror("Writing string data to flat text files not yet supported.");
            }
            else if ((working->type == ENTRY_DEFINITION) || (working->type == ENTRY_JOIN_NODE)){
            }
            else {
                yyerror("Invalid entry type when emitting text memory image");
            }
            working = working->next;
        }

        // write the 16 byte aligned starting address first
        write(fd,&adj_start_addr,sizeof(uint64_t));
        // then write all of the data/encodings
        write(fd,buff,adj_end_addr - adj_start_addr);
        free(buff);
        close(fd);

        list = list->next;
    }

}
