ALL_TESTS:=$(filter-out test.sql,$(wildcard *.sql))

test: test.sql
	db2 -t +c -s -vf $<

clean:
	rm -f test.sql

test.sql: $(ALL_TESTS)
	echo "CONNECT TO $(DBNAME);" > $@
	echo "SET SCHEMA $(SCHEMANAME);" >> $@
	echo "SET PATH SYSTEM PATH, $(SCHEMANAME), USER;" >> $@
	cat $^ >> $@
	echo "ROLLBACK;" >> $@

.PHONY: test clean
