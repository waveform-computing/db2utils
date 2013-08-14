DBNAME:=SAMPLE
SCHEMANAME:=UTILS

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
	echo "SET PATH SYSTEM PATH, USER, $(SCHEMANAME);" >> foo
	awk --re-interval -f test.awk test.dat >> foo
	db2 -tvf foo || true
	rm -f foo

clean: $(SUBDIRS)
	$(MAKE) -C pcre clean
	rm -f foo
	rm -f *.foo
	rm -f install.sql
	rm -f uninstall.sql

%.foo: %.sql
	cat $< >> foo
	touch $@

install.sql: $(ALL_FOO)
	echo "CONNECT TO $(DBNAME)!" > $@
	echo "SET SCHEMA $(SCHEMANAME)!" >> $@
	echo "SET PATH SYSTEM PATH, USER, $(SCHEMANAME)!" >> $@
	cat foo >> $@
	echo "COMMIT!" >> $@
	rm foo
	rm -f *.foo

uninstall.sql: install.sql
	echo "CONNECT TO $(DBNAME)!" > $@
	echo "SET SCHEMA $(SCHEMANAME)!" >> $@
	echo "SET PATH SYSTEM PATH, USER, $(SCHEMANAME)!" >> $@
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
