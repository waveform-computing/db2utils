-------------------------------------------------------------------------------
-- HISTORY FRAMEWORK
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
-- The following code is adapted from a Usenet posting, discussing methods of
-- tracking history via triggers:
--
-- http://groups.google.com/group/comp.databases.ibm-db2/msg/e84aeb1f6ac87e6c
--
-- Routines are provided for creating a table which will store the history of
-- a "master" table, and for creating triggers that will keep the history
-- populated as rows are manipulated in the master. Routines are also provided
-- for creating views providing commonly requested transformations of the
-- history such as "what changed when" and "snapshots over constant periods".
-------------------------------------------------------------------------------

-- HISTORY$EFFNAME(RESOLUTION)
-- HISTORY$EXPNAME(RESOLUTION)
-- HISTORY$EFFDEFAULT(RESOLUTION)
-- HISTORY$EXPDEFAULT(RESOLUTION)
-- HISTORY$PERIODSTART(RESOLUTION, EXPRESSION)
-- HISTORY$PERIODEND(RESOLUTION, EXPRESSION)
-- HISTORY$PERIODLEN(RESOLUTION)
-- HISTORY$EFFNEXT(RESOLUTION, OFFSET)
-- HISTORY$EXPPRIOR(RESOLUTION, OFFSET)
-- HISTORY$INSERT(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION, OFFSET)
-- HISTORY$EXPIRE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION, OFFSET)
-- HISTORY$DELETE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION)
-- HISTORY$UPDATE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION)
-- HISTORY$CHECK(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION)
-- HISTORY$CHANGES(SOURCE_SCHEMA, SOURCE_TABLE, RESOLUTION)
-- HISTORY$SNAPSHOTS(SOURCE_SCHEMA, SOURCE_TABLE, RESOLUTION)
-- HISTORY$UPDATE_FIELDS(SOURCE_SCHEMA, SOURCE_TABLE, KEY_FIELDS)
-- HISTORY$UPDATE_WHEN(SOURCE_SCHEMA, SOURCE_TABLE, KEY_FIELDS)
-------------------------------------------------------------------------------
-- These functions are effectively private utility subroutines for the
-- procedures defined below. They simply generate snippets of SQL given a set
-- of input parameters.
-------------------------------------------------------------------------------

CREATE FUNCTION HISTORY$EFFNAME(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EFFNAME
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE WHEN RESOLUTION IN (
            'MICROSECOND',
            'SECOND',
            'MINUTE',
            'HOUR',
            'DAY',
            'WEEK',
            'WEEK_ISO',
            'MONTH',
            'YEAR'
        )
        THEN 'EFFECTIVE_' || RESOLUTION
        ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
    END!

CREATE FUNCTION HISTORY$EXPNAME(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EXPNAME
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE WHEN RESOLUTION IN (
            'MICROSECOND',
            'SECOND',
            'MINUTE',
            'HOUR',
            'DAY',
            'WEEK',
            'WEEK_ISO',
            'MONTH',
            'YEAR'
        )
        THEN 'EXPIRY_' || RESOLUTION
        ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
    END!

CREATE FUNCTION HISTORY$EFFDEFAULT(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EFFDEFAULT
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE
        WHEN RESOLUTION IN ('MICROSECOND', 'SECOND', 'MINUTE', 'HOUR') THEN 'CURRENT TIMESTAMP'
        WHEN RESOLUTION IN ('DAY', 'WEEK', 'WEEK_ISO', 'MONTH', 'YEAR') THEN 'CURRENT DATE'
        ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
    END!

CREATE FUNCTION HISTORY$EXPDEFAULT(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(28)
    SPECIFIC HISTORY$EXPDEFAULT
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE
        WHEN RESOLUTION IN ('MICROSECOND', 'SECOND', 'MINUTE', 'HOUR') THEN 'TIMESTAMP(''9999-12-31 23:59:59.999999'')'
        WHEN RESOLUTION IN ('DAY', 'WEEK', 'WEEK_ISO', 'MONTH', 'YEAR') THEN 'DATE(''9999-12-31'')'
        ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
    END!

CREATE FUNCTION HISTORY$PERIODSTART(RESOLUTION VARCHAR(11), EXPRESSION VARCHAR(100))
    RETURNS VARCHAR(100)
    SPECIFIC HISTORY$PERIODSTART
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE RESOLUTION
        WHEN 'MICROSECOND' THEN                        EXPRESSION
        WHEN 'SECOND'      THEN 'SECONDSTART('      || EXPRESSION || ')'
        WHEN 'MINUTE'      THEN 'MINUTESTART('      || EXPRESSION || ')'
        WHEN 'HOUR'        THEN 'HOURSTART('        || EXPRESSION || ')'
        WHEN 'DAY'         THEN                        EXPRESSION
        WHEN 'WEEK'        THEN 'WEEKSTART('        || EXPRESSION || ')'
        WHEN 'WEEK_ISO'    THEN 'WEEKSTART_ISO('    || EXPRESSION || ')'
        WHEN 'MONTH'       THEN 'MONTHSTART('       || EXPRESSION || ')'
        WHEN 'YEAR'        THEN 'YEARSTART('        || EXPRESSION || ')'
        ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
    END!

CREATE FUNCTION HISTORY$PERIODEND(RESOLUTION VARCHAR(11), EXPRESSION VARCHAR(100))
    RETURNS VARCHAR(100)
    SPECIFIC HISTORY$PERIODEND
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE RESOLUTION
        WHEN 'MICROSECOND' THEN                      EXPRESSION
        WHEN 'SECOND'      THEN 'SECONDEND('      || EXPRESSION || ')'
        WHEN 'MINUTE'      THEN 'MINUTEEND('      || EXPRESSION || ')'
        WHEN 'HOUR'        THEN 'HOUREND('        || EXPRESSION || ')'
        WHEN 'DAY'         THEN                      EXPRESSION
        WHEN 'WEEK'        THEN 'WEEKEND('        || EXPRESSION || ')'
        WHEN 'WEEK_ISO'    THEN 'WEEKEND_ISO('    || EXPRESSION || ')'
        WHEN 'MONTH'       THEN 'MONTHEND('       || EXPRESSION || ')'
        WHEN 'YEAR'        THEN 'YEAREND('        || EXPRESSION || ')'
        ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
    END!

CREATE FUNCTION HISTORY$PERIODLEN(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(100)
    SPECIFIC HISTORY$PERIODLEN
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE RESOLUTION
        WHEN 'MICROSECOND' THEN '1 MICROSECOND'
        WHEN 'SECOND'      THEN '1 SECOND'
        WHEN 'MINUTE'      THEN '1 MINUTE'
        WHEN 'HOUR'        THEN '1 HOUR'
        WHEN 'DAY'         THEN '1 DAY'
        WHEN 'WEEK'        THEN '7 DAYS'
        WHEN 'WEEK_ISO'    THEN '7 DAYS'
        WHEN 'MONTH'       THEN '1 MONTH'
        WHEN 'YEAR'        THEN '1 YEAR'
        ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
    END!

CREATE FUNCTION HISTORY$EFFNEXT(RESOLUTION VARCHAR(11), OFFSET VARCHAR(100))
    RETURNS VARCHAR(100)
    SPECIFIC HISTORY$EFFNEXT
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    HISTORY$PERIODSTART(RESOLUTION, HISTORY$EFFDEFAULT(RESOLUTION) || OFFSET)!

CREATE FUNCTION HISTORY$EXPPRIOR(RESOLUTION VARCHAR(11), OFFSET VARCHAR(100))
    RETURNS VARCHAR(100)
    SPECIFIC HISTORY$EXPPRIOR
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    HISTORY$PERIODEND(RESOLUTION, HISTORY$EFFDEFAULT(RESOLUTION) || ' - ' || HISTORY$PERIODLEN(RESOLUTION) || ' ' || OFFSET)!

CREATE FUNCTION HISTORY$INSERT(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11),
    OFFSET VARCHAR(100)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$INSERT
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE INSERT_STMT CLOB(64K) DEFAULT '';
    DECLARE VALUES_STMT CLOB(64K) DEFAULT '';
    SET INSERT_STMT = 'INSERT INTO ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE) || '(';
    SET VALUES_STMT = ' VALUES (';
    SET INSERT_STMT = INSERT_STMT || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION));
    SET VALUES_STMT = VALUES_STMT || HISTORY$EFFNEXT(RESOLUTION, OFFSET);
    FOR C AS
        SELECT COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        ORDER BY COLNO
    DO
        SET INSERT_STMT = INSERT_STMT || ',' || QUOTE_IDENTIFIER(C.COLNAME);
        SET VALUES_STMT = VALUES_STMT || ',NEW.' || QUOTE_IDENTIFIER(C.COLNAME);
    END FOR;
    SET INSERT_STMT = INSERT_STMT || ')';
    SET VALUES_STMT = VALUES_STMT || ')';
    RETURN INSERT_STMT || VALUES_STMT;
END!

CREATE FUNCTION HISTORY$EXPIRE(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11),
    OFFSET VARCHAR(100)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$EXPIRE
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE UPDATE_STMT CLOB(64K) DEFAULT '';
    SET UPDATE_STMT = 'UPDATE ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE)
        || ' SET '   || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ' = ' || HISTORY$EXPPRIOR(RESOLUTION, OFFSET)
        || ' WHERE ' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ' = ' || HISTORY$EXPDEFAULT(RESOLUTION);
    FOR C AS
        SELECT COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND COALESCE(KEYSEQ, 0) > 0
        ORDER BY COLNO
    DO
        SET UPDATE_STMT = UPDATE_STMT || ' AND ' || QUOTE_IDENTIFIER(C.COLNAME) || ' = OLD.' || QUOTE_IDENTIFIER(C.COLNAME);
    END FOR;
    RETURN UPDATE_STMT;
END!

CREATE FUNCTION HISTORY$UPDATE(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$UPDATE
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE UPDATE_STMT CLOB(64K) DEFAULT '';
    DECLARE SET_STMT CLOB(64K) DEFAULT '';
    DECLARE WHERE_STMT CLOB(64K) DEFAULT '';
    SET UPDATE_STMT = 'UPDATE ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE) || ' ';
    SET WHERE_STMT = ' WHERE ' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ' = ' || HISTORY$EXPDEFAULT(RESOLUTION);
    FOR C AS
        SELECT COALESCE(KEYSEQ, 0) AS KEYSEQ, COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        ORDER BY COLNO
    DO
        IF C.KEYSEQ = 0 THEN
            SET SET_STMT = SET_STMT || ', ' || QUOTE_IDENTIFIER(C.COLNAME) || ' = NEW.' || QUOTE_IDENTIFIER(C.COLNAME);
        ELSE
            SET WHERE_STMT = WHERE_STMT || ' AND ' || QUOTE_IDENTIFIER(C.COLNAME) || ' = OLD.' || QUOTE_IDENTIFIER(C.COLNAME);
        END IF;
    END FOR;
    SET SET_STMT = 'SET' || SUBSTR(SET_STMT, 2);
    RETURN UPDATE_STMT || SET_STMT || WHERE_STMT;
END!

CREATE FUNCTION HISTORY$DELETE(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$DELETE
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE DELETE_STMT CLOB(64K) DEFAULT '';
    DECLARE WHERE_STMT CLOB(64K) DEFAULT '';
    SET DELETE_STMT = 'DELETE FROM ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE);
    SET WHERE_STMT = ' WHERE ' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ' = ' || HISTORY$EXPDEFAULT(RESOLUTION);
    FOR C AS
        SELECT COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND COALESCE(KEYSEQ, 0) > 0
        ORDER BY COLNO
    DO
        SET WHERE_STMT = WHERE_STMT || ' AND ' || QUOTE_IDENTIFIER(C.COLNAME) || ' = OLD.' || QUOTE_IDENTIFIER(C.COLNAME);
    END FOR;
    RETURN DELETE_STMT || WHERE_STMT;
END!

CREATE FUNCTION HISTORY$CHECK(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$CHECK
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE SELECT_STMT CLOB(64K) DEFAULT '';
    DECLARE WHERE_STMT CLOB(64K) DEFAULT '';
    SET SELECT_STMT =
        'SELECT ' || HISTORY$PERIODEND(RESOLUTION, HISTORY$EFFNAME(RESOLUTION))
        || ' FROM ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE);
    SET WHERE_STMT =
        ' WHERE ' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ' = ' || HISTORY$EXPDEFAULT(RESOLUTION);
    FOR C AS
        SELECT COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND COALESCE(KEYSEQ, 0) > 0
        ORDER BY COLNO
    DO
        SET WHERE_STMT = WHERE_STMT || ' AND ' || QUOTE_IDENTIFIER(C.COLNAME) || ' = OLD.' || QUOTE_IDENTIFIER(C.COLNAME);
    END FOR;
    RETURN SELECT_STMT || WHERE_STMT;
END!

CREATE FUNCTION HISTORY$CHANGES(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$CHANGES
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE SELECT_STMT CLOB(64K) DEFAULT '';
    DECLARE FROM_STMT CLOB(64K) DEFAULT '';
    DECLARE INSERT_TEST CLOB(64K) DEFAULT '';
    DECLARE UPDATE_TEST CLOB(64K) DEFAULT '';
    DECLARE DELETE_TEST CLOB(64K) DEFAULT '';
    SET FROM_STMT =
        ' FROM ' || QUOTE_IDENTIFIER('OLD_' || SOURCE_TABLE) || ' AS OLD'
        || ' FULL OUTER JOIN ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE) || ' AS NEW'
        || ' ON NEW.' || HISTORY$EFFNAME(RESOLUTION) || ' '
        || CASE
            WHEN RESOLUTION IN ('MICROSECOND', 'SECOND', 'MINUTE', 'HOUR') THEN '- 1 MICROSECOND'
            WHEN RESOLUTION IN ('DAY', 'WEEK', 'WEEK_ISO', 'MONTH') THEN '- 1 DAY'
            ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
        END
        || ' BETWEEN OLD.' || HISTORY$EFFNAME(RESOLUTION) || ' AND OLD.' || HISTORY$EXPNAME(RESOLUTION);
    FOR C AS
        SELECT COALESCE(KEYSEQ, 0) AS KEYSEQ, COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND COLNAME <> HISTORY$EFFNAME(RESOLUTION)
        AND COLNAME <> HISTORY$EXPNAME(RESOLUTION)
        ORDER BY COLNO
    DO
        SET SELECT_STMT = SELECT_STMT
            || ', OLD.' || QUOTE_IDENTIFIER(C.COLNAME) || ' AS ' || QUOTE_IDENTIFIER('OLD_' || C.COLNAME)
            || ', NEW.' || QUOTE_IDENTIFIER(C.COLNAME) || ' AS ' || QUOTE_IDENTIFIER('NEW_' || C.COLNAME);
        IF C.KEYSEQ > 0 THEN
            SET FROM_STMT = FROM_STMT
                || ' AND OLD.' || QUOTE_IDENTIFIER(C.COLNAME) || ' = NEW.' || QUOTE_IDENTIFIER(C.COLNAME);
            SET INSERT_TEST = INSERT_TEST
                || 'AND OLD.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NULL '
                || 'AND NEW.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NOT NULL ';
            SET UPDATE_TEST = UPDATE_TEST
                || 'AND OLD.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NOT NULL '
                || 'AND NEW.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NOT NULL ';
            SET DELETE_TEST = DELETE_TEST
                || 'AND OLD.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NOT NULL '
                || 'AND NEW.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NULL ';
        END IF;
    END FOR;
    SET SELECT_STMT =
        'SELECT'
        || ' COALESCE(OLD.'
            || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ', NEW.'
            || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION)) || ') AS CHANGED'
        || ', CHAR(CASE '
            || 'WHEN' || SUBSTR(INSERT_TEST, 4) || 'THEN ''INSERT'' '
            || 'WHEN' || SUBSTR(UPDATE_TEST, 4) || 'THEN ''UPDATE'' '
            || 'WHEN' || SUBSTR(DELETE_TEST, 4) || 'THEN ''DELETE'' '
            || 'ELSE ''ERROR'' END) AS CHANGE'
        || SELECT_STMT;
    RETURN
        'WITH ' || QUOTE_IDENTIFIER('OLD_' || SOURCE_TABLE) || ' AS ('
        || '    SELECT *'
        || '    FROM ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE)
        || '    WHERE ' || HISTORY$EXPNAME(RESOLUTION) || ' < ' || HISTORY$EXPDEFAULT(RESOLUTION)
        || ') '
        || SELECT_STMT
        || FROM_STMT;
END!

CREATE FUNCTION HISTORY$SNAPSHOTS(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$SNAPSHOTS
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE SELECT_STMT CLOB(64K) DEFAULT '';
    SET SELECT_STMT =
        'WITH RANGE(D) AS ('
        || '    SELECT MIN(' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION)) || ')'
        || '    FROM ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE)
        || '    UNION ALL'
        || '    SELECT D + ' || HISTORY$PERIODLEN(RESOLUTION)
        || '    FROM RANGE'
        || '    WHERE D <= ' || HISTORY$EFFDEFAULT(RESOLUTION)
        || ') '
        || 'SELECT ' || HISTORY$PERIODEND(RESOLUTION, 'R.D') || ' AS SNAPSHOT';
    FOR C AS
        SELECT COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND COLNAME <> HISTORY$EFFNAME(RESOLUTION)
        AND COLNAME <> HISTORY$EXPNAME(RESOLUTION)
        ORDER BY COLNO
    DO
        SET SELECT_STMT = SELECT_STMT
            || ', H.' || QUOTE_IDENTIFIER(C.COLNAME);
    END FOR;
    RETURN SELECT_STMT
        || ' FROM RANGE R INNER JOIN ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE) || ' H'
        || ' ON R.D BETWEEN H.' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION))
        || ' AND H.' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION));
END!

CREATE FUNCTION HISTORY$UPDATE_FIELDS(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    KEY_FIELDS CHAR(1)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$UPDATE_FIELDS
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE RESULT CLOB(64K) DEFAULT '';
    IF NOT KEY_FIELDS IN ('N', 'Y') THEN
        SIGNAL SQLSTATE '70001'
        SET MESSAGE_TEXT = 'KEY_FIELDS must be N or Y';
    END IF;
    FOR C AS
        SELECT COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND (
            (KEY_FIELDS = 'Y' AND COALESCE(KEYSEQ, 0) > 0) OR
            (KEY_FIELDS = 'N' AND COALESCE(KEYSEQ, 0) = 0)
        )
        ORDER BY COLNO
    DO
        SET RESULT = RESULT || ', ' || QUOTE_IDENTIFIER(C.COLNAME);
    END FOR;
    RETURN SUBSTR(RESULT, 2);
END!

CREATE FUNCTION HISTORY$UPDATE_WHEN(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    KEY_FIELDS CHAR(1)
)
    RETURNS CLOB(64K)
    SPECIFIC HISTORY$UPDATE_WHEN
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE RESULT CLOB(64K) DEFAULT '';
    IF NOT KEY_FIELDS IN ('N', 'Y') THEN
        SIGNAL SQLSTATE '70001'
        SET MESSAGE_TEXT = 'KEY_FIELDS must be N or Y';
    END IF;
    FOR C AS
        SELECT COLNAME, NULLS
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND (
            (KEY_FIELDS = 'Y' AND COALESCE(KEYSEQ, 0) > 0) OR
            (KEY_FIELDS = 'N' AND COALESCE(KEYSEQ, 0) = 0)
        )
        ORDER BY COLNO
    DO
        SET RESULT = RESULT || ' OR OLD.' || QUOTE_IDENTIFIER(C.COLNAME) || ' <> NEW.' || QUOTE_IDENTIFIER(C.COLNAME);
        IF C.NULLS = 'Y' THEN
            SET RESULT = RESULT || ' OR (OLD.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NULL AND NEW.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NOT NULL)';
            SET RESULT = RESULT || ' OR (NEW.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NULL AND OLD.' || QUOTE_IDENTIFIER(C.COLNAME) || ' IS NOT NULL)';
        END IF;
    END FOR;
    RETURN SUBSTR(RESULT, 5);
END!

-- CREATE_HISTORY_TABLE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, DEST_TBSPACE, RESOLUTION)
-- CREATE_HISTORY_TABLE(SOURCE_TABLE, DEST_TABLE, DEST_TBSPACE, RESOLUTION)
-- CREATE_HISTORY_TABLE(SOURCE_TABLE, DEST_TABLE, RESOLUTION)
-- CREATE_HISTORY_TABLE(SOURCE_TABLE, RESOLUTION)
-------------------------------------------------------------------------------
-- The CREATE_HISTORY_TABLE procedure creates, from a template table specified
-- by SOURCE_SCHEMA and SOURCE_TABLE, another table named by DEST_SCHEMA and
-- DEST_TABLE designed to hold a representation of the source table's content
-- over time.  Specifically, the destination table has the same structure as
-- source table, but with two additional columns named EFFECTIVE_DATE and
-- EXPIRY_DATE which occur before all other "original" columns. The primary key
-- of the source table, in combination with EFFECTIVE_DATE will form the
-- primary key of the destination table, and a unique index involving the
-- primary key and the EXPIRY_DATE column will also be created as this provides
-- better performance of the triggers used to maintain the destination table.
--
-- The DEST_TBSPACE parameter identifies the tablespace used to store the new
-- table's data. If DEST_TBSPACE is not specified, it defaults to the
-- tablespace of the source table. If DEST_TABLE is not specified it defaults
-- to the value of SOURCE_TABLE with "_HISTORY" as a suffix. If DEST_SCHEMA and
-- SOURCE_SCHEMA are not specified they default to the current schema.
--
-- The RESOLUTION parameter determines the smallest unit of time that a history
-- record can cover. See the CREATE_HISTORY_TRIGGER documentation for a list of
-- the possible values.
--
-- All SELECT and CONTROL authorities present on the source table will be
-- copied to the destination table. However, INSERT, UPDATE and DELETE
-- authorities are excluded as these operations should only ever be performed
-- by the history maintenance triggers themselves.
--
-- If the specified table already exists, this procedure will replace it,
-- potentially losing all its content. If the existing history data is
-- important to you, make sure you back it up before executing this procedure.
-------------------------------------------------------------------------------

CREATE PROCEDURE CREATE_HISTORY_TABLE(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    DEST_TBSPACE VARCHAR(18),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_TABLE1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE KEY_COLS CLOB(64K) DEFAULT '';
    DECLARE INC_COLS CLOB(64K) DEFAULT '';
    DECLARE DDL CLOB(64K) DEFAULT '';
    DECLARE SAVE_PATH VARCHAR(254);
    DECLARE SAVE_SCHEMA VARCHAR(128);
    DECLARE PK_CLUSTERED CHAR(1) DEFAULT 'N';
    DECLARE TAB_COMPRESSED CHAR(1) DEFAULT 'N';
    -- Check the source table has a primary key
    IF (SELECT COALESCE(KEYCOLUMNS, 0)
        FROM SYSCAT.TABLES
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE) = 0 THEN
        SIGNAL SQLSTATE '70001'
        SET MESSAGE_TEXT = 'Source table must have a primary key';
    END IF;
    SET TAB_COMPRESSED = (
        SELECT
            CASE COMPRESSION
                WHEN 'R' THEN 'Y'
                WHEN 'B' THEN 'Y'
                ELSE 'N'
            END
        FROM SYSCAT.TABLES
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
    );
    SET PK_CLUSTERED = (
        SELECT
            CASE INDEXTYPE
                WHEN 'CLUS' THEN 'Y'
                ELSE 'N'
            END
        FROM SYSCAT.INDEXES
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND UNIQUERULE = 'P'
    );
    -- Drop any existing table with the same name as the destination table
    FOR D AS
        SELECT
            'DROP TABLE ' || QUOTE_IDENTIFIER(TABSCHEMA) || '.' || QUOTE_IDENTIFIER(TABNAME) AS DROP_CMD
        FROM
            SYSCAT.TABLES
        WHERE
            TABSCHEMA = DEST_SCHEMA
            AND TABNAME = DEST_TABLE
            AND TYPE = 'T'
    DO
        EXECUTE IMMEDIATE D.DROP_CMD;
    END FOR;
    -- Calculate comma-separated lists of key columns and include columns for
    -- later use in index and key statements
    FOR C AS
        SELECT
            CASE ICU.COLORDER
                WHEN 'I' THEN 'N'
                ELSE 'Y'
            END AS KEYCOL,
            ICU.COLNAME
        FROM
            SYSCAT.INDEXCOLUSE ICU
            INNER JOIN SYSCAT.INDEXES IND
                ON IND.INDSCHEMA = ICU.INDSCHEMA
                AND IND.INDNAME = ICU.INDNAME
        WHERE
            IND.TABSCHEMA = SOURCE_SCHEMA
            AND IND.TABNAME = SOURCE_TABLE
            AND IND.UNIQUERULE = 'P'
        ORDER BY
            ICU.COLSEQ
        FETCH FIRST 62 ROWS ONLY
    DO
        IF KEYCOL = 'Y' THEN
            SET KEY_COLS = KEY_COLS || QUOTE_IDENTIFIER(COLNAME) || ',';
        ELSE
            SET INC_COLS = INC_COLS || QUOTE_IDENTIFIER(COLNAME) || ',';
        END IF;
    END FOR;
    -- Create the history table based on the source table
    SET DDL =
        'CREATE TABLE ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE) || ' AS '
        || '('
        || '    SELECT'
        || '        ' || HISTORY$EFFDEFAULT(RESOLUTION) || ' AS ' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION)) || ','
        || '        ' || HISTORY$EXPDEFAULT(RESOLUTION) || ' AS ' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ','
        || '        T.*'
        || '    FROM '
        ||          QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE) || ' AS T'
        || ')'
        || 'WITH NO DATA IN ' || DEST_TBSPACE || ' '
        || 'COMPRESS ' || CASE TAB_COMPRESSED WHEN 'Y' THEN 'YES' ELSE 'NO' END;
    EXECUTE IMMEDIATE DDL;
    -- Create two unique indexes, both based on the source table's primary key,
    -- plus the EFFECTIVE and EXPIRY fields respectively. Use INCLUDE for
    -- additional small fields in the EFFECTIVE index. The columns included are
    -- the same as those included in the primary key of the source table.
    SET DDL =
        'CREATE UNIQUE INDEX ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE || '_PK') || ' '
        || 'ON ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE)
        || '(' || KEY_COLS || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION))
        || ') INCLUDE (' || INC_COLS || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ') '
        || CASE PK_CLUSTERED WHEN 'Y' THEN 'CLUSTER' ELSE '' END;
    EXECUTE IMMEDIATE DDL;
    SET DDL =
        'CREATE UNIQUE INDEX ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE || '_PK2') || ' '
        || 'ON ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE)
        || '(' || KEY_COLS || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION))
        || ')';
    EXECUTE IMMEDIATE DDL;
    -- Create additional indexes that are useful for performance purposes
    SET DDL =
        'CREATE INDEX ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE || '_IX1') || ' '
        || 'ON ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE)
        || '(' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION)) || ', ' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION))
        || ')';
    EXECUTE IMMEDIATE DDL;
    -- Create a primary key with the same fields as the EFFECTIVE index defined
    -- above.
    SET DDL =
        'ALTER TABLE ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE) || ' '
        || 'ADD CONSTRAINT PK PRIMARY KEY (' || KEY_COLS || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION)) || ') '
        || 'ADD CONSTRAINT EXPIRY_CK CHECK (' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION)) || ' <= ' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ') '
        || 'ALTER COLUMN ' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION)) || ' SET DEFAULT ' || HISTORY$EFFDEFAULT(RESOLUTION) || ' '
        || 'ALTER COLUMN ' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION)) || ' SET DEFAULT ' || HISTORY$EXPDEFAULT(RESOLUTION);
    EXECUTE IMMEDIATE DDL;
    -- Copy CHECK constraints from the source table to the history table. Note
    -- that we do not copy FOREIGN KEY constraints as there's no good method of
    -- matching a parent record in a historized table.
    SET SAVE_PATH = CURRENT PATH;
    SET SAVE_SCHEMA = CURRENT SCHEMA;
    FOR C AS
        SELECT
            'SET SCHEMA '  || QUOTE_IDENTIFIER(QUALIFIER)       AS SET_SCHEMA,
            'SET PATH '    || FUNC_PATH                         AS SET_PATH,
            'ALTER TABLE ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE)
                || ' ADD CONSTRAINT ' || QUOTE_IDENTIFIER(CONSTNAME)
                || ' CHECK (' || TEXT || ')'                    AS CREATE_CONST,
            'SET SCHEMA '  || QUOTE_IDENTIFIER(SAVE_SCHEMA)     AS RESTORE_SCHEMA,
            'SET PATH '    || SAVE_PATH                         AS RESTORE_PATH
        FROM
            SYSCAT.CHECKS
        WHERE
            TABSCHEMA = SOURCE_SCHEMA
            AND TABNAME = SOURCE_TABLE
            AND TYPE = 'C'
    DO
        EXECUTE IMMEDIATE C.SET_PATH;
        EXECUTE IMMEDIATE C.SET_SCHEMA;
        EXECUTE IMMEDIATE C.CREATE_CONST;
        EXECUTE IMMEDIATE C.RESTORE_PATH;
        EXECUTE IMMEDIATE C.RESTORE_SCHEMA;
    END FOR;
    -- Store the source table's authorizations, then redirect them to the
    -- destination table filtering out those authorizations which should be
    -- excluded
    CALL SAVE_AUTH(SOURCE_SCHEMA, SOURCE_TABLE);
    UPDATE SAVED_AUTH SET
        TABSCHEMA = DEST_SCHEMA,
        TABNAME = DEST_TABLE,
        DELETEAUTH = 'N',
        INSERTAUTH = 'N',
        UPDATEAUTH = 'N'
    WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE;
    CALL RESTORE_AUTH(DEST_SCHEMA, DEST_TABLE);
    -- Set up comments for the effective and expiry fields then copy the
    -- comments for all fields from the source table
    SET DDL = 'COMMENT ON COLUMN '
        || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE) || '.' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(RESOLUTION))
        || ' IS ' || QUOTE_STRING('The date/timestamp from which this row was present in the source table');
    EXECUTE IMMEDIATE DDL;
    SET DDL = 'COMMENT ON COLUMN '
        || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE) || '.' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(RESOLUTION))
        || ' IS ' || QUOTE_STRING('The date/timestamp until which this row was present in the source table (rows with 9999-12-31 currently exist in the source table)');
    EXECUTE IMMEDIATE DDL;
    SET DDL = 'COMMENT ON TABLE '
        || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE)
        || ' IS ' || QUOTE_STRING('History table which tracks the content of @' || SOURCE_SCHEMA || '.' || SOURCE_TABLE);
    EXECUTE IMMEDIATE DDL;
    FOR C AS
        SELECT
            VARCHAR('COMMENT ON COLUMN '
                || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE) || '.' || QUOTE_IDENTIFIER(COLNAME)
                || ' IS ' || QUOTE_STRING(REMARKS)) AS COMMENT_STMT
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND REMARKS IS NOT NULL
    DO
        EXECUTE IMMEDIATE C.COMMENT_STMT;
    END FOR;
END!

CREATE PROCEDURE CREATE_HISTORY_TABLE(
    SOURCE_TABLE VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    DEST_TBSPACE VARCHAR(18),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_TABLE2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_TABLE(CURRENT SCHEMA, SOURCE_TABLE, CURRENT SCHEMA, DEST_TABLE, DEST_TBSPACE, RESOLUTION);
END!

CREATE PROCEDURE CREATE_HISTORY_TABLE(
    SOURCE_TABLE VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_TABLE3
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_TABLE(SOURCE_TABLE, DEST_TABLE, (
        SELECT TBSPACE
        FROM SYSCAT.TABLES
        WHERE TABSCHEMA = CURRENT SCHEMA
        AND TABNAME = SOURCE_TABLE
    ), RESOLUTION);
END!

CREATE PROCEDURE CREATE_HISTORY_TABLE(SOURCE_TABLE VARCHAR(128), RESOLUTION VARCHAR(11))
    SPECIFIC CREATE_HISTORY_TABLE4
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_TABLE(SOURCE_TABLE, SOURCE_TABLE || '_HISTORY', RESOLUTION);
END!

COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_TABLE1
    IS 'Creates a temporal history table based on the structure of the specified table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_TABLE2
    IS 'Creates a temporal history table based on the structure of the specified table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_TABLE3
    IS 'Creates a temporal history table based on the structure of the specified table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_TABLE4
    IS 'Creates a temporal history table based on the structure of the specified table'!

-- CREATE_HISTORY_CHANGES(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_VIEW, RESOLUTION)
-- CREATE_HISTORY_CHANGES(SOURCE_TABLE, DEST_VIEW, RESOLUTION)
-- CREATE_HISTORY_CHANGES(SOURCE_TABLE, RESOLUTION)
-------------------------------------------------------------------------------
-- The CREATE_HISTORY_CHANGES procedure creates a view on top of a history
-- table which is assumed to have a structure generated by
-- CREATE_HISTORY_TABLE.  The view represents the history data as a series of
-- "change" rows. The EFFECTIVE and EXPIRY columns from the source history
-- table are merged into a "CHANGED" column while all other columns are
-- represented twice as an "OLD_" and "NEW_" variant.
--
-- If DEST_VIEW is not specified it defaults to the value of SOURCE_TABLE with
-- "_HISTORY" replaced with "_CHANGES". If DEST_SCHEMA and SOURCE_SCHEMA are
-- not specified they default to the current schema.
--
-- The RESOLUTION parameter determines the smallest unit of time that a history
-- record can cover. See the CREATE_HISTORY_TRIGGERS documentation for a list
-- of the possible values.
--
-- All SELECT and CONTROL authorities present on the source table will be
-- copied to the destination table.
--
-- The type of change can be determined by querying the NULL state of the old
-- and new key columns. For example:
--
-- INSERT
-- If the old key or keys are NULL and the new are non-NULL, the change was an
-- insertion.
--
-- UPDATE
-- If both the old and new key or keys are non-NULL, the change was an update.
--
-- DELETE
-- If the old key or keys are non-NULL and the new are NULL, the change was a
-- deletion.
-------------------------------------------------------------------------------

CREATE PROCEDURE CREATE_HISTORY_CHANGES(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_VIEW VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_CHANGES1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE DDL CLOB(64K) DEFAULT '';
    SET DDL =
        'CREATE VIEW ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || ' AS '
        || HISTORY$CHANGES(SOURCE_SCHEMA, SOURCE_TABLE, RESOLUTION);
    EXECUTE IMMEDIATE DDL;
    -- Store the source table's authorizations, then redirect them to the
    -- destination table filtering out those authorizations which should be
    -- excluded
    CALL SAVE_AUTH(SOURCE_SCHEMA, SOURCE_TABLE);
    UPDATE SAVED_AUTH SET
        TABSCHEMA = DEST_SCHEMA,
        TABNAME = DEST_VIEW,
        DELETEAUTH = 'N',
        INSERTAUTH = 'N',
        UPDATEAUTH = 'N',
        INDEXAUTH = 'N',
        REFAUTH = 'N'
    WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE;
    CALL RESTORE_AUTH(DEST_SCHEMA, DEST_VIEW);
    -- Set up comments for the effective and expiry fields then copy the
    -- comments for all fields from the source table
    SET DDL = 'COMMENT ON COLUMN '
        || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || '.' || QUOTE_IDENTIFIER('CHANGED')
        || ' IS ' || QUOTE_STRING('The date/timestamp on which this row changed');
    EXECUTE IMMEDIATE DDL;
    SET DDL = 'COMMENT ON TABLE '
        || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW)
        || ' IS ' || QUOTE_STRING('View showing the content of @' || SOURCE_SCHEMA || '.' || SOURCE_TABLE || ' as a series of changes');
    EXECUTE IMMEDIATE DDL;
    FOR C AS
        SELECT
            VARCHAR('COMMENT ON COLUMN '
                || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || '.' || QUOTE_IDENTIFIER('OLD_' || COLNAME)
                || ' IS ' || QUOTE_STRING('Value of @' || SOURCE_SCHEMA || '.' || SOURCE_TABLE || '.' || COLNAME || ' prior to change')) AS COMMENT_OLD_STMT,
            VARCHAR('COMMENT ON COLUMN '
                || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || '.' || QUOTE_IDENTIFIER('NEW_' || COLNAME)
                || ' IS ' || QUOTE_STRING('Value of @' || SOURCE_SCHEMA || '.' || SOURCE_TABLE || '.' || COLNAME || ' after change')) AS COMMENT_NEW_STMT
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND REMARKS IS NOT NULL
        AND COLNO >= 2
    DO
        EXECUTE IMMEDIATE C.COMMENT_OLD_STMT;
        EXECUTE IMMEDIATE C.COMMENT_NEW_STMT;
    END FOR;
END!

CREATE PROCEDURE CREATE_HISTORY_CHANGES(
    SOURCE_TABLE VARCHAR(128),
    DEST_VIEW VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_CHANGES2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_CHANGES(CURRENT SCHEMA, SOURCE_TABLE, CURRENT SCHEMA, DEST_VIEW, RESOLUTION);
END!

CREATE PROCEDURE CREATE_HISTORY_CHANGES(
    SOURCE_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_CHANGES3
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_CHANGES(SOURCE_TABLE, REPLACE(SOURCE_TABLE, '_HISTORY', '_CHANGES'), RESOLUTION);
END!

COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_CHANGES1
    IS 'Creates an "OLD vs NEW" changes view on top of the specified history table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_CHANGES2
    IS 'Creates an "OLD vs NEW" changes view on top of the specified history table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_CHANGES3
    IS 'Creates an "OLD vs NEW" changes view on top of the specified history table'!

-- CREATE_HISTORY_SNAPSHOTS(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_VIEW, RESOLUTION)
-- CREATE_HISTORY_SNAPSHOTS(SOURCE_TABLE, DEST_VIEW, RESOLUTION)
-- CREATE_HISTORY_SNAPSHOTS(SOURCE_TABLE, RESOLUTION)
-------------------------------------------------------------------------------
-- The CREATE_HISTORY_SNAPSHOTS procedure creates a view on top of a history
-- table which is assumed to have a structure generated by
-- CREATE_HISTORY_TABLE.  The view represents the history data as a series of
-- "snapshots" of the main table at various points through time. The EFFECTIVE
-- and EXPIRY columns from the source history table are replaced with a
-- "SNAPSHOT" column which indicates the timestamp or date of the snapshot of
-- the main table. All other columns are represented in their original form.
--
-- If DEST_VIEW is not specified it defaults to the value of SOURCE_TABLE with
-- "_HISTORY" replaced with a custom suffix which depends on the value of
-- RESOLUTION. For example, if RESOLUTION is "MONTH" then the suffix is
-- "MONTHLY", if RESOLUTION is "WEEK", or "WEEK_ISO" then the suffix is
-- "WEEKLY" and so on. If DEST_SCHEMA and SOURCE_SCHEMA are not specified they
-- default to the current schema.
--
-- The RESOLUTION parameter determines the amount of time between snapshots.
-- Snapshots will be generated for the end of each period given by a particular
-- RESOLUTION. For example, if RESOLUTION is "WEEK" then a snapshot will be
-- generated for the end of each week according to the WEEKEND function from
-- the earilest record in the history table up to the current date. See the
-- CREATE_HISTORY_TRIGGER documentation for a list of the possible values.
--
-- All SELECT and CONTROL authorities present on the source table will be
-- copied to the destination table.
-------------------------------------------------------------------------------

CREATE PROCEDURE CREATE_HISTORY_SNAPSHOTS(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_VIEW VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_SNAPSHOTS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE DDL CLOB(64K) DEFAULT '';
    SET DDL =
        'CREATE VIEW ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || ' AS '
        || HISTORY$SNAPSHOTS(SOURCE_SCHEMA, SOURCE_TABLE, RESOLUTION);
    EXECUTE IMMEDIATE DDL;
    -- Store the source table's authorizations, then redirect them to the
    -- destination table filtering out those authorizations which should be
    -- excluded
    CALL SAVE_AUTH(SOURCE_SCHEMA, SOURCE_TABLE);
    UPDATE SAVED_AUTH SET
        TABSCHEMA = DEST_SCHEMA,
        TABNAME = DEST_VIEW,
        DELETEAUTH = 'N',
        INSERTAUTH = 'N',
        UPDATEAUTH = 'N',
        INDEXAUTH = 'N',
        REFAUTH = 'N'
    WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE;
    CALL RESTORE_AUTH(DEST_SCHEMA, DEST_VIEW);
    -- Set up comments for the effective and expiry fields then copy the
    -- comments for all fields from the source table
    SET DDL = 'COMMENT ON COLUMN '
        || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || '.' || QUOTE_IDENTIFIER('SNAPSHOT')
        || ' IS ' || QUOTE_STRING('The date/timestamp of this row''s snapshot');
    EXECUTE IMMEDIATE DDL;
    SET DDL = 'COMMENT ON TABLE '
        || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW)
        || ' IS ' || QUOTE_STRING('View showing the content of @' || SOURCE_SCHEMA || '.' || SOURCE_TABLE || ' as a series of snapshots');
    EXECUTE IMMEDIATE DDL;
    FOR C AS
        SELECT
            VARCHAR('COMMENT ON COLUMN '
                || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || '.' || QUOTE_IDENTIFIER('OLD_' || COLNAME)
                || ' IS ' || QUOTE_STRING('Value of @' || SOURCE_SCHEMA || '.' || SOURCE_TABLE || '.' || COLNAME || ' at the time of the snapshot')) AS COMMENT_STMT
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND REMARKS IS NOT NULL
        AND COLNO >= 2
    DO
        EXECUTE IMMEDIATE C.COMMENT_STMT;
    END FOR;
END!

CREATE PROCEDURE CREATE_HISTORY_SNAPSHOTS(
    SOURCE_TABLE VARCHAR(128),
    DEST_VIEW VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_SNAPSHOTS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_SNAPSHOTS(CURRENT SCHEMA, SOURCE_TABLE, CURRENT SCHEMA, DEST_VIEW, RESOLUTION);
END!

CREATE PROCEDURE CREATE_HISTORY_SNAPSHOTS(
    SOURCE_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_SNAPSHOTS3
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_SNAPSHOTS(SOURCE_TABLE,
        REPLACE(SOURCE_TABLE, '_HISTORY',
        CASE RESOLUTION
            WHEN 'MICROSECOND' THEN '_MICROSECONDLY'
            WHEN 'SECOND'      THEN '_SECONDLY'
            WHEN 'MINUTE'      THEN '_MINUTELY'
            WHEN 'HOUR'        THEN '_HOURLY'
            WHEN 'DAY'         THEN '_DAILY'
            WHEN 'WEEK'        THEN '_WEEKLY'
            WHEN 'WEEK_ISO'    THEN '_WEEKLY'
            WHEN 'MONTH'       THEN '_MONTHLY'
            ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
        END), RESOLUTION);
END!

COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_SNAPSHOTS1
    IS 'Creates an exploded view of the specified history table with one row per entity per resolution time-slice (e.g. daily, monthly, yearly, etc.)'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_SNAPSHOTS2
    IS 'Creates an exploded view of the specified history table with one row per entity per resolution time-slice (e.g. daily, monthly, yearly, etc.)'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_SNAPSHOTS3
    IS 'Creates an exploded view of the specified history table with one row per entity per resolution time-slice (e.g. daily, monthly, yearly, etc.)'!

-- CREATE_HISTORY_TRIGGERS(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION, OFFSET)
-- CREATE_HISTORY_TRIGGERS(SOURCE_TABLE, DEST_TABLE, RESOLUTION, OFFSET)
-- CREATE_HISTORY_TRIGGERS(SOURCE_TABLE, RESOLUTION, OFFSET)
-- CREATE_HISTORY_TRIGGERS(SOURCE_TABLE, RESOLUTION)
-------------------------------------------------------------------------------
-- The CREATE_HISTORY_TRIGGERS procedure creates several trigger linking the
-- specified source table to the destination table which is assumed to have a
-- structure compatible with the result of running CREATE_HISTORY_TABLE above,
-- i.e. two extra columns called EFFECTIVE_DATE and EXPIRY_DATE.
--
-- If DEST_TABLE is not specified it defaults to the value of SOURCE_TABLE with
-- "_HISTORY" as a suffix. If DEST_SCHEMA and SOURCE_SCHEMA are not specified
-- they default to the current schema.
--
-- The RESOLUTION parameter specifies the smallest unit of time that a history
-- entry can cover. This is effectively used to quantize the history. The value
-- given for the RESOLUTION parameter should match the value given as the
-- RESOLUTION parameter to the CREATE_HISTORY_TABLE procedure. The values
-- which can be specified are as follows:
--
-- 'MICROSECOND'
-- With this value, the triggers perform no explicit quantization. Instead,
-- history records are constrained simply by the resolution of the TIMESTAMP
-- datatype, currently microseconds.
--
-- 'SECOND'
-- Quantizes history into individual seconds. If multiple changes occur to
-- the master record within a single second, only the final state is kept
-- in the history table.
--
-- 'MINUTE'
-- Quantizes history into individual minutes.
--
-- 'HOUR'
-- Quantizes history into individual hours.
--
-- 'DAY'
-- Quantizes history into individual days. If multiple changes occur to the
-- master record within a single day, as defined by the CURRENT DATE special
-- register, only the final state is kept in the history table.
--
-- 'WEEK'
-- Quantizes history into blocks starting on a Sunday and ending on a Saturday.
--
-- 'WEEK_ISO'
-- Quantizes history into blocks starting on a Monday and ending on a Sunday.
--
-- 'MONTH'
-- Quantizes history into blocks starting on the 1st of a month and ending
-- on the last day of the corresponding month.
--
-- 'YEAR'
-- Quantizes history into blocks starting on the 1st of a year and ending on
-- the last day of the corresponding year.
--
-- The OFFSET parameter specifies an SQL phrase that will be used to offset the
-- effective dates of new history records. For example, if the source table is
-- only updated a week in arrears, then OFFSET could be set to '- 7 DAYS' to
-- cause the effective dates to be accurate.
-------------------------------------------------------------------------------

CREATE PROCEDURE CREATE_HISTORY_TRIGGERS(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11),
    OFFSET VARCHAR(100)
)
    SPECIFIC CREATE_HISTORY_TRIGGERS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE DDL CLOB(64K) DEFAULT '';
    -- Drop any existing triggers with the same name as the destination
    -- triggers
    FOR D AS
        SELECT
            'DROP TRIGGER ' || QUOTE_IDENTIFIER(TRIGSCHEMA) || '.' || QUOTE_IDENTIFIER(TRIGNAME) AS DROP_CMD
        FROM
            SYSCAT.TRIGGERS
        WHERE
            TABSCHEMA = SOURCE_SCHEMA
            AND TABNAME = SOURCE_TABLE
            AND TRIGSCHEMA = SOURCE_SCHEMA
            AND TRIGNAME IN (
                SOURCE_TABLE || '_KEYCHG',
                SOURCE_TABLE || '_INSERT',
                SOURCE_TABLE || '_UPDATE',
                SOURCE_TABLE || '_DELETE'
            )
    DO
        EXECUTE IMMEDIATE D.DROP_CMD;
    END FOR;
    -- Create the KEYCHG trigger
    SET DDL =
        'CREATE TRIGGER ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE || '_KEYCHG')
        || '    NO CASCADE BEFORE UPDATE OF '
        ||          HISTORY$UPDATE_FIELDS(SOURCE_SCHEMA, SOURCE_TABLE, CHAR('Y'))
        || '    ON ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE)
        || '    REFERENCING OLD AS OLD NEW AS NEW'
        || '    FOR EACH ROW '
        || 'WHEN ('
        ||      HISTORY$UPDATE_WHEN(SOURCE_SCHEMA, SOURCE_TABLE, CHAR('Y'))
        || ') '
        || 'BEGIN ATOMIC'
        || '    SIGNAL SQLSTATE ''75001'''
        || '        SET MESSAGE_TEXT = ''Cannot update unique key of a ' || REPLACE(QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE), '''', '''''') || ' row''; '
        || 'END';
    EXECUTE IMMEDIATE DDL;
    -- Create the INSERT trigger
    SET DDL =
        'CREATE TRIGGER ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE || '_INSERT')
        || '    AFTER INSERT ON ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE)
        || '    REFERENCING NEW AS NEW'
        || '    FOR EACH ROW '
        || 'BEGIN ATOMIC '
        ||      HISTORY$INSERT(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION, OFFSET) || ';'
        || 'END';
    EXECUTE IMMEDIATE DDL;
    -- Create the UPDATE trigger
    SET DDL =
        'CREATE TRIGGER ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE || '_UPDATE')
        || '    AFTER UPDATE OF '
        ||          HISTORY$UPDATE_FIELDS(SOURCE_SCHEMA, SOURCE_TABLE, CHAR('N'))
        || '    ON ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE)
        || '    REFERENCING OLD AS OLD NEW AS NEW'
        || '    FOR EACH ROW '
        || 'WHEN ('
        ||      HISTORY$UPDATE_WHEN(SOURCE_SCHEMA, SOURCE_TABLE, CHAR('N'))
        || ') '
        || 'BEGIN ATOMIC'
        || '    DECLARE CHK_DATE DATE;'
        || '    SET CHK_DATE = ('
        ||          HISTORY$CHECK(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION)
        || '    );'
        || '    IF ' || HISTORY$EFFNEXT(RESOLUTION, OFFSET) || ' > CHK_DATE THEN '
        ||          HISTORY$EXPIRE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION, OFFSET) || ';'
        ||          HISTORY$INSERT(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION, OFFSET) || ';'
        || '    ELSE '
        ||          HISTORY$UPDATE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION) || ';'
        || '    END IF; '
        || 'END';
    EXECUTE IMMEDIATE DDL;
    -- Create the DELETE trigger
    SET DDL =
        'CREATE TRIGGER ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE || '_DELETE')
        || '    AFTER DELETE ON ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE)
        || '    REFERENCING OLD AS OLD'
        || '    FOR EACH ROW '
        || 'BEGIN ATOMIC'
        || '    DECLARE CHK_DATE DATE;'
        || '    SET CHK_DATE = ('
        ||          HISTORY$CHECK(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION)
        || '    );'
        || '    IF ' || HISTORY$EFFNEXT(RESOLUTION, OFFSET) || ' > CHK_DATE THEN '
        ||          HISTORY$EXPIRE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION, OFFSET) || ';'
        || '    ELSE '
        ||          HISTORY$DELETE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, RESOLUTION) || ';'
        || '    END IF; '
        || 'END';
    EXECUTE IMMEDIATE DDL;
END!

CREATE PROCEDURE CREATE_HISTORY_TRIGGERS(
    SOURCE_TABLE VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11),
    OFFSET VARCHAR(100)
)
    SPECIFIC CREATE_HISTORY_TRIGGERS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_TRIGGERS(CURRENT SCHEMA, SOURCE_TABLE, CURRENT SCHEMA, DEST_TABLE, RESOLUTION, OFFSET);
END!

CREATE PROCEDURE CREATE_HISTORY_TRIGGERS(
    SOURCE_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11),
    OFFSET VARCHAR(100)
)
    SPECIFIC CREATE_HISTORY_TRIGGERS3
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_TRIGGERS(SOURCE_TABLE, SOURCE_TABLE || '_HISTORY', RESOLUTION, OFFSET);
END!

CREATE PROCEDURE CREATE_HISTORY_TRIGGERS(
    SOURCE_TABLE VARCHAR(128),
    RESOLUTION VARCHAR(11)
)
    SPECIFIC CREATE_HISTORY_TRIGGERS4
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_TRIGGERS(SOURCE_TABLE, SOURCE_TABLE || '_HISTORY', RESOLUTION, '');
END!

COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_TRIGGERS1
    IS 'Creates the triggers to link the specified table to its corresponding history table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_TRIGGERS2
    IS 'Creates the triggers to link the specified table to its corresponding history table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_TRIGGERS3
    IS 'Creates the triggers to link the specified table to its corresponding history table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_HISTORY_TRIGGERS4
    IS 'Creates the triggers to link the specified table to its corresponding history table'!

-- vim: set et sw=4 sts=4:
