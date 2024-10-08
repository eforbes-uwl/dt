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
 * a hodge-podge of helper functions
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "util.h"

// arbitrary version numbering
int dt_major_vers = 0;
int dt_minor_vers = 2;
int dt_patch_vers = 0;
int dt_year = 2024;


// replaces escape sequences (like "\n" with a newline, "\t" with a tab, etc.)
char * parse_string(char * str) {
    char * ret;
    int idx = 0;

    ret = (char*) malloc(sizeof(char) * (strlen(str)+1));
    if (!ret) yyerror("Unable to allocate memory for string parsing");
    bzero(ret,strlen(str)+1);

    for (int i=0; i<strlen(str); i++){
        if ((str[i] == '\\') && (i < strlen(str))){
            if (str[i+1] == 'n'){
                ret[idx] = '\n';
                idx++;
                i++;
            }
            else if (str[i+1] == 't'){
                ret[idx] = '\t';
                idx++;
                i++;
            }
            else if (str[i+1] == '\\'){
                ret[idx] = '\\';
                idx++;
                i++;
            }
            else if (str[i+1] == '\"'){
                ret[idx] = '\"';
                idx++;
                i++;
            }
            else if (str[i+1] == '\''){
                ret[idx] = '\'';
                idx++;
                i++;
            }
            else {
                ret[idx] = str[i];
                idx++;
            }
        }
        else {
            ret[idx] = str[i];
            idx++;
        }
    }

    return ret;
}

