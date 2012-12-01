# This Makefile expects mingw-w64 toolchain, unix-like shell and utilities
# (e.g. msys) and GNU Make.
#
# Targets:
# --------
#   make all        - Makes mCtrl.dll and import libs (this is default target).
#   make doc        - Generates documentation (requires doxygen).
#   make examples   - Makes examples in examples/ subdirectory.
#   make clean      - Deletes mCtrl.dll objects and binary.
#   make distclean  - Deletes all generated files.
#
# Useful variables:
# -----------------
#   PREFIX=<prefix> - Specifies gcc toolchain prefix.
#                     (e.g. 'make PREFIX=x86_64-w64-mingw32-' can build
#                     x86_64 binaries, if you have mingw-w64 installed and
#                     its bin directory in PATH.)
#   DEBUG=<number>  - Sets debugging level. Default is 0. Possible values:
#                         0 = no debugging (i.e. release build)
#                         1 = enables some asserts and traces
#                         2 = as 1 and also tracks malloc/free usage


BASENAME = mCtrl.dll


DEBUG ?= 0

INCDIR ?= include
SRCDIR ?= src
BINDIR ?= bin
OBJDIR ?= obj
LIBDIR ?= lib

export GCC ?= gcc

export CC = $(GCC) -c
export LD = $(GCC)
export WINDRES ?= windres
export DLLTOOL ?= dlltool
export DEP = $(GCC) -x c -MM -MG
export RM = rm -rf


INCLUDES = -I$(INCDIR) -I$(SRCDIR)
WINVER = -D_WIN32_IE=0x0501 -D_WIN32_WINNT=0x0600 -DWINVER=_WIN32_WINNT

override CPPFLAGS += -DMCTRL_BUILD $(WINVER) $(INCLUDES) -D_CRT_NON_CONFORMING_SWPRINTFS
override CFLAGS += -Wall
override LDFLAGS += -mwindows
override LIBS = -lcomctl32 -lole32 -loleaut32

ifneq ($(DEBUG),0)
	override CPPFLAGS += -DDEBUG=$(DEBUG)
	override CFLAGS += -g -O0
else
	override CFLAGS += -O3
	override LDFLAGS += -s
endif

ifndef DISABLE_UNICODE
    override CPPFLAGS_UNICODE = -DUNICODE=1 -D_UNICODE=1
    override CPPFLAGS += $(CPPFLAGS_UNICODE)
    override CFLAGS += -municode
    override LDFLAGS += -municode
endif

PUBLIC_HEADERS = $(wildcard $(INCDIR)/*.h $(INCDIR)/mCtrl/*.h)
HEADERS = $(PUBLIC_HEADERS) $(wildcard $(SRCDIR)/*.h)
C_SOURCES = $(wildcard $(SRCDIR)/*.c)
RC_SOURCES = $(wildcard $(SRCDIR)/*.rc)
SOURCES = $(C_SOURCES) $(RC_SOURCES)
C_OBJECTS = $(addprefix $(OBJDIR)/, $(notdir $(addsuffix .o,$(basename $(C_SOURCES)))))
RC_OBJECTS = $(addprefix $(OBJDIR)/, $(notdir $(addsuffix .o,$(basename $(RC_SOURCES)))))
OBJECTS = $(addprefix $(OBJDIR)/, $(notdir $(addsuffix .o,$(basename $(SOURCES)))))
TARGET = $(BINDIR)/$(BASENAME)
TARGET_LIB = $(LIBDIR)/lib$(basename $(BASENAME)).a


####################
# The main targets #
####################

.PHONY: all examples doc clean distclean mctrl

all: mctrl

mctrl: $(TARGET) $(TARGET_LIB)

examples:
	(cd examples && $(MAKE))

doc:
	doxygen

clean:
	$(RM) $(OBJECTS)
	$(RM) $(OBJDIR)/mCtrl.def
	$(RM) $(TARGET_LIB)
	$(RM) $(TARGET)

distclean: clean
	(cd examples && $(MAKE) clean)
	$(RM) doc/*


################
# Dependencies #
################

# The dependencies are automatically detected by scanning all sources in src/.

Makefile.dep: $(SOURCES) $(HEADERS)
	$(RM) Makefile.dep
	echo "# This file is automatically (re)generated by Makefile when any source" >> Makefile.dep
	echo "# is modified or when new source is added into the src/ directory." >> Makefile.dep
	echo "# Do not modify this file manually." >> Makefile.dep
	echo >> Makefile.dep
	echo >> Makefile.dep
	$(DEP) $(CPPFLAGS) $(SOURCES) | sed "/\.o:/ s/^/$(subst /,\\/,$(OBJDIR))\//" >> Makefile.dep
	echo "$(RC_OBJECTS): $(wildcard $(SRCDIR)/res/*)" >> Makefile.dep
	echo >> Makefile.dep

include Makefile.dep


###############
# Build rules #
###############

$(TARGET) $(TARGET_LIB): $(OBJECTS)
	$(LD) $(LDFLAGS) -mdll $^ -o $@.tmp $(LIBS) -Wl,--output-def,$(OBJDIR)/mCtrl.def
	$(RM) $@.tmp
	$(LD) $(LDFLAGS) -mdll $^ -o $@ $(LIBS) -Wl,--kill-at
	$(DLLTOOL) --kill-at --input-def $(OBJDIR)/mCtrl.def --output-lib $(TARGET_LIB) --dllname $(notdir $@)

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.rc
	$(WINDRES) $(filter-out $(CPPFLAGS_UNICODE), $(subst -isystem,-I,$(CPPFLAGS))) -I$(SRCDIR) $< $@


