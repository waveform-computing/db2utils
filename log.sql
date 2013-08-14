-------------------------------------------------------------------------------
-- LOGGING FRAMEWORK
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

-- VARCHAR_EXPRESSION(EXPRESSION, TYPESCHEMA, TYPENAME)
-- VARCHAR_EXPRESSION(EXPRESSION, TYPENAME)
-------------------------------------------------------------------------------
-- This is a small utility function used to simply construction of procedures
-- which need to represent arbitrary values as a VARCHAR, typically for
-- inclusion in messages. Given an expression and a datatype expressed as a
-- schema and a typename, the function returns the expression wrapped in
-- whatever scalar function calls would be necessary to convert the
-- expression's datatype into a VARCHAR.  Currently the function does not
-- support anything beyond the basic built-in types. Specifically, user-defined
-- types and LOB types are not supported.  If TYPESCHEMA is omitted, then
-- SYSIBM is assumed.
--
-- If anyone's wondering about any the ludicrous amount of single quotes in the
-- definition below, consider that it's the consequence of using SQL's stupid
-- "double-it" escaping mechanism in SQL to generate other SQL.
-------------------------------------------------------------------------------

CREATE FUNCTION VARCHAR_EXPRESSION(
    EXPRESSION VARCHAR(256),
    TYPESCHEMA VARCHAR(128),
    TYPENAME VARCHAR(128)
)
    RETURNS VARCHAR(300)
    SPECIFIC VARCHAR_EXPRESSION1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE TYPESCHEMA
        WHEN 'SYSIBM' THEN
            CASE TYPENAME
                WHEN 'CHARACTER'  THEN ''''''''' || REPLACE(TRIM(' || EXPRESSION || '), '''''''', '''''''''''') || '''''''''
                WHEN 'GRAPHIC'    THEN ''''''''' || REPLACE(VARCHAR(TRIM(' || EXPRESSION || '), '''''''', '''''''''''') || '''''''''
                WHEN 'VARCHAR'    THEN ''''''''' || REPLACE(' || EXPRESSION || ', '''''''', '''''''''''') || '''''''''
                WHEN 'VARGRAPHIC' THEN ''''''''' || REPLACE(VARCHAR(' || EXPRESSION || '), '''''''', '''''''''''') || '''''''''
                WHEN 'BIGINT'     THEN 'TRIM(CHAR(' || EXPRESSION || ')'
                WHEN 'INTEGER'    THEN 'TRIM(CHAR(' || EXPRESSION || ')'
                WHEN 'SMALLINT'   THEN 'TRIM(CHAR(' || EXPRESSION || ')'
                WHEN 'DECFLOAT'   THEN 'TRIM(CHAR(' || EXPRESSION || ')'
                WHEN 'DECIMAL'    THEN 'TRIM(CHAR(' || EXPRESSION || ')'
                WHEN 'DOUBLE'     THEN 'TRIM(CHAR(' || EXPRESSION || ')'
                WHEN 'REAL'       THEN 'TRIM(CHAR(' || EXPRESSION || ')'
                WHEN 'DATE'       THEN ''''''''' || VARCHAR(CHAR(' || EXPRESSION || ', ISO)) || '''''''''
                WHEN 'TIME'       THEN ''''''''' || VARCHAR(CHAR(' || EXPRESSION || ', JIS)) || '''''''''
                WHEN 'TIMESTAMP'  THEN ''''''''' || TO_CHAR(' || EXPRESSION || ', ''YYYY-MM-DD HH24:MI:SS.NNNNNN'') || '''''''''
                ELSE RAISE_ERROR('70001', 'Cannot construct key expression for system type ' || TYPENAME)
            END
        ELSE
            RAISE_ERROR('70001', 'Cannot construct VARCHAR expression for user-defined type ' || TYPESCHEMA || '.' || TYPENAME)
    END!

CREATE FUNCTION VARCHAR_EXPRESSION(
    EXPRESSION VARCHAR(256),
    TYPENAME VARCHAR(128)
)
    RETURNS VARCHAR(300)
    SPECIFIC VARCHAR_EXPRESSION2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    VARCHAR_EXPRESSION(EXPRESSION, 'SYSIBM', TYPENAME)!

-- LOG
-------------------------------------------------------------------------------
-- The LOG table holds a list of administrative notifications.  The CREATED
-- column contains the timestamp of the message. The SEVERITY column indicates
-- whether the message is:
--
-- D = debugging
-- I = informational
-- W = warning
-- E = error
--
-- The SUBJECT_TYPE schema indicates whether the subject of the message is:
--
-- D = the database
-- S = a schema (specified by SUBJECT_SCHEMA)
-- T = a table (specified by SUBJECT_SCHEMA, SUBJECT_NAME)
-- V = a view
-- A = an alias
-- F = a function
-- P = a procedure
-- M = a method
-- R = a trigger
-- I = an index
-- Q = a sequence
--
-- Finally, the TEXT column contains up to 1k of text for the message itself.
-- The table has three roles associated with it which are created in the DDL
-- below:
--
-- LOG_WRITER -- Has the ability to INSERT into the table
-- LOG_READER -- Has the ability to SELECT from the table
-- LOG_ADMIN -- Has CONTROL of the table
-------------------------------------------------------------------------------

CREATE ROLE LOG_ADMIN!
CREATE ROLE LOG_READER!
CREATE ROLE LOG_WRITER!

CREATE TABLE LOG (
    CREATED          TIMESTAMP DEFAULT CURRENT TIMESTAMP NOT NULL,
    SEVERITY         CHAR(1) DEFAULT 'I' NOT NULL,
    SUBJECT_TYPE     CHAR(1) DEFAULT 'D' NOT NULL,
    SUBJECT_SCHEMA   VARCHAR(128) DEFAULT NULL,
    SUBJECT_NAME     VARCHAR(128) DEFAULT NULL,
    TEXT             VARCHAR(1024) NOT NULL
)!

CREATE INDEX LOG_IX1
    ON LOG (SUBJECT_SCHEMA, SUBJECT_NAME)!

CREATE INDEX LOG_IX2
    ON LOG (SUBJECT_TYPE, SUBJECT_SCHEMA, SUBJECT_NAME)!

CREATE INDEX LOG_IX3
    ON LOG (CREATED, SUBJECT_TYPE, SUBJECT_SCHEMA, SUBJECT_NAME)!

ALTER TABLE LOG
    ADD CONSTRAINT SEVERITY_CK CHECK (SEVERITY IN ('D', 'I', 'W', 'E'))
    ADD CONSTRAINT SUBJECT_TYPE_CK CHECK (
        SUBJECT_TYPE IN ('D', 'S', 'T', 'V', 'A', 'F', 'P', 'M', 'R', 'I', 'Q')
    )
    ADD CONSTRAINT SUBJECT_SCHEMA_CK CHECK (
        (SUBJECT_TYPE = 'D' AND SUBJECT_SCHEMA IS NULL) OR
        (SUBJECT_TYPE <> 'D' AND SUBJECT_SCHEMA IS NOT NULL)
    )
    ADD CONSTRAINT SUBJECT_NAME_CK CHECK (
        (SUBJECT_TYPE IN ('D', 'S') AND SUBJECT_NAME IS NULL) OR
        (SUBJECT_TYPE NOT IN ('D', 'S') AND SUBJECT_NAME IS NOT NULL)
    )!

GRANT CONTROL ON LOG TO ROLE LOG_ADMIN!
GRANT SELECT ON LOG TO ROLE LOG_READER!
GRANT INSERT ON LOG TO ROLE LOG_WRITER!

-- vim: set et sw=4 sts=4:
