-------------------------------------------------------------------------------
-- SQL UTILITIES
-------------------------------------------------------------------------------
-- Copyright (c) 2005-2010 Dave Hughes <dave@waveform.org.uk>
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
    CASE WHEN
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

-- vim: set et sw=4 sts=4:
