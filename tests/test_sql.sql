CALL ASSERT_EQUALS(QUOTE_STRING('A string'), '''A string''');
CALL ASSERT_EQUALS(QUOTE_STRING('Frank''s string'), '''Frank''''s string''');
CALL ASSERT_EQUALS(QUOTE_STRING('A multi' || X'0A' || 'line string'), '''A multi'' || X''0A'' || ''line string''');
CALL ASSERT_EQUALS(QUOTE_IDENTIFIER('MY_TABLE'), 'MY_TABLE');
CALL ASSERT_EQUALS(QUOTE_IDENTIFIER('MY#TABLE'), 'MY#TABLE');
CALL ASSERT_EQUALS(QUOTE_IDENTIFIER('MyTable'), '"MyTable"');
CALL ASSERT_EQUALS(QUOTE_IDENTIFIER('My "Table"'), '"My ""Table"""');

