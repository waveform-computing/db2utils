BEGIN {
	first = 1;
	print "WITH TESTS(TEST, RESULT, EXPECTED) AS (";
	print "    VALUES";
}

# test row
NR % 2 == 1 {
	if (first) first = 0; else print ",";
	print "(";
	print "'" gensub("'", "''", "g", $0) "',";
	print "VARCHAR(" $0 "),";
}

# result row
NR % 2 == 0 {
	print "CAST(" $0 " AS VARCHAR(4000))";
	print ")";
}

END {
	print ")";
	print "SELECT";
	print "    ((ROW_NUMBER() OVER () - 1) * 2) + 1 AS LINE_NUMBER,";
	print "    VARCHAR(CASE WHEN LENGTH(TEST)     > 30 THEN LEFT(TEST,     27) || '...' ELSE TEST END,     30) AS TEST,";
	print "    VARCHAR(CASE WHEN LENGTH(RESULT)   > 30 THEN LEFT(RESULT,   27) || '...' ELSE RESULT END,   30) AS RESULT,";
	print "    VARCHAR(CASE WHEN LENGTH(EXPECTED) > 30 THEN LEFT(EXPECTED, 27) || '...' ELSE EXPECTED END, 30) AS EXPECTED,";
	print "    CASE WHEN (RESULT IS NOT NULL AND EXPECTED IS NOT NULL AND RESULT = EXPECTED) OR (RESULT IS NULL AND EXPECTED IS NULL)";
	print "        THEN ''";
	print "        ELSE 'FAILED'";
	print "    END AS FAILURES";
	print "FROM";
	print "    TESTS;";
}
