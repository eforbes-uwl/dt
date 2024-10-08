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
   * dt lexer specification
   */

%option noyywrap case-insensitive yylineno

%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include "dt.tab.h"
%}

%%

  /* Core Instruction */

lui                             {return INST_LUI;}
auipc                           {return INST_AUIPC;}
jal                             {return INST_JAL;}
jalr                            {return INST_JALR;}
beq                             {return INST_BEQ;}
bne                             {return INST_BNE;}
blt                             {return INST_BLT;}
bge                             {return INST_BGE;}
bltu                            {return INST_BLTU;}
bgeu                            {return INST_BGEU;}
lb                              {return INST_LB;}
lh                              {return INST_LH;}
lw                              {return INST_LW;}
lbu                             {return INST_LBU;}
lhu                             {return INST_LHU;}
sb                              {return INST_SB;}
sh                              {return INST_SH;}
sw                              {return INST_SW;}
addi                            {return INST_ADDI;}
slti                            {return INST_SLTI;}
sltiu                           {return INST_SLTIU;}
xori                            {return INST_XORI;}
ori                             {return INST_ORI;}
andi                            {return INST_ANDI;}
slli                            {return INST_SLLI;}
srli                            {return INST_SRLI;}
srai                            {return INST_SRAI;}
add                             {return INST_ADD;}
sub                             {return INST_SUB;}
sll                             {return INST_SLL;}
slt                             {return INST_SLT;}
sltu                            {return INST_SLTU;}
xor                             {return INST_XOR;}
srl                             {return INST_SRL;}
sra                             {return INST_SRA;}
or                              {return INST_OR;}
and                             {return INST_AND;}
fence                           {return INST_FENCE;}
fence\.i                        {return INST_FENCE_I;}
ecall                           {return INST_ECALL;}
ebreak                          {return INST_EBREAK;}
csrrw                           {return INST_CSRRW;}
csrrs                           {return INST_CSRRS;}
csrrc                           {return INST_CSRRC;}
csrrwi                          {return INST_CSRRWI;}
csrrsi                          {return INST_CSRRSI;}
csrrci                          {return INST_CSRRCI;}

j                               {return INST_J;}
jr                              {return INST_JR;}
ret                             {return INST_RET;}
nop                             {return INST_NOP;}

mul                             {return INST_MUL;}
div                             {return INST_DIV;}

  /* Operators */
\+                               {return PLUS;}
-                                {return MINUS;}
\*                               {return MULTIPLY;}
\/                               {return DIVIDE;}
&                                {return AND;}
\|                               {return OR;}
~                                {return NOT;}
\^                               {return XOR;}
\<\<                             {return LSHIFT;}
\>\>                             {return RSHIFT;}
@                                {return ADDRESSOF;}
\<                               {return LT;}
\>                               {return GT;}
\<=                              {return LTE;}
\>=                              {return GTE;}
==                               {return EQ;}
!=                               {return NEQ;}
=                                {return ASSIGN;}

  /* Register convention names */
$zero                            {yylval.ivalue = (int64_t) 0;  return IREG;}
$ra                              {yylval.ivalue = (int64_t) 1;  return IREG;}
$sp                              {yylval.ivalue = (int64_t) 2;  return IREG;}
$gp                              {yylval.ivalue = (int64_t) 3;  return IREG;}
$tp                              {yylval.ivalue = (int64_t) 4;  return IREG;}
$t0                              {yylval.ivalue = (int64_t) 5;  return IREG;}
$t1                              {yylval.ivalue = (int64_t) 6;  return IREG;}
$t2                              {yylval.ivalue = (int64_t) 7;  return IREG;}
$s0                              {yylval.ivalue = (int64_t) 8;  return IREG;}
$fp                              {yylval.ivalue = (int64_t) 8;  return IREG;}
$s1                              {yylval.ivalue = (int64_t) 9;  return IREG;}
$a0                              {yylval.ivalue = (int64_t) 10; return IREG;}
$a1                              {yylval.ivalue = (int64_t) 11; return IREG;}
$a2                              {yylval.ivalue = (int64_t) 12; return IREG;}
$a3                              {yylval.ivalue = (int64_t) 13; return IREG;}
$a4                              {yylval.ivalue = (int64_t) 14; return IREG;}
$a5                              {yylval.ivalue = (int64_t) 15; return IREG;}
$a6                              {yylval.ivalue = (int64_t) 16; return IREG;}
$a7                              {yylval.ivalue = (int64_t) 17; return IREG;}
$s2                              {yylval.ivalue = (int64_t) 18; return IREG;}
$s3                              {yylval.ivalue = (int64_t) 19; return IREG;}
$s4                              {yylval.ivalue = (int64_t) 20; return IREG;}
$s5                              {yylval.ivalue = (int64_t) 21; return IREG;}
$s6                              {yylval.ivalue = (int64_t) 22; return IREG;}
$s7                              {yylval.ivalue = (int64_t) 23; return IREG;}
$s8                              {yylval.ivalue = (int64_t) 24; return IREG;}
$s9                              {yylval.ivalue = (int64_t) 25; return IREG;}
$s10                             {yylval.ivalue = (int64_t) 26; return IREG;}
$s11                             {yylval.ivalue = (int64_t) 27; return IREG;}
$t3                              {yylval.ivalue = (int64_t) 28; return IREG;}
$t4                              {yylval.ivalue = (int64_t) 29; return IREG;}
$t5                              {yylval.ivalue = (int64_t) 30; return IREG;}
$t6                              {yylval.ivalue = (int64_t) 31; return IREG;}

  /* Registers */
$x[0-9]+[ \t]*                   {yylval.ivalue = (int64_t) atoi(&yytext[2]); return IREG;}
$pc[ \t]*                        {return PCREG;}

  /* Code Blocks */
mem                              {return MEMBLOCK;}
if                               {return IFBLOCK;}
else                             {return ELSEBLOCK;}
while                            {return WHILEBLOCK;}
do                               {return DOBLOCK;}
until                            {return UNTILBLOCK;}

  /* Immediates / Offsets */
[-+]?[0-9]+                      {yylval.ivalue = (int64_t) atoi(yytext); return IIMM;}
0x[0-9a-f]+                      {sscanf(yytext,"%" PRIx64,&(yylval.ivalue)); return IIMM;}
[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)? {yylval.fvalue = atof(&yytext[1]); return FIMM;}
\".*\"                           {yylval.string = strndup(&yytext[1],strlen(yytext)-2); return STRING;} 



  /* Comments */
#.*                              /* gobble up comments */

  /* Labels / Names */
[a-z][a-z0-9_]*                  {yylval.string = strdup(yytext);return LABEL;}

  /* Misc */
\[                               {return LBRACKET;}
\]                               {return RBRACKET;}
\{                               {return LBRACE;}
\}                               {return RBRACE;}
\(                               {return LPAREN;}
\)                               {return RPAREN;}
:                                {return COLON;}

  /* data directives */
\.byte                           {return BYTEFILL;}
\.half                           {return HALFFILL;}
\.word                           {return WORDFILL;}
\.long                           {return LONGFILL;}
\.float                          {return FLOATFILL;}
\.double                         {return DOUBLEFILL;}
\.stringz                        {return STRINGZFILL;}

[ \t]+                           /* whitespace -- do nothing */
[\n\r]+                          /* linefeed -- do nothing */
,                                /* commas -- ignore them too */
.                                {return UNKNOWN;}

%%

