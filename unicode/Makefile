###############################################################################
# Makefile for the Unicode UDFs library
#
# This makefile was adapted from the samples/c/bldrtn script distributed with
# IBM DB2 for Linux/UNIX/Windows. It essentially performs the same steps as
# that script with a few minor alterations
###############################################################################

CC:=gcc
CCFLAGS:=

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
	cp unicode_udfs $(DB2PATH)/function/

uninstall:
	rm -f $(DB2PATH)/function/unicode_udfs

build: unicode_udfs

clean:
	rm -f unicode_udfs.o unicode_udfs

unicode_udfs: unicode_udfs.o
	$(CC) $(LINK_FLAGS) -o unicode_udfs unicode_udfs.o $(EXTRA_LFLAG) -L$(DB2PATH)/$(LIB) -ldb2 -lpthread

unicode_udfs.o: unicode_udfs.c unicode_udfs.h
	$(CC) $(EXTRA_C_FLAGS) -I$(DB2PATH)/include -c unicode_udfs.c -D_REENTRANT

.PHONY: uninstall install build clean
