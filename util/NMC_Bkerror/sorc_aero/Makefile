SHELL=/bin/sh

#==============================================================================
#
# stats Makefile
#
#-----------------------------------------------------------------------------
#                          -- Parent make (calls child make) --
#-----------------------------------------------------------------------------
# Default configuration, possibily redefined in Makefile.conf
# -----------------------------------------------------------

SED      = sed
DASPERL  = /usr/bin/perl
COREROOT = ../../..
COREBIN  = $(COREROOT)/bin
CORELIB  = $(COREROOT)/lib
COREINC  = $(COREROOT)/include
COREETC  = $(COREROOT)/etc

# -------------
# General Rules
# -------------

CP      = /bin/cp -p
MKDIR   = /bin/mkdir -p

# ---------
# Libraries
# ---------
LIBgsi = $(CORELIB)/libgsi.a
LIBsp  = $(CORELIB)/libsp.a
LIBw3  = $(CORELIB)/libw3.a
LIBbacio = $(CORELIB)/libbacio.a
LIBmpi = -lmpi

#------------
# need to know what compiling options to use
#------------

include Makefile.conf


# -------------
# This makefile
# -------------

  MAKE_FILE = Makefile


# -----------
# Load module
# -----------

  EXE_FILE = calcstats_aerosol.exe
#  EXE_SP_FILE = calcstats_aerosol.sp.exe
#  EXE_DP_FILE = calcstats_aerosol.dp.exe
 

# --------------------
# Installing directory
# --------------------

  INSTALL_DIR = ../bin


# --------
# Log file
# --------

  LOG_FILE = log.make.$(EXE_FILE)


# ---------------
# Call child make
# ---------------

"" :
	@$(MAKE) -f $(MAKE_FILE) all


# ------------
# Make install
# ------------

install:
	@echo
	@echo '==== INSTALL ================================================='
	@if [ -e $(INSTALL_DIR) ]; then \
	  if [ ! -d $(INSTALL_DIR) ]; then \
	    echo '### Fail to create installing directory ###' ;\
	    echo '### Stop the installation               ###' ;\
	    exit ;\
	  fi ;\
	else \
	  echo "	mkdir -p $(INSTALL_DIR)" ;\
	  mkdir -p $(INSTALL_DIR) ;\
	fi
	cp $(EXE_FILE) $(INSTALL_DIR)
	@cd $(INSTALL_DIR) ; ls -l `pwd`/$(EXE_FILE)


# ----------
# Make clean
# ----------

clean:
	@echo
	@echo '==== CLEAN ==================================================='
	- rm -f $(EXE_FILE) *.o *.mod *.MOD *.lst


#-----------------------------------------------------------------------------
#                          -- Child make --
#-----------------------------------------------------------------------------

# ------------
# Source files
# ------------

  SRCSF90C = \
    comm_mod.f90 \
    delvars_aerosol.f90 \
    deter_subdomain.f90 \
    getcases_nems.f90 \
    grdsphdp.f90 \
    horizsc_aerosol.f90 \
    init_commvars.f90 \
    initvars.f90 \
    kinds.F90 \
    mat.f90 \
    postmod.f90 \
    readpairs_aerosol.f90 \
    smoothz.f90 \
    specgrid.f90 \
    statsmain_aerosol.f90 \
    variables.f90 \
    variances_aerosol.f90 \
    vertsc_aerosol.f90 \

  SRCSF77 =

  SRCSC =

  SRCS = $(SRCSF90C) $(SRCSF77) $(SRCSC)


# ------------
# Object files
# ------------

  SRCSF90	= ${SRCSF90C:.F90=.f90}

  OBJS 		= ${SRCSF90:.f90=.o} ${SRCSF77:.f=.o} ${SRCSC:.c=.o}


# -----------------------
# Default compiling rules
# -----------------------

.SUFFIXES : .F90 .f90 .f .c

.F90.o  :
	@echo
	@echo '---> Compiling $<'
	$(CF) $(FFLAGS) -c $<

.f90.o  :
	@echo
	@echo '---> Compiling $<'
	$(CF) $(FFLAGS) -c $<

.c.o  :
	@echo
	@echo '---> Compiling $<'
	$(CC) $(CFLAGS) -c $<


# ------------
# Dependencies
# ------------

