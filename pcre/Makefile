###############################################################################
# Makefile for the PCRE UDFs library
#
# This makefile was adapted from the samples/c/bldrtn script distributed with
# IBM DB2 for Linux/UNIX/Windows. It essentially performs the same steps as
# that script with a few minor alterations (links the library with
# the pcre library, and adds a registration step).
###############################################################################

CC:=gcc
CCFLAGS:=

# The name of the target database and target schema name into which the default
# register target will add the functions. Adjust as necessary
DBNAME:=SAMPLE
SCHEMANAME:=UTILS

HARDWAREPLAT:=$(shell uname -m)
DB2PATH:=$(shell getent passwd ${DB2INSTANCE} | cut -d':' -f6)/sqllib

# Platform detection
ifeq ($(filter x86_64 ppc64 s390x ia64, $(HARDWAREPLAT)), $(HARDWAREPLAT))
BITWIDTH:=64
LIB:=lib64
EXTRA_C_FLAGS:=-m64
else
BITWIDTH:=32
LIB:=lib32
ifeq ($(HARDWAREPLAT), s390x)
EXTRA_C_FLAGS:=-m31
else
EXTRA_C_FLAGS:=-m32
endif
endif

# Compiler specific settings
ifeq ($(CC), xlc_r)
SHARED_LIB_FLAG:=-qmkshrobj
else
SHARED_LIB_FLAG:=-shared
EXTRA_C_FLAGS:=$(EXTRA_C_FLAGS) -fpic
endif
LINK_FLAGS:=$(EXTRA_C_FLAGS) $(SHARED_LIB_FLAG)
EXTRA_LFLAG:=-Wl,-rpath,$(DB2PATH)/$(LIB)

install: build
	rm -f $(DB2PATH)/function/pcre_udfs
	cp pcre_udfs $(DB2PATH)/function

build: pcre_udfs

clean:
	rm -f pcre_udfs.o pcre_udfs

test: pcre_udfs.o
	$(CC) $(EXTRA_C_FLAGS) -o pcre_udfs pcre_udfs.o $(EXTRA_LFLAG) -L$(DB2PATH)/$(LIB) -ldb2 -lpthread $(shell pcre-config --libs)

pcre_udfs: pcre_udfs.o
	$(CC) $(LINK_FLAGS) -o pcre_udfs pcre_udfs.o $(EXTRA_LFLAG) -L$(DB2PATH)/$(LIB) -ldb2 -lpthread $(shell pcre-config --libs)

pcre_udfs.o: pcre_udfs.c pcre_udfs.h
	$(CC) $(EXTRA_C_FLAGS) -I$(DB2PATH)/include -c pcre_udfs.c -D_REENTRANT

.PHONY: install build register unregister clean
