-------------------------------------------------------------------------------
-- TOGGLE TRIGGERS
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
-- The following code is inspired by the developerWorks article "How to
-- Temporarily Disable Triggers in DB2 Universal Database" by Erasmo Acosta,
-- Tony Lee, and Paul Yip:
--
-- http://www-128.ibm.com/developerworks/db2/library/techarticle/0211swart/0211swart.html
--
-- Routines are provided to disable and enable individual triggers or all
-- triggers on a specified table.
-------------------------------------------------------------------------------

-- DISABLED_TRIGGERS
-------------------------------------------------------------------------------
-- The DISABLED_TRIGGERS table holds all the details necessary to recreate
-- disabled triggers, including the function path and current schema at the
-- time the trigger was created, and the SQL code used to create the trigger.
-------------------------------------------------------------------------------

CREATE TABLE DISABLED_TRIGGERS AS (
    SELECT
        TRIGSCHEMA,
        TRIGNAME,
        TABSCHEMA,
        TABNAME,
        QUALIFIER,
        FUNC_PATH,
        TEXT
    FROM
        SYSCAT.TRIGGERS
)
WITH NO DATA!

CREATE UNIQUE INDEX DISABLED_TRIGGERS_PK
    ON DISABLED_TRIGGERS (TRIGSCHEMA, TRIGNAME)!

ALTER TABLE DISABLED_TRIGGERS
    ADD CONSTRAINT PK PRIMARY KEY (TRIGSCHEMA, TRIGNAME)!

-- DISABLE_TRIGGER(ASCHEMA, ATRIGGER)
-- DISABLE_TRIGGER(ATRIGGER)
-------------------------------------------------------------------------------
-- Drops a trigger after storing its definition in the DISABLED_TRIGGERS table
-- for later "revival". The trigger must be operative (if it is not, recreate
-- it with the RECREATE_TRIGGER procedure above before calling
-- DISABLE_TRIGGER).
-------------------------------------------------------------------------------

CREATE PROCEDURE DISABLE_TRIGGER(ASCHEMA VARCHAR(128), ATRIGGER VARCHAR(128))
    SPECIFIC DISABLE_TRIGGER1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SQLCODE INTEGER DEFAULT 0;
    DECLARE EXIT HANDLER FOR NOT FOUND
        SIGNAL SQLSTATE '80000'
        SET MESSAGE_TEXT = 'Trigger not found';
    DECLARE EXIT HANDLER FOR SQLWARNING
        SIGNAL SQLSTATE '80001'
        SET MESSAGE_TEXT = 'Unable to disable trigger';
    -- Copy the trigger's entry from SYSCAT.TRIGGERS to DISABLED_TRIGGERS
    INSERT INTO DISABLED_TRIGGERS
        SELECT
            TRIGSCHEMA,
            TRIGNAME,
            TABSCHEMA,
            TABNAME,
            QUALIFIER,
            FUNC_PATH,
            TEXT
        FROM
            SYSCAT.TRIGGERS
        WHERE
            TRIGSCHEMA = ASCHEMA
            AND TRIGNAME = ATRIGGER
            AND VALID = 'Y';
    -- Drop the trigger
    FOR D AS
        SELECT DDL
        FROM (
            VALUES 'DROP TRIGGER ' || QUOTE_IDENTIFIER(ASCHEMA) || '.' || QUOTE_IDENTIFIER(ATRIGGER)
        ) AS D(DDL)
    DO
        EXECUTE IMMEDIATE D.DDL;
    END FOR;
END!

CREATE PROCEDURE DISABLE_TRIGGER(ATRIGGER VARCHAR(128))
    SPECIFIC DISABLE_TRIGGER2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL DISABLE_TRIGGER(CURRENT SCHEMA, ATRIGGER);
END!

COMMENT ON SPECIFIC PROCEDURE DISABLE_TRIGGER1
    IS 'Disables the specified trigger by saving its definition to a table and dropping it'!
COMMENT ON SPECIFIC PROCEDURE DISABLE_TRIGGER2
    IS 'Disables the specified trigger by saving its definition to a table and dropping it'!

-- DISABLE_TRIGGERS(ASCHEMA, ATABLE)
-- DISABLE_TRIGGERS(ATABLE)
-------------------------------------------------------------------------------
-- Disables all the active triggers associated with a particular table. If a
-- trigger exists, but is inactive, it is not touched by this procedure.
-------------------------------------------------------------------------------

CREATE PROCEDURE DISABLE_TRIGGERS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    SPECIFIC DISABLE_TRIGGERS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SQLCODE INTEGER DEFAULT 0;
    DECLARE EXIT HANDLER FOR NOT FOUND
        SIGNAL SQLSTATE '80000'
        SET MESSAGE_TEXT = 'Trigger not found';
    DECLARE EXIT HANDLER FOR SQLWARNING
        SIGNAL SQLSTATE '80001'
        SET MESSAGE_TEXT = 'Unable to disable trigger';
    -- Copy all of ATABLE's triggers from SYSCAT.TRIGGERS to DISABLED_TRIGGERS
    INSERT INTO DISABLED_TRIGGERS
        SELECT
            TRIGSCHEMA,
            TRIGNAME,
            TABSCHEMA,
            TABNAME,
            QUALIFIER,
            FUNC_PATH,
            TEXT
        FROM
            SYSCAT.TRIGGERS
        WHERE
            TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
            AND VALID = 'Y';
    -- Drop the triggers
    FOR D AS
        SELECT
            'DROP TRIGGER ' || QUOTE_IDENTIFIER(TRIGSCHEMA) || '.' || QUOTE_IDENTIFIER(TRIGNAME) AS DDL
        FROM
            SYSCAT.TRIGGERS
        WHERE
            TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
            AND VALID = 'Y'
    DO
        EXECUTE IMMEDIATE D.DDL;
    END FOR;
END!

CREATE PROCEDURE DISABLE_TRIGGERS(ATABLE VARCHAR(128))
    SPECIFIC DISABLE_TRIGGERS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL DISABLE_TRIGGERS(CURRENT SCHEMA, ATABLE);
END!

COMMENT ON SPECIFIC PROCEDURE DISABLE_TRIGGERS1
    IS 'Disables all triggers associated with the specified table by saving their definitions to a table and dropping them'!
COMMENT ON SPECIFIC PROCEDURE DISABLE_TRIGGERS2
    IS 'Disables all triggers associated with the specified table by saving their definitions to a table and dropping them'!

-- ENABLE_TRIGGER(ASCHEMA, ATRIGGER)
-- ENABLE_TRIGGER(ATRIGGER)
-------------------------------------------------------------------------------
-- Recreates a "disabled" trigger by retrieving its definition from
-- DISABLED_TRIGGERS.
-------------------------------------------------------------------------------

CREATE PROCEDURE ENABLE_TRIGGER(ASCHEMA VARCHAR(128), ATRIGGER VARCHAR(128))
    SPECIFIC ENABLE_TRIGGER1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SQLCODE INTEGER DEFAULT 0;
    DECLARE SAVE_PATH VARCHAR(254);
    DECLARE SAVE_SCHEMA VARCHAR(128);
    DECLARE EXIT HANDLER FOR SQLWARNING
        SIGNAL SQLSTATE '80000'
        SET MESSAGE_TEXT = 'Unable to enable trigger';
    -- Save the current function resolution path and implicit schema for later
    -- restoration
    SET SAVE_PATH = CURRENT PATH;
    SET SAVE_SCHEMA = CURRENT SCHEMA;
    -- Change the current schema and path to those that were used when the
    -- trigger was created and recreate the trigger
    FOR D AS
        SELECT
            'SET SCHEMA ' || QUOTE_IDENTIFIER(QUALIFIER)   AS SET_QUALIFIER,
            'SET PATH '   || FUNC_PATH                     AS SET_PATH,
            TEXT                                           AS TEXT,
            'SET SCHEMA ' || QUOTE_IDENTIFIER(SAVE_SCHEMA) AS RESTORE_QUALIFIER,
            'SET PATH '   || SAVE_PATH                     AS RESTORE_PATH
        FROM
            DISABLED_TRIGGERS
        WHERE
            TRIGSCHEMA = ASCHEMA
            AND TRIGNAME = ATRIGGER
    DO
        EXECUTE IMMEDIATE D.SET_PATH;
        EXECUTE IMMEDIATE D.SET_QUALIFIER;
        EXECUTE IMMEDIATE D.TEXT;
        EXECUTE IMMEDIATE D.RESTORE_QUALIFIER;
        EXECUTE IMMEDIATE D.RESTORE_PATH;
    END FOR;
    -- Remove the entry from DISABLED_TRIGGERS
    DELETE FROM DISABLED_TRIGGERS
        WHERE TRIGSCHEMA = ASCHEMA AND TRIGNAME = ATRIGGER;