comm_mod.o: kinds.o variables.o
delvars_aerosol.o: kinds.o variables.o
deter_subdomain.o: kinds.o variables.o
getcases_nems.o: kinds.o variables.o
grdsphdp.o: kinds.o variables.o
horizsc_aerosol.o: kinds.o variables.o comm_mod.o specgrid.o postmod.o
init_commvars.o: kinds.o comm_mod.o variables.o
initvars.o: kinds.o specgrid.o variables.o 
mat.o:
postmod.o: kinds.o variables.o
readpairs_aerosol.o: kinds.o specgrid.o comm_mod.o variables.o
smoothz.o:
specgrid.o: kinds.o variables.o
statsmain_aerosol.o: postmod.o specgrid.o comm_mod.o kinds.o variables.o
kinds.o:
variables.o: kinds.o
variances_aerosol.o: postmod.o kinds.o variables.o
vertsc_aerosol.o: postmod.o kinds.o variables.o

# ----
# Link
# ----

$(EXE_FILE) : $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)

calcstats.x: $(EXE_FILE)
	mv $(EXE_FILE) $@


# ------------------------
# Call compiler and linker
# ------------------------

all :
	@$(MAKE) -f $(MAKE_FILE) "COMP_MODE=$@" check_mode
	@echo
	@echo '==== COMPILE ================================================='
	@$(MAKE) -f $(MAKE_FILE) \
		"FFLAGS=$(FFLAGS_N)" \
		"CFLAGS=$(CFLAGS_N)" \
		$(OBJS)
	@echo
	@echo '==== LINK ===================================================='
	@$(MAKE) -f $(MAKE_FILE) \
		"LIBS=$(LIBS_N)" "LDFLAGS=$(LDFLAGS_N)" \
		$(EXE_FILE)

single :
	@$(MAKE) -f $(MAKE_FILE) "COMP_MODE=$@" check_mode
	@echo
	@echo '==== COMPILE ================================================='
	@$(MAKE) -f $(MAKE_FILE) \
		"FFLAGS=$(FFLAGS_N)" \
		"CFLAGS=$(CFLAGS_N)" \
		$(OBJS)
	@echo
	@echo '==== LINK ===================================================='
	@$(MAKE) -f $(MAKE_FILE) \
		"LIBS=$(LIBS_N)" "LDFLAGS=$(LDFLAGS_N)" \
		$(EXE_SP_FILE)

double :
	@$(MAKE) -f $(MAKE_FILE) "COMP_MODE=$@" check_mode
	@echo
	@echo '==== COMPILE ================================================='
	@$(MAKE) -f $(MAKE_FILE) \
		"FFLAGS=$(FFLAGS_N8)" \
		"CFLAGS=$(CFLAGS_N)" \
		$(OBJS)
	@echo
	@echo '==== LINK ===================================================='
	@$(MAKE) -f $(MAKE_FILE) \
		"LIBS=$(LIBS_N8)" "LDFLAGS=$(LDFLAGS_N)" \
		$(EXE_DP_FILE)

debug :
	@$(MAKE) -f $(MAKE_FILE) "COMP_MODE=$@" check_mode
	@echo
	@echo '==== COMPILE ================================================='
	@$(MAKE) -f $(MAKE_FILE) \
		"FFLAGS=$(FFLAGS_D)" \
		"CFLAGS=$(CFLAGS_D)" \
		$(OBJS)
	@echo
	@echo '==== LINK ===================================================='
	@$(MAKE) -f $(MAKE_FILE) \
		"LIBS=$(LIBS_D)" "LDFLAGS=$(LDFLAGS_N)" \
		$(EXE_FILE)

check_mode :
	@if [ -e $(LOG_FILE) ]; then \
	  if [ '$(COMP_MODE)' != `head -n 1 $(LOG_FILE)` ]; then \
	    echo ;\
	    echo "### COMPILE MODE WAS CHANGED ###" ;\
	    make clean ;\
	  fi ;\
	else \
	  echo ;\
	  echo "### NO LOG FILE ###" ;\
	  make clean ;\
	fi
	@echo $(COMP_MODE) > $(LOG_FILE)

# -------------------------
# GMAO Nomenclature/targets
# -------------------------

export: $(EXE_FILE)
	$(MKDIR)                  $(COREBIN)
	$(CP) $(EXE_FILE)         $(COREBIN)/calcstats.x
	$(CP) stats.parm.sample   $(COREETC)/stats.parm

