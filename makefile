CC = gcc
SCANNER = flex
PARSER = bison

TOP = .

OPTIMIZATION = -O3 
FLAGS = -g -D__STDC_FORMAT_MACROS

WARN = -Wall


CFLAGS = $(OPTIMIZATION) $(FLAGS) $(WARN)


DT_OBJ = $(TOP)/obj/lex.yy.o \
	$(TOP)/obj/inst.o \
	$(TOP)/obj/mem.o \
	$(TOP)/obj/output.o \
	$(TOP)/obj/pc.o \
	$(TOP)/obj/symtab.o \
	$(TOP)/obj/util.o \
	$(TOP)/obj/dt.tab.o

# All sources ###############################################################

$(TOP)/bin/dt: $(DT_OBJ)
	$(CC) -o $(TOP)/bin/dt $(CFLAGS) $(DT_OBJ)

# CC compile ################################################################

$(TOP)/src/lex.yy.c : $(TOP)/src/dt.l $(TOP)/src/dt.tab.h
	$(SCANNER) -o$(TOP)/src/lex.yy.c $(TOP)/src/dt.l

$(TOP)/obj/lex.yy.o : $(TOP)/src/lex.yy.c
	$(CC) $(CFLAGS) -c $(TOP)/src/lex.yy.c -o $(TOP)/obj/lex.yy.o 

$(TOP)/src/dt.tab.c : $(TOP)/src/dt.y $(TOP)/src/inst.h $(TOP)/src/mem.h $(TOP)/src/output.h $(TOP)/src/pc.h $(TOP)/src/riscvarch.h $(TOP)/src/symtab.h $(TOP)/src/util.h
	$(PARSER) -v -d $(TOP)/src/dt.y -o$(TOP)/src/dt.tab.c

$(TOP)/src/dt.tab.h : $(TOP)/src/dt.y $(TOP)/src/inst.h $(TOP)/src/mem.h $(TOP)/src/output.h $(TOP)/src/pc.h $(TOP)/src/riscvarch.h $(TOP)/src/symtab.h $(TOP)/src/util.h
	$(PARSER) -v -d $(TOP)/src/dt.y -o$(TOP)/src/dt.tab.c

$(TOP)/obj/dt.tab.o : $(TOP)/src/dt.tab.c $(TOP)/src/dt.tab.h
	$(CC) $(CFLAGS) -c $(TOP)/src/dt.tab.c -o $(TOP)/obj/dt.tab.o 

$(TOP)/obj/inst.o : $(TOP)/src/inst.c $(TOP)/src/inst.h $(TOP)/src/riscvarch.h $(TOP)/src/mem.h $(TOP)/src/symtab.h $(TOP)/src/util.h
	$(CC) $(CFLAGS) -c $(TOP)/src/inst.c -o $(TOP)/obj/inst.o 

$(TOP)/obj/mem.o : $(TOP)/src/mem.c $(TOP)/src/mem.h $(TOP)/src/inst.h $(TOP)/src/util.h
	$(CC) $(CFLAGS) -c $(TOP)/src/mem.c -o $(TOP)/obj/mem.o 

$(TOP)/obj/output.o : $(TOP)/src/output.c $(TOP)/src/output.h $(TOP)/src/riscvarch.h $(TOP)/src/inst.h $(TOP)/src/mem.h $(TOP)/src/pc.h $(TOP)/src/symtab.h $(TOP)/src/util.h
	$(CC) $(CFLAGS) -c $(TOP)/src/output.c -o $(TOP)/obj/output.o 

$(TOP)/obj/pc.o : $(TOP)/src/pc.c $(TOP)/src/pc.h
	$(CC) $(CFLAGS) -c $(TOP)/src/pc.c -o $(TOP)/obj/pc.o 

$(TOP)/obj/symtab.o : $(TOP)/src/symtab.c $(TOP)/src/symtab.h $(TOP)/src/util.h
	$(CC) $(CFLAGS) -c $(TOP)/src/symtab.c -o $(TOP)/obj/symtab.o 

$(TOP)/obj/util.o : $(TOP)/src/util.c $(TOP)/src/util.h
	$(CC) $(CFLAGS) -c $(TOP)/src/util.c -o $(TOP)/obj/util.o 

# Cleanup ###################################################################

 
clean:
	rm -f $(TOP)/bin/* $(DT_OBJ) $(TOP)/src/lex.yy.c $(TOP)/src/dt.tab.* $(TOP)/src/dt.output
