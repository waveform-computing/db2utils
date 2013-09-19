ALL_TESTS:=$(filter-out test.sql,$(wildcard *.sql))

test: test.sql
	db2 -td! +c -s -vf $< ; db2 ROLLBACK

clean:
	rm -f test.sql

test.sql: $(ALL_TESTS)
	echo "CONNECT TO $(DBNAME)!" > $@
	echo "SET SCHEMA $(SCHEMANAME)!" >> $@
	echo "SET PATH SYSTEM PATH, $(SCHEMANAME), USER!" >> $@
	cat $^ >> $@

.PHONY: test clean
