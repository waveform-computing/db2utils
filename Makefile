DBNAME:=SAMPLE
SCHEMANAME:=UTILS

ALL_SQL:=$(filter-out install.sql uninstall.sql test.sql,$(wildcard *.sql))
ALL_FOO:=$(ALL_SQL:%.sql=%.foo)

install: install.sql
	cd pcre && $(MAKE) install
	db2 -td! +c -s -vf $< || [ $$? -lt 4 ] && true

uninstall: uninstall.sql
	db2 -td! +c +s -vf $< || true

test: test.awk test.dat
	echo "CONNECT TO $(DBNAME);" > foo
	echo "SET SCHEMA $(SCHEMANAME);" >> foo
	echo "SET PATH SYSTEM PATH, USER, $(SCHEMANAME);" >> foo
	awk --re-interval -f test.awk test.dat >> foo
	db2 -tvf foo || true
	rm -f foo

clean:
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
	awk '\
		/^CREATE +(FUNCTION|PROCEDURE) +([A-Za-z0-9_#$$@]+)\>/ { routine=$$2; } \
		/^[[:space:]]*\<SPECIFIC +([A-Za-z0-9_#$$@]+)\>/ { print "DROP SPECIFIC " routine " " $$2 "!"; } \
		/^CREATE +(ALIAS|TABLE|VIEW|ROLE|TRIGGER) +([A-Za-z0-9_#$$@]+)\>/ { print "DROP " $$2 " " gensub("!$$", "", 1, $$3) "!"; }' $< | tac >> $@
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
