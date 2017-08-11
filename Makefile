# $(prefix) is where things get installed to
prefix ?= $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/build
bindir := $(prefix)/bin
libdir := $(prefix)/lib
includedir := $(prefix)/include
datarootdir := $(prefix)/share

# $(srcdir) is where source will be downloaded/unpacked
srcdir := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/build

# Auto-guess ARCH from environment if not given
ARCH ?= $(shell uname -m)
UNAME := $(shell uname) 

# Define a few useful things like TAR, what version of FFTW we're building, etc...
TAR := $(shell which gtar 2>/dev/null || which tar 2>/dev/null)
FFTW_VERS := $(shell cat VERSION)
CONFIG := --prefix=$(prefix) --libdir=$(libdir) --bindir=$(bindir)
FFTW_CONFIG := --enable-shared --disable-fortran --disable-mpi --enable-threads --disable-avx --disable-avx2

ifeq ($(ARCH),x86_64)
#FFTW_CONFIG += --enable-sse2 --enable-fma
endif


# Platform-dependent fixups.  Note that we have two ways of detecting if we're
# compiling for Windows; using `uname` when cross-compiling, and using $(OS)
# when running in something like Appveyor.
ifneq ($(findstring MSYS,$(UNAME))$(findstring Windows_NT,$(OS)),)
SHLIB_EXT := dll
SUFFIX := -3
FFTW_CONFIG += --with-our-malloc --with-combined-threads
CONFIG += --host=$(ARCH)-w64-mingw32
libdir = $(bindir)
# On win32, add --with-incoming-stack-boundary
ifneq ($(ARCH),x86_64)
FFTW_CONFIG += --with-incoming-stack-boundary=2
endif
else
# Otherwise, we're on a POSIX-y platform, add the _threads suffix
SUFFIX := _threads
ifeq ($(UNAME),Darwin)
SHLIB_EXT := dylib
else
SHLIB_EXT := so
endif
endif

# If we're cross-compiling, (e.g. $(target) has been set by BinDeps2) add that to CONFIG
CONFIG += --host=$(target)

TARGET_single := libfftw3f$(SUFFIX).$(SHLIB_EXT)
TARGET_double := libfftw3$(SUFFIX).$(SHLIB_EXT)

default: $(libdir)/$(TARGET_single) $(libdir)/$(TARGET_double)

# Define directory-creation rule for many directories we'll need
define dir_rule
$(1):
	@mkdir -p $(1)
endef
$(foreach d,$(srcdir) $(libdir) $(bindir),$(eval $(call dir_rule,$(d))))

FFTW_ENABLE_single := --enable-single
FFTW_ENABLE_double :=

.PHONY: default clean

$(srcdir)/fftw-$(FFTW_VERS).tar.gz: | $(srcdir)
	curl -fkL --connect-timeout 15 -y 15 http://www.fftw.org/$(notdir $@) -o $@

$(srcdir)/configure: $(srcdir)/fftw-$(FFTW_VERS).tar.gz
	$(TAR) -C $(dir $@) --strip-components 1 -xf $<

define FFTW_BUILD
$$(libdir)/$$(TARGET_$1): $$(srcdir)/configure | $$(libdir) $$(bindir)
	(cd $$(dir $$<) && \
	    ./configure $$(CONFIG) $$(FFTW_CONFIG) $$(FFTW_ENABLE_$1) --enable-avx || \
	    ./configure $$(CONFIG) $$(FFTW_CONFIG) $$(FFTW_ENABLE_$1))
	$(MAKE) -C $$(dir $$<) -j3
	$(MAKE) -C $$(dir $$<) install
endef

$(foreach prec,single double,$(eval $(call FFTW_BUILD,$(prec))))

# To `make clean` between builds for different architectures
clean: 
	-$(MAKE) -C $(srcdir) clean
	-rm -rf $(bindir) $(libdir) $(includedir) $(datarootdir)

# For debugging
print-%:
	@echo '$*=$($*)'
