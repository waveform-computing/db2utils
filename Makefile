DBNAME:=SAMPLE
SCHEMANAME:=UTILS

VERSION:=0.1
ALL_EXT:=$(wildcard pcre/*.c) $(wildcard pcre/*.h)
ALL_SQL:=$(filter-out install.sql uninstall.sql test.sql,$(wildcard *.sql))
ALL_FOO:=$(ALL_SQL:%.sql=%.foo)

install: install.sql
	$(MAKE) -C pcre install
	db2 -td! +c -s -vf $< || [ $$? -lt 4 ] && true

uninstall: uninstall.sql
	db2 -td! +c +s -vf $< || true
	$(MAKE) -C pcre uninstall

test: test.awk test.dat
	echo "CONNECT TO $(DBNAME);" > foo
	echo "SET SCHEMA $(SCHEMANAME);" >> foo
	echo "SET PATH SYSTEM PATH, $(SCHEMANAME), USER;" >> foo
	awk --re-interval -f test.awk test.dat >> foo
	db2 -tvf foo || true
	rm -f foo

clean: $(SUBDIRS)
	$(MAKE) -C pcre clean
	rm -f foo
	rm -f *.foo
	rm -f install.sql
	rm -f uninstall.sql
	rm -fr build/ dist/

dist: $(ALL_SQL) $(ALL_EXT) \
		INSTALL LICENSE \
		Makefile pcre/Makefile \
		uninstall.awk test.awk test.dat
	mkdir -p build/db2utils/
	mkdir -p dist/
	for f in $^; do \
		mkdir -p build/db2utils/$$(dirname $$f)/ ; \
		cp $$f build/db2utils/$$(dirname $$f)/ ; \
	done
	tar -cvzf dist/db2utils-$(VERSION).tar.gz -C build/ db2utils/

%.foo: %.sql
	cat $< >> foo
	touch $@

install.sql: $(ALL_FOO)
	echo "CONNECT TO $(DBNAME)!" > $@
	echo "SET SCHEMA $(SCHEMANAME)!" >> $@
	echo "SET PATH SYSTEM PATH, $(SCHEMANAME), USER!" >> $@
	cat foo >> $@
	echo "COMMIT!" >> $@
	rm foo
	rm -f *.foo

uninstall.sql: install.sql
	echo "CONNECT TO $(DBNAME)!" > $@
	echo "SET SCHEMA $(SCHEMANAME)!" >> $@
	echo "SET PATH SYSTEM PATH, $(SCHEMANAME), USER!" >> $@
	awk -f uninstall.awk $< | tac >> $@
	echo "COMMIT!" >> $@

export_load.foo: sql.foo

exceptions.foo: sql.foo auth.foo

evolve.foo: sql.foo auth.foo

auth.foo: sql.foo

drop_schema.foo: sql.foo

history.foo: sql.foo auth.foo date_time.foo

corrections.foo: sql.foo log.foo

toggle_triggers.foo: sql.foo

.PHONY: install uninstall clean test
