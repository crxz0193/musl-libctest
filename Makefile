B:=src
SRCS:=$(sort $(wildcard src/*/*.c))
OBJS:=$(SRCS:src/%.c=$(B)/%.o)
LOBJS:=$(SRCS:src/%.c=$(B)/%.lo)
DIRS:=$(patsubst src/%/,%,$(sort $(dir $(SRCS))))
BDIRS:=$(DIRS:%=$(B)/%)
NAMES:=$(SRCS:src/%.c=%)
CFLAGS:=-Isrc/common -I$(B)/common
LDLIBS:=$(B)/common/libtest.a
AR = $(CROSS_COMPILE)ar
RANLIB = $(CROSS_COMPILE)ranlib
RUN_TEST = $(RUN_WRAP) $(B)/common/runtest.exe -w '$(RUN_WRAP)'

all:
%.mk:
# turn off evil implicit rules
.SUFFIXES:
%: %.o
%: %.c
%: %.cc
%: %.C
%: %.cpp
%: %.p
%: %.f
%: %.F
%: %.r
%: %.s
%: %.S
%: %.mod
%: %.sh
%: %,v
%: RCS/%,v
%: RCS/%
%: s.%
%: SCCS/s.%

config.mak:
	cp config.mak.def $@
-include config.mak

define default_template
$(1).BINS_TEMPL:=bin.exe bin-static.exe
$(1).NAMES:=$$(filter $(1)/%,$$(NAMES))
$(1).OBJS:=$$($(1).NAMES:%=$(B)/%.o)
endef
$(foreach d,$(DIRS),$(eval $(call default_template,$(d))))
common.BINS_TEMPL:=
api.BINS_TEMPL:=
math.BINS_TEMPL:=bin.exe

define template
D:=$$(patsubst %/,%,$$(dir $(1)))
N:=$(1)
$(1).BINS := $$($$(D).BINS_TEMPL:bin%=$(B)/$(1)%)
-include src/$(1).mk
#$$(warning D $$(D) N $$(N) B $$($(1).BINS))
$(B)/$(1).exe $(B)/$(1)-static.exe: $$($(1).OBJS)
$(B)/$(1).so: $$($(1).LOBJS)
# make sure dynamic and static binaries are not run parallel (matters for some tests eg ipc)
$(B)/$(1)-static.err: $(B)/$(1).err
endef
$(foreach n,$(NAMES),$(eval $(call template,$(n))))

BINS:=$(foreach n,$(NAMES),$($(n).BINS)) $(B)/api/main.exe
LIBS:=$(foreach n,$(NAMES),$($(n).LIBS)) $(B)/common/runtest.exe
ERRS:=$(BINS:%.exe=%.err)

debug:
	@echo NAMES $(NAMES)
	@echo BINS $(BINS)
	@echo LIBS $(LIBS)
	@echo ERRS $(ERRS)
	@echo DIRS $(DIRS)

define target_template
$(1).ERRS:=$$(filter $(B)/$(1)/%,$$(ERRS))
$(B)/$(1)/all: $(B)/$(1)/REPORT
$(B)/$(1)/run: $(B)/$(1)/cleanerr $(B)/$(1)/REPORT
$(B)/$(1)/cleanerr:
	rm -f $$(filter-out $(B)/$(1)/%-static.err,$$($(1).ERRS))
$(B)/$(1)/clean:
	rm -f $$(filter $(B)/$(1)/%,$$(OBJS) $$(LOBJS) $$(BINS) $$(LIBS)) $(B)/$(1)/*.err
$(B)/$(1)/REPORT: $$($(1).ERRS)
	cat $(B)/$(1)/*.err >$$@
run: $(B)/$(1)/run
$(B)/REPORT: $(B)/$(1)/REPORT
.PHONY: $(B)/$(1)/all $(B)/$(1)/clean
endef
$(foreach d,$(DIRS),$(eval $(call target_template,$(d))))

$(B)/common/libtest.a: $(common.OBJS)
	rm -f $@
	$(AR) rc $@ $^
	$(RANLIB) $@

$(B)/common/all: $(B)/common/runtest.exe

$(ERRS): $(B)/common/runtest.exe | $(BDIRS)
$(BINS) $(LIBS): $(B)/common/libtest.a
$(OBJS): src/common/test.h | $(BDIRS)
$(BDIRS):
	mkdir -p $@

$(B)/common/options.h: src/common/options.h.in
	$(CC) -E - <$< | sed -e '1,/optiongroups_unistd_end/d' -e '/^#/d' -e '/^[[:space:]]*$$/d' -e 's/^/#define /' >$@

$(B)/common/mtest.o: src/common/mtest.h
$(math.OBJS): src/common/mtest.h

$(B)/api/main.exe: $(api.OBJS)
api/main.OBJS:=$(api.OBJS)
$(api.OBJS):$(B)/common/options.h
$(api.OBJS):CFLAGS+=-pedantic-errors -Werror -Wno-unused -D_XOPEN_SOURCE=700

all:$(B)/REPORT
run:$(B)/REPORT
clean:
	rm -f $(OBJS) $(BINS) $(LIBS) $(B)/common/libtest.a $(B)/common/runtest.exe $(B)/common/options.h $(B)/*/*.err
cleanall: clean
	rm -f $(B)/REPORT $(B)/*/REPORT
$(B)/REPORT:
	cat $^ |tee $@

$(B)/%.o:: src/%.c
	$(CC) $(CFLAGS) $($*.CFLAGS) -c -o $@ $< 2>$@.err || echo BUILDERROR $@
$(B)/%.s:: src/%.c
	$(CC) $(CFLAGS) $($*.CFLAGS) -S -o $@ $< || echo BUILDERROR $@
$(B)/%.lo:: src/%.c
	$(CC) $(CFLAGS) $($*.CFLAGS) -fPIC -DSHARED -c -o $@ $< 2>$@.err || echo BUILDERROR $@
$(B)/%.so: $(B)/%.lo
	$(CC) -shared $(LDFLAGS) $($*.so.LDFLAGS) -o $@ $< $($*.so.LOBJS) $(LDLIBS) $($*.so.LDLIBS) 2>$@.err || echo BUILDERROR $@
$(B)/%-static.exe: $(B)/%.o
	$(CC) -static $(LDFLAGS) $($*-static.LDFLAGS) -o $@ $< $($*-static.OBJS) $(LDLIBS) $($*-static.LDLIBS) 2>$@.ld.err || echo BUILDERROR $@
$(B)/%.exe: $(B)/%.o
	$(CC) $(LDFLAGS) $($*.LDFLAGS) -o $@ $< $($*.OBJS) $(LDLIBS) $($*.LDLIBS) 2>$@.ld.err || echo BUILDERROR $@

%.o.err: %.o
	touch $@
%.lo.err: %.lo
	touch $@
%.so.err: %.so
	touch $@
%.ld.err: %.exe
	touch $@
%.err: %.exe
	$(RUN_TEST) ./$< >$@ || true

.PHONY: all run clean cleanall