END!

CREATE PROCEDURE ENABLE_TRIGGER(ATRIGGER VARCHAR(128))
    SPECIFIC ENABLE_TRIGGER2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL ENABLE_TRIGGER(CURRENT SCHEMA, ATRIGGER);
END!

COMMENT ON SPECIFIC PROCEDURE ENABLE_TRIGGER1
    IS 'Enables the specified trigger by restoring its definition from a table'!
COMMENT ON SPECIFIC PROCEDURE ENABLE_TRIGGER2
    IS 'Enables the specified trigger by restoring its definition from a table'!

-- ENABLE_TRIGGERS(ASCHEMA, ATABLE)
-- ENABLE_TRIGGERS(ATABLE)
-------------------------------------------------------------------------------
-- Enables all the disabled triggers for a given table. Note that this does not
-- affect inactive triggers which are still attached to the table, just those
-- triggers that have been disabled with DISABLE_TRIGGER or DISABLE_TRIGGERS.
-- To reactivate inactive triggers, see RECREATE_TRIGGER and RECREATE_TRIGGERS.
-------------------------------------------------------------------------------

CREATE PROCEDURE ENABLE_TRIGGERS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    SPECIFIC ENABLE_TRIGGERS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SQLCODE INTEGER DEFAULT 0;
    DECLARE SAVE_PATH VARCHAR(254);
    DECLARE SAVE_SCHEMA VARCHAR(128);
    DECLARE EXIT HANDLER FOR SQLWARNING
        SIGNAL SQLSTATE '80000'
        SET MESSAGE_TEXT = 'Unable to enable trigger';
    -- Save the current function resolution path and implicit schema for later
    -- restoration
    SET SAVE_PATH = CURRENT PATH;
    SET SAVE_SCHEMA = CURRENT SCHEMA;
    -- Change the current schema and path to those that were used when the
    -- triggers were created and recreate the triggers
    FOR D AS
        SELECT
            'SET SCHEMA ' || QUOTE_IDENTIFIER(QUALIFIER)   AS SET_QUALIFIER,
            'SET PATH '   || FUNC_PATH                     AS SET_PATH,
            TEXT                                           AS TEXT,
            'SET SCHEMA ' || QUOTE_IDENTIFIER(SAVE_SCHEMA) AS RESTORE_QUALIFIER,
            'SET PATH '   || SAVE_PATH                     AS RESTORE_PATH
        FROM
            DISABLED_TRIGGERS
        WHERE
            TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
    DO
        EXECUTE IMMEDIATE D.SET_PATH;
        EXECUTE IMMEDIATE D.SET_QUALIFIER;
        EXECUTE IMMEDIATE D.TEXT;
        EXECUTE IMMEDIATE D.RESTORE_QUALIFIER;
        EXECUTE IMMEDIATE D.RESTORE_PATH;
    END FOR;
    -- Remove the entries from DISABLED_TRIGGERS
    DELETE FROM DISABLED_TRIGGERS
        WHERE TABSCHEMA = ASCHEMA AND TABNAME = ATABLE;
END!

CREATE PROCEDURE ENABLE_TRIGGERS(ATABLE VARCHAR(128))
    SPECIFIC ENABLE_TRIGGERS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL ENABLE_TRIGGERS(CURRENT SCHEMA, ATABLE);
END!

COMMENT ON SPECIFIC PROCEDURE ENABLE_TRIGGERS1
    IS 'Enables all disabled triggers associated with a specified table'!
COMMENT ON SPECIFIC PROCEDURE ENABLE_TRIGGERS2
    IS 'Enables all disabled triggers associated with a specified table'!

-- vim: set et sw=4 sts=4:
