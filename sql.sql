-------------------------------------------------------------------------------
-- SQL UTILITIES
-------------------------------------------------------------------------------
-- Copyright (c) 2005-2013 Dave Hughes <dave@waveform.org.uk>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
-------------------------------------------------------------------------------
-- The following functions are used fairly extensively in the other modules for
-- constructing SQL with SQL, including the appropriate escaping.
-------------------------------------------------------------------------------

-- QUOTE_STRING(ASTRING)
-------------------------------------------------------------------------------
-- Returns ASTRING surrounded by single quotes and performs any necessary
-- escaping within the string to make it valid SQL. For example, single quotes
-- within ASTRING are doubled, and control characters like CR or LF are
-- returned as concatenated hex-strings
-------------------------------------------------------------------------------

CREATE FUNCTION QUOTE_STRING(ASTRING VARCHAR(4000))
    RETURNS VARCHAR(4000)
    SPECIFIC QUOTE_STRING1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
BEGIN ATOMIC
    DECLARE I SMALLINT DEFAULT 1;
    DECLARE RESULT VARCHAR(4000) DEFAULT '';
    DECLARE IN_HEX CHAR(1);
    IF ASTRING IS NULL THEN
        RETURN NULL;
    END IF;
    SET IN_HEX = CASE
        WHEN ASCII(SUBSTR(ASTRING, I, 1)) BETWEEN 32 AND 127 THEN 'N'
        ELSE 'Y'
    END;
    SET RESULT = CASE IN_HEX
        WHEN 'Y' THEN 'X'''
        ELSE ''''
    END;
    WHILE I <= LENGTH(ASTRING) DO
        IF ASCII(SUBSTR(ASTRING, I, 1)) BETWEEN 32 AND 127 THEN
            IF IN_HEX = 'Y' THEN
                SET RESULT = RESULT || ''' || ''';
                SET IN_HEX = 'N';
            END IF;
        ELSE
            IF IN_HEX = 'N' THEN
                SET RESULT = RESULT || ''' || X''';
                SET IN_HEX = 'Y';
            END IF;
        END IF;
        SET RESULT = RESULT ||
            CASE IN_HEX
                WHEN 'Y' THEN HEX(SUBSTR(ASTRING, I, 1))
                ELSE REPLACE(SUBSTR(ASTRING, I, 1), '''', '''''')
            END;
        SET I = I + 1;
    END WHILE;
    RETURN RESULT || '''';
END!

COMMENT ON SPECIFIC FUNCTION QUOTE_STRING1
    IS 'Returns ASTRING surrounded by single quotes with all necessary escaping. Useful when constructing SQL for EXECUTE IMMEDIATE within a procedure'!

-- QUOTE_IDENTIFIER(AIDENT)
-------------------------------------------------------------------------------
-- Returns AIDENT surrounded by double quotes if AIDENT contains any characters
-- which cannot appear in an identifier, as defined by the DB2 SQL dialect.
-- Specifically this function is intended for correctly quoting SQL identifiers
-- in generated SQL. Hence if AIDENT contains any lower-case, whitespace or
-- symbolic characters, or begins with a numeral or underscore, it is returned
-- quoted. If AIDENT contains no such characters it is returned verbatim.
-------------------------------------------------------------------------------

CREATE FUNCTION QUOTE_IDENTIFIER(AIDENT VARCHAR(128))
    RETURNS VARCHAR(258)
    SPECIFIC QUOTE_IDENTIFIER1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE
        WHEN AIDENT IS NULL THEN NULL
        WHEN
            TRANSLATE(SUBSTR(AIDENT, 1, 1),
                'XXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
                'ABCDEFGHIJKLMNOPQRSTUVWXYZ#$@') ||
            TRANSLATE(SUBSTR(AIDENT, 2),
                'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
                'ABCDEFGHIJKLMNOPQRSTUVWXYZ#$@_0123456789') =
            REPEAT('X', LENGTH(RTRIM(AIDENT)))
        THEN
            RTRIM(AIDENT)
        ELSE
            '"' || REPLACE(RTRIM(AIDENT), '"', '""') || '"'
    END!

COMMENT ON SPECIFIC FUNCTION QUOTE_STRING1
    IS 'If AIDENT is an identifier which requires quoting, returns AIDENT surrounded by double quotes with all contained double quotes doubled. Useful when constructing SQL for EXECUTE IMMEDIATE within a procedure'!

-- vim: set et sw=4 sts=4:
