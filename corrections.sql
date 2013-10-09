-------------------------------------------------------------------------------
-- COLUMN CORRECTION FRAMEWORK
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
-- TODO Provide some documentation and examples
-------------------------------------------------------------------------------

-- CREATE_CORRECTION_TRIGGERS(ASCHEMA, ATABLE, BASE_COLUMN, CORRECTION_COLUMN, LOGSCHEMA, LOGTABLE)
-- CREATE_CORRECTION_TRIGGERS(ASCHEMA, ATABLE, BASE_COLUMN, CORRECTION_COLUMN)
-- CREATE_CORRECTION_TRIGGERS(ATABLE, BASE_COLUMN, CORRECTION_COLUMN)
-------------------------------------------------------------------------------
-- The CREATE_CORRECTION_TRIGGERS procedure creates, for a base table specified
-- by ASCHEMA and ATABLE, a couple of update triggers for the column specified
-- by BASE_COLUMN. In the event that BASE_COLUMN is updated, and the column
-- specified by CORRECTION_COLUMN is non-NULL, a before update trigger will set
-- CORRECTION_COLUMN to NULL, and an after update trigger will log the change
-- in the LOG table specified by LOGSCHEMA and LOGTABLE. If
--
-- If ASCHEMA is not specified it defaults to the current schema.  The schema
-- of the created trigger will be ASCHEMA. The name of the triggers will be
-- <ATABLE>_RESET_<CORRECTION_COLUMN> for the before trigger and
-- <ATABLE>_RESET_<CORRECTION_COLUMN>_LOG for the after trigger.
-------------------------------------------------------------------------------

CREATE PROCEDURE CREATE_CORRECTION_TRIGGERS(
    ASCHEMA VARCHAR(128),
    ATABLE VARCHAR(128),
    BASE_COLUMN VARCHAR(128),
    CORRECTION_COLUMN VARCHAR(128)
)
    SPECIFIC CREATE_CORRECTION_TRIGGERS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE DDL CLOB(64K) DEFAULT '';
    DECLARE KEY_EXPR CLOB(64K) DEFAULT '';
    DECLARE BEFORE_NAME VARCHAR(128) DEFAULT '';
    DECLARE AFTER_NAME VARCHAR(128) DEFAULT '';
    DECLARE BASE_TYPE_SCHEMA VARCHAR(128);
    DECLARE BASE_TYPE_NAME VARCHAR(128);
    DECLARE CORRECTION_TYPE_SCHEMA VARCHAR(128);
    DECLARE CORRECTION_TYPE_NAME VARCHAR(128);

    SET BEFORE_NAME = ATABLE || '_RESET_' || CORRECTION_COLUMN;
    SET AFTER_NAME = ATABLE || '_RESET_' || CORRECTION_COLUMN || '_LOG';
    -- Drop any existing triggers with the target names
    FOR D AS
        SELECT
            'DROP TRIGGER ' || QUOTE_IDENTIFIER(TRIGSCHEMA) || '.' || QUOTE_IDENTIFIER(TRIGNAME) AS DROP_CMD
        FROM
            SYSCAT.TRIGGERS
        WHERE
            TRIGSCHEMA = ASCHEMA
            AND TRIGNAME IN (BEFORE_NAME, AFTER_NAME)
    DO
        EXECUTE IMMEDIATE D.DROP_CMD;
    END FOR;
    -- Create the before trigger to reset the clean column
    SET DDL =
        'CREATE TRIGGER ' || QUOTE_IDENTIFIER(ASCHEMA) || '.' || QUOTE_IDENTIFIER(BEFORE_NAME) || ' '
        || '    BEFORE UPDATE OF ' || QUOTE_IDENTIFIER(BASE_COLUMN)
        || '    ON ' || QUOTE_IDENTIFIER(ASCHEMA) || '.' || QUOTE_IDENTIFIER(ATABLE)
        || '    REFERENCING OLD AS OLD NEW AS NEW'
        || '    FOR EACH ROW '
        || '    WHEN ('
        || '        OLD.' || QUOTE_IDENTIFIER(BASE_COLUMN) || ' <> NEW.' || QUOTE_IDENTIFIER(BASE_COLUMN)
        || '        AND OLD.' || QUOTE_IDENTIFIER(CORRECTION_COLUMN) || ' IS NOT NULL'
        || '    )'
        || '    SET NEW.' || QUOTE_IDENTIFIER(CORRECTION_COLUMN) || ' = NULL';
    EXECUTE IMMEDIATE DDL;
    -- Create the after trigger to log the event
    FOR K AS
        SELECT
            COLNAME,
            TYPESCHEMA,
            TYPENAME,
            KEYSEQ
        FROM
            SYSCAT.COLUMNS
        WHERE
            TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
            AND COALESCE(KEYSEQ, 0) > 0
        ORDER BY
            KEYSEQ
    DO
        SET KEY_EXPR = KEY_EXPR ||
            CASE KEYSEQ WHEN 1 THEN '' ELSE ' || '', '' || ' END ||
            VARCHAR_EXPRESSION('OLD.' || QUOTE_IDENTIFIER(COLNAME), TYPESCHEMA, TYPENAME);
    END FOR;
    SET (BASE_TYPE_SCHEMA, BASE_TYPE_NAME) = (
        SELECT TYPESCHEMA, TYPENAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = ASCHEMA
        AND TABNAME = ATABLE
        AND COLNAME = BASE_COLUMN
    );
    SET (CORRECTION_TYPE_SCHEMA, CORRECTION_TYPE_NAME) = (
        SELECT TYPESCHEMA, TYPENAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = ASCHEMA
        AND TABNAME = ATABLE
        AND COLNAME = CORRECTION_COLUMN
    );
    SET DDL =
        'CREATE TRIGGER ' || QUOTE_IDENTIFIER(ASCHEMA) || '.' || QUOTE_IDENTIFIER(AFTER_NAME) || ' '
        || '    AFTER UPDATE OF ' || QUOTE_IDENTIFIER(BASE_COLUMN)
        || '    ON ' || QUOTE_IDENTIFIER(ASCHEMA) || '.' || QUOTE_IDENTIFIER(ATABLE)
        || '    REFERENCING OLD AS OLD NEW AS NEW'
        || '    FOR EACH ROW '
        || '    WHEN ('
        || '        OLD.' || QUOTE_IDENTIFIER(BASE_COLUMN) || ' <> NEW.' || QUOTE_IDENTIFIER(BASE_COLUMN)
        || '        AND OLD.' || QUOTE_IDENTIFIER(CORRECTION_COLUMN) || ' IS NOT NULL'
        || '    )'
        || '    INSERT INTO ' || QUOTE_IDENTIFIER(CURRENT SCHEMA) || '.LOG ('
        || '        SEVERITY,'
        || '        SUBJECT_TYPE,'
        || '        SUBJECT_SCHEMA,'
        || '        SUBJECT_NAME,'
        || '        TEXT'
        || '    )'
        || '    VALUES ('
        || '        ''W'', /* Warning */'
        || '        ''T'', /* Table subject */'
        ||          '''' || REPLACE(ASCHEMA, '''', '''''') || ''','
        ||          '''' || REPLACE(ATABLE, '''', '''''') || ''','
        ||          '''For row with key ('' || ' || KEY_EXPR || ' || ''), '
        ||              REPLACE(BASE_COLUMN, '''', '''''') || ' has changed value from '''
        ||              ' || ' || VARCHAR_EXPRESSION('OLD.' || QUOTE_IDENTIFIER(BASE_COLUMN), BASE_TYPE_SCHEMA, BASE_TYPE_NAME) || ' || '' to '''
        ||              ' || ' || VARCHAR_EXPRESSION('NEW.' || QUOTE_IDENTIFIER(BASE_COLUMN), BASE_TYPE_SCHEMA, BASE_TYPE_NAME) || ' || ''; '
        ||              'resetting ' || REPLACE(CORRECTION_COLUMN, '''', '''''') || ' from '''
        ||              ' || ' || VARCHAR_EXPRESSION('OLD.' || QUOTE_IDENTIFIER(CORRECTION_COLUMN), CORRECTION_TYPE_SCHEMA, CORRECTION_TYPE_NAME) || ' || '' to NULL'''
        || '    )';
    EXECUTE IMMEDIATE DDL;
END!

CREATE PROCEDURE CREATE_CORRECTION_TRIGGERS(
    ATABLE VARCHAR(128),
    BASE_COLUMN VARCHAR(128),
    CORRECTION_COLUMN VARCHAR(128)
)
    SPECIFIC CREATE_CORRECTION_TRIGGERS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_CORRECTION_TRIGGERS(CURRENT SCHEMA, ATABLE, BASE_COLUMN, CORRECTION_COLUMN);
END!

COMMENT ON SPECIFIC PROCEDURE CREATE_CORRECTION_TRIGGERS1
    IS 'Creates triggers on the specified column which will log changes and NULL out a corresponding correction column. See source for usage examples'!
COMMENT ON SPECIFIC PROCEDURE CREATE_CORRECTION_TRIGGERS2
    IS 'Creates triggers on the specified column which will log changes and NULL out a corresponding correction column. See source for usage examples'!

-- vim: set et sw=4 sts=4:
