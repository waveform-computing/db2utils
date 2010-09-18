-------------------------------------------------------------------------------
-- EXCEPTIONS TABLE UTILITIES
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
-- The following code is adapted from the examples in the Exceptions Tables
-- section of the DB2 InfoCenter. Stored procedures are provided for creating
-- exceptions tables and analysis views based on existing tables.
-------------------------------------------------------------------------------

-- CREATE_EXCEPTION_TABLE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, DEST_TBSPACE)
-- CREATE_EXCEPTION_TABLE(SOURCE_TABLE, DEST_TABLE, DEST_TBSPACE)
-- CREATE_EXCEPTION_TABLE(SOURCE_TABLE, DEST_TABLE)
-- CREATE_EXCEPTION_TABLE(SOURCE_TABLE)
-------------------------------------------------------------------------------
-- The CREATE_EXCEPTION_TABLE procedure creates, from a template table
-- (specified by SOURCE_SCHEMA and SOURCE_TABLE), another table (named by
-- DEST_SCHEMA and DEST_TABLE) designed to hold LOAD and SET INTEGRITY
-- exceptions from the template table. The new table is identical to the
-- template table, but contains two extra fields: EXCEPT_MSG (which stores
-- information about the exception that occurred when loading or setting the
-- integrity of the table), and EXCEPT_TS, a TIMESTAMP field indicating when
-- the exception the occurred.
--
-- The DEST_TBSPACE parameter identifies the tablespace used to store the new
-- table's data. As exceptions data is not typically considered performance
-- critical, and is generally not expected to be large, an SMS tablespace
-- should be utilized for the new table.
--
-- Only the SOURCE_TABLE parameter is mandatory. All other parameters are
-- optional.  If DEST_TBSPACE is not specified, it defaults to the tablespace
-- of the source table. If DEST_TABLE is not specified it defaults to the value
-- of SOURCE_TABLE. If DEST_SCHEMA is not specified it defaults to the
-- EXCEPTIONS schema. If SOURCE_SCHEMA is not specified, it defaults to the
-- current schema.
--
-- All SELECT and CONTROL authorities present on the source table will be
-- copied to the destination table.
--
-- If the specified table already exists, this procedure will replace it,
-- potentially losing all its content. If the existing exceptions data is
-- important to you, make sure you back it up before executing this procedure.
-------------------------------------------------------------------------------

CREATE PROCEDURE CREATE_EXCEPTION_TABLE(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    DEST_TBSPACE VARCHAR(18)
)
    SPECIFIC CREATE_EXCEPTION_TABLE1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE DDL CLOB(64K) DEFAULT '';
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
    -- Create the exceptions table based on the source table
    SET DDL =
        'CREATE TABLE ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_TABLE) || ' AS '
        || '('
        || '    SELECT'
        || '        T.*,'
        || '        CAST(NULL AS TIMESTAMP) AS EXCEPT_TS,'
        || '        CAST(NULL AS CLOB(32K)) AS EXCEPT_MSG'
        || '    FROM '
        ||          QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE) || ' AS T'
        || ')'
        || 'WITH NO DATA IN ' || DEST_TBSPACE;
    EXECUTE IMMEDIATE DDL;
    -- Store the source table's authorizations, then redirect them to the
    -- destination table
    CALL SAVE_AUTH(SOURCE_SCHEMA, SOURCE_TABLE);
    UPDATE SAVED_AUTH SET
        TABSCHEMA = DEST_SCHEMA,
        TABNAME = DEST_TABLE
    WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE;
    CALL RESTORE_AUTH(DEST_SCHEMA, DEST_TABLE);
END!

CREATE PROCEDURE CREATE_EXCEPTION_TABLE(
    SOURCE_TABLE VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    DEST_TBSPACE VARCHAR(18)
)
    SPECIFIC CREATE_EXCEPTION_TABLE2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_TABLE(
        CURRENT SCHEMA,
        SOURCE_TABLE,
        'EXCEPTIONS',
        DEST_TABLE,
        DEST_TBSPACE
    );
END!

CREATE PROCEDURE CREATE_EXCEPTION_TABLE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128))
    SPECIFIC CREATE_EXCEPTION_TABLE3
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_TABLE(SOURCE_TABLE, DEST_TABLE, (
        SELECT TBSPACE
        FROM SYSCAT.TABLES
        WHERE TABSCHEMA = CURRENT SCHEMA
        AND TABNAME = SOURCE_TABLE
    ));
END!

CREATE PROCEDURE CREATE_EXCEPTION_TABLE(SOURCE_TABLE VARCHAR(128))
    SPECIFIC CREATE_EXCEPTION_TABLE4
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_TABLE(SOURCE_TABLE, SOURCE_TABLE);
END!

-- CREATE_EXCEPTION_VIEW(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_VIEW)
-- CREATE_EXCEPTION_VIEW(SOURCE_TABLE, DEST_VIEW)
-- CREATE_EXCEPTION_VIEW(SOURCE_TABLE)
-------------------------------------------------------------------------------
-- The CREATE_EXCEPTION_VIEW procedure creates a view on top of an exceptions
-- table. The view uses a recursive common-table-expression to split the large
-- EXCEPT_MSG field into several rows and several columns to allow for easier
-- analysis. Instead of EXCEPT_MSG, the view contains the following
-- exceptions-related fields:
--
-- EXCEPT_TYPE
--     K - check constraint violation
--     F - foreign key violation
--     G - generated column violation
--     I - unique index violation
--     L - datalink load violation
--     D - cascaded deletion violation
--
-- EXCEPT_OBJECT
--     The fully qualified name of the object that caused the exception (e.g.
--     the name of the check constraint, foreign key, column or unique index)
--
-- Like the CREATE_EXCEPTION_TABLE procedure, this procedure has only one
-- mandatory parameter: SOURCE_TABLE. If SOURCE_SCHEMA and DEST_SCHEMA are not
-- specified, they default to the current schema. If DEST_VIEW is not
-- specified, it defaults to the value of SOURCE_TABLE with a '_V' suffix.
--
-- SELECT and CONTROL authorizations are copied from the source table to the
-- destination view.
-------------------------------------------------------------------------------

CREATE PROCEDURE CREATE_EXCEPTION_VIEW(
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_VIEW VARCHAR(128)
)
    SPECIFIC CREATE_EXCEPTION_VIEW1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE COLS CLOB(64K) DEFAULT '';
    DECLARE DDL CLOB(64K) DEFAULT '';
    -- Drop any existing view with the same name as the destination view
    FOR D AS
        SELECT
            'DROP VIEW ' || QUOTE_IDENTIFIER(TABSCHEMA) || '.' || QUOTE_IDENTIFIER(TABNAME)  AS DROP_CMD
        FROM
            SYSCAT.TABLES
        WHERE
            TABSCHEMA = DEST_SCHEMA
            AND TABNAME = DEST_VIEW
            AND TYPE = 'V'
    DO
        EXECUTE IMMEDIATE D.DROP_CMD;
    END FOR;
    -- Generate a comma separated list of the source table fields in the order
    -- that they exist in the source table
    FOR C AS
        SELECT
            COLNAME
        FROM
            SYSCAT.COLUMNS
        WHERE
            TABSCHEMA = SOURCE_SCHEMA
            AND TABNAME = SOURCE_TABLE
            AND COLNAME <> 'EXCEPT_MSG'
            AND COLNAME <> 'EXCEPT_TS'
        ORDER BY
            COLNO
    DO
        SET COLS = COLS || QUOTE_IDENTIFIER(C.COLNAME) || ', ';
    END FOR;
    -- Create the exceptions view based on the structure of the source table
    SET DDL =
        'CREATE VIEW ' || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || ' AS '
        || 'WITH T ('
        ||      COLS
        || '    EXCEPT_MSG,'
        || '    EXCEPT_TYPE,'
        || '    EXCEPT_OBJECT,'
        || '    EXCEPT_TS,'
        || '    I,'
        || '    J'
        || ') AS ('
        || '    SELECT '
        ||          COLS
        || '        EXCEPT_MSG,'
        || '        CHAR(SUBSTR(EXCEPT_MSG, 6, 1)),'
        || '        CHAR(SUBSTR(EXCEPT_MSG, 12, INTEGER(DECIMAL(VARCHAR(SUBSTR(EXCEPT_MSG, 7, 5)), 5, 0)))),'
        || '        EXCEPT_TS,'
        || '        1,'
        || '        15 + INTEGER(DECIMAL(VARCHAR(SUBSTR(EXCEPT_MSG, 7, 5)), 5, 0))'
        || '    FROM ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE)
        || '    UNION ALL'
        || '    SELECT '
        ||          COLS
        || '        EXCEPT_MSG,'
        || '        CHAR(SUBSTR(EXCEPT_MSG, J, 1)),'
        || '        CHAR(SUBSTR(EXCEPT_MSG, J + 6, INTEGER(DECIMAL(VARCHAR(SUBSTR(EXCEPT_MSG, J + 1, 5)), 5, 0)))),'
        || '        EXCEPT_TS,'
        || '        I + 1,'
        || '        J + 9 + INTEGER(DECIMAL(VARCHAR(SUBSTR(EXCEPT_MSG, J + 1, 5)), 5, 0))'
        || '    FROM T'
        || '    WHERE I < INTEGER(DECIMAL(VARCHAR(SUBSTR(EXCEPT_MSG, 1, 5)), 5, 0))'
        || '    AND I < 20'
        || ')'
        || 'SELECT '
        ||      COLS
        || '    EXCEPT_TYPE,'
        || '    CASE WHEN EXCEPT_TYPE = ''I'''
        || '        THEN ('
        || '            SELECT VARCHAR(RTRIM(INDSCHEMA) || ''.'' || RTRIM(INDNAME))'
        || '            FROM SYSCAT.INDEXES'
        || '            WHERE CHAR(IID) = EXCEPT_OBJECT'
        || '        )'
        || '        ELSE EXCEPT_OBJECT'
        || '    END AS EXCEPT_OBJECT,'
        || '    EXCEPT_TS '
        || 'FROM T';
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
        UPDATEAUTH = 'N'
    WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE;
    CALL RESTORE_AUTH(DEST_SCHEMA, DEST_VIEW);
END!

CREATE PROCEDURE CREATE_EXCEPTION_VIEW(SOURCE_TABLE VARCHAR(128), DEST_VIEW VARCHAR(128))
    SPECIFIC CREATE_EXCEPTION_VIEW2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_VIEW(CURRENT SCHEMA, SOURCE_TABLE, CURRENT SCHEMA, DEST_VIEW);
END!

CREATE PROCEDURE CREATE_EXCEPTION_VIEW(SOURCE_TABLE VARCHAR(128))
    SPECIFIC CREATE_EXCEPTION_VIEW3
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_VIEW(SOURCE_TABLE, SOURCE_TABLE || '_V');
END!

-- vim: set et sw=4 sts=4:
