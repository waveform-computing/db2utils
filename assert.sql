-------------------------------------------------------------------------------
-- ASSERTION FRAMEWORK
-------------------------------------------------------------------------------
-- Copyright (c) 2013 Dave Hughes <dave@waveform.org.uk>
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


-- ASSERT_SQLSTATE
-------------------------------------------------------------------------------
-- The ASSERT_SQLSTATE variable specifies the SQLSTATE that is raised in the
-- case that an assertion fails. If you need to catch this specific SQLSTATE it
-- is recommended you assign a unique (valid) SQLSTATE to this variable.
-------------------------------------------------------------------------------

CREATE VARIABLE ASSERT_SQLSTATE CHAR(5) DEFAULT '90001'!

COMMENT ON VARIABLE ASSERT_SQLSTATE
    IS 'The SQLSTATE to be raised by all ASSERT_* procedures and functions in the case of failure'!

-- ASSERT_SIGNALS(STATE, SQL)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if executing SQL does NOT raise SQLSTATE STATE.
-- SQL must be capable of being executed by EXECUTE IMMEDIATE, i.e. no queries
-- or SIGNAL calls. In order to permit simple testing of ASSERT_SIGNALS an
-- additional procedure is defined below which simply calls SIGNAL; EXECUTE
-- IMMEDIATE can execute a SIGNAL within a CALL, but not a SIGNAL directly...
-------------------------------------------------------------------------------

CREATE PROCEDURE ASSERT_SIGNALS(STATE CHAR(5), SQL CLOB(64K))
    SPECIFIC ASSERT_SIGNALS1
    LANGUAGE SQL
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
BEGIN ATOMIC
    DECLARE NEWSTATE CHAR(5);
    DECLARE SQLSTATE CHAR(5);
    DECLARE SAVESTATE CHAR(5);
    DECLARE MESSAGE VARCHAR(70);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            SET SAVESTATE = SQLSTATE;
            SET NEWSTATE = ASSERT_SQLSTATE;
            IF SAVESTATE <> STATE THEN
                SET MESSAGE = SUBSTR(SQL, 1, 20)
                    || CASE WHEN LENGTH(SQL) > 20 THEN '...' ELSE '' END
                    || ' signalled SQLSTATE ' || SAVESTATE
                    || ' instead of ' || STATE;
                SIGNAL SQLSTATE NEWSTATE SET MESSAGE_TEXT = MESSAGE;
            END IF;
        END;
    EXECUTE IMMEDIATE SQL;
    SET NEWSTATE = ASSERT_SQLSTATE;
    SET MESSAGE = SUBSTR(SQL, 1, 20)
        || CASE WHEN LENGTH(SQL) > 20 THEN '...' ELSE '' END
        || ' did not signal SQLSTATE ' || STATE;
    SIGNAL SQLSTATE NEWSTATE SET MESSAGE_TEXT = MESSAGE;
END!

COMMENT ON SPECIFIC PROCEDURE ASSERT_SIGNALS1
    IS 'Signals ASSERT_SQLSTATE if the execution of SQL doesn''t signal SQLSTATE STATE, or signals a different SQLSTATE'!

-- ASSERT_TABLE_EXISTS(ASCHEMA, ATABLE)
-- ASSERT_TABLE_EXISTS(ATABLE)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if ASCHEMA.ATABLE does not exist, or is not a
-- table/view. If not specified, ASCHEMA defaults to the value of the CURRENT
-- SCHEMA special register. Note that the function doesn't check that
-- an existing table is currently marked invalid or inoperative, merely for
-- existence.
-------------------------------------------------------------------------------

CREATE FUNCTION ASSERT_TABLE_EXISTS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    RETURNS INTEGER
    SPECIFIC ASSERT_TABLE_EXISTS1
    LANGUAGE SQL
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE (
            SELECT COUNT(*)
            FROM SYSCAT.TABLES
            WHERE TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
        )
        WHEN 1 THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, SUBSTR(ASCHEMA || '.' || ATABLE, 1, 50)
            || CASE WHEN LENGTH(ASCHEMA) + 1 + LENGTH(ATABLE) > 50 THEN '...' ELSE '' END
            || ' does not exist')
    END!

CREATE FUNCTION ASSERT_TABLE_EXISTS(ATABLE VARCHAR(128))
    RETURNS INTEGER
    SPECIFIC ASSERT_TABLE_EXISTS2
    LANGUAGE SQL
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    VALUES ASSERT_TABLE_EXISTS(CURRENT SCHEMA, ATABLE)!

COMMENT ON SPECIFIC FUNCTION ASSERT_TABLE_EXISTS1
    IS 'Signals ASSERT_SQLSTATE if the specified table does not exist'!
COMMENT ON SPECIFIC FUNCTION ASSERT_TABLE_EXISTS2
    IS 'Signals ASSERT_SQLSTATE if the specified table does not exist'!

-- ASSERT_COLUMN_EXISTS(ASCHEMA, ATABLE, ACOLNAME)
-- ASSERT_COLUMN_EXISTS(ATABLE, ACOLNAME)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if ACOLNAME does not exist within the
-- ASCHEMA.ATABLE.  If not specified, ASCHEMA defaults to the value of the
-- CURRENT SCHEMA special register.
-------------------------------------------------------------------------------

CREATE FUNCTION ASSERT_COLUMN_EXISTS(
        ASCHEMA VARCHAR(128),
        ATABLE VARCHAR(128),
        ACOLNAME VARCHAR(128)
    )
    RETURNS INTEGER
    SPECIFIC ASSERT_COLUMN_EXISTS1
    LANGUAGE SQL
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE (
            SELECT COUNT(*)
            FROM SYSCAT.COLUMNS
            WHERE TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
            AND COLNAME = ACOLNAME
        )
        WHEN 1 THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, SUBSTR(ACOLNAME, 1, 20)
            || CASE WHEN LENGTH(ACOLNAME) > 20 THEN '...' ELSE '' END
            || ' does not exist in '
            || SUBSTR(ASCHEMA || '.' || ATABLE, 1, 30)
            || CASE WHEN LENGTH(ASCHEMA) + 1 + LENGTH(ATABLE) > 30 THEN '...' ELSE '' END)
    END!

CREATE FUNCTION ASSERT_COLUMN_EXISTS(ATABLE VARCHAR(128), ACOLNAME VARCHAR(128))
    RETURNS INTEGER
    SPECIFIC ASSERT_COLUMN_EXISTS2
    LANGUAGE SQL
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    VALUES ASSERT_COLUMN_EXISTS(CURRENT SCHEMA, ATABLE, ACOLNAME)!

COMMENT ON SPECIFIC FUNCTION ASSERT_COLUMN_EXISTS1
    IS 'Signals ASSERT_SQLSTATE if the specified column does not exist'!
COMMENT ON SPECIFIC FUNCTION ASSERT_COLUMN_EXISTS2
    IS 'Signals ASSERT_SQLSTATE if the specified column does not exist'!

-- ASSERT_TRIGGER_EXISTS(ASCHEMA, ATRIGGER)
-- ASSERT_TRIGGER_EXISTS(ATRIGGER)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if ASCHEMA.ATRIGGER does not exist, or is not a
-- trigger. If not specified, ASCHEMA defaults to the value of the CURRENT
-- SCHEMA special register. Note that the function doesn't check whether an
-- existing trigger is currently marked inoperative, merely for existence.
-------------------------------------------------------------------------------

CREATE FUNCTION ASSERT_TRIGGER_EXISTS(ASCHEMA VARCHAR(128), ATRIGGER VARCHAR(128))
    RETURNS INTEGER
    SPECIFIC ASSERT_TRIGGER_EXISTS1
    LANGUAGE SQL
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE (
            SELECT COUNT(*)
            FROM SYSCAT.TRIGGERS
            WHERE TRIGSCHEMA = ASCHEMA
            AND TRIGNAME = ATRIGGER
        )
        WHEN 1 THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, SUBSTR(ASCHEMA || '.' || ATRIGGER, 1, 50)
            || CASE WHEN LENGTH(ASCHEMA) + 1 + LENGTH(ATRIGGER) > 50 THEN '...' ELSE '' END
            || ' does not exist')
    END!

CREATE FUNCTION ASSERT_TRIGGER_EXISTS(ATRIGGER VARCHAR(128))
    RETURNS INTEGER
    SPECIFIC ASSERT_TRIGGER_EXISTS2
    LANGUAGE SQL
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    VALUES ASSERT_TRIGGER_EXISTS(CURRENT SCHEMA, ATRIGGER)!

COMMENT ON SPECIFIC FUNCTION ASSERT_TRIGGER_EXISTS1
    IS 'Signals ASSERT_SQLSTATE if the specified trigger does not exist'!
COMMENT ON SPECIFIC FUNCTION ASSERT_TRIGGER_EXISTS2
    IS 'Signals ASSERT_SQLSTATE if the specified trigger does not exist'!

-- ASSERT_ROUTINE_EXISTS(ASCHEMA, AROUTINE)
-- ASSERT_ROUTINE_EXISTS(AROUTINE)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if ASCHEMA.AROUTINE does not exist, or is not a
-- routine. If not specified, ASCHEMA defaults to the value of the CURRENT
-- SCHEMA special register. Note that the function doesn't check whether an
-- existing routine is currently marked inoperative, merely for existence.
-------------------------------------------------------------------------------

CREATE FUNCTION ASSERT_ROUTINE_EXISTS(ASCHEMA VARCHAR(128), AROUTINE VARCHAR(128))
    RETURNS INTEGER
    SPECIFIC ASSERT_ROUTINE_EXISTS1
    LANGUAGE SQL
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE (
            SELECT COUNT(*)
            FROM SYSCAT.ROUTINES
            WHERE ROUTINESCHEMA = ASCHEMA
            AND ROUTINENAME = AROUTINE
        )
        WHEN 1 THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, SUBSTR(ASCHEMA || '.' || AROUTINE, 1, 50)
            || CASE WHEN LENGTH(ASCHEMA) + 1 + LENGTH(AROUTINE) > 50 THEN '...' ELSE '' END
            || ' does not exist')
    END!

CREATE FUNCTION ASSERT_ROUTINE_EXISTS(AROUTINE VARCHAR(128))
    RETURNS INTEGER
    SPECIFIC ASSERT_ROUTINE_EXISTS2
    LANGUAGE SQL
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    VALUES ASSERT_ROUTINE_EXISTS(CURRENT SCHEMA, AROUTINE)!

COMMENT ON SPECIFIC FUNCTION ASSERT_ROUTINE_EXISTS1
    IS 'Signals ASSERT_SQLSTATE if the specified routine does not exist'!
COMMENT ON SPECIFIC FUNCTION ASSERT_ROUTINE_EXISTS2
    IS 'Signals ASSERT_SQLSTATE if the specified routine does not exist'!

-- ASSERT_IS_NULL(A)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if A is not NULL. The function is overloaded
-- for most common types and generally should not need CASTs for usage.
-------------------------------------------------------------------------------

CREATE FUNCTION ASSERT_IS_NULL(A INTEGER)
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NULL1
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' is non-NULL')
    END!

CREATE FUNCTION ASSERT_IS_NULL(A DOUBLE)
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NULL2
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' is non-NULL')
    END!

CREATE FUNCTION ASSERT_IS_NULL(A TIMESTAMP)
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NULL3
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' is non-NULL')
    END!

CREATE FUNCTION ASSERT_IS_NULL(A TIME)
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NULL4
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' is non-NULL')
    END!

CREATE FUNCTION ASSERT_IS_NULL(A VARCHAR(4000))
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NULL5
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE,
            QUOTE_STRING(SUBSTR(A, 1, 20) || CASE WHEN LENGTH(A) > 20 THEN '...' ELSE '' END) ||
            ' is non-NULL')
    END!

COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NULL1
    IS 'Signals ASSERT_SQLSTATE if the specified value is not NULL'!
COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NULL2
    IS 'Signals ASSERT_SQLSTATE if the specified value is not NULL'!
COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NULL3
    IS 'Signals ASSERT_SQLSTATE if the specified value is not NULL'!
COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NULL4
    IS 'Signals ASSERT_SQLSTATE if the specified value is not NULL'!
COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NULL5
    IS 'Signals ASSERT_SQLSTATE if the specified value is not NULL'!

-- ASSERT_IS_NOT_NULL(A)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if A is not NULL. The function is overloaded
-- for most common types and generally should not need CASTs for usage.
-------------------------------------------------------------------------------

CREATE FUNCTION ASSERT_IS_NOT_NULL(A INTEGER)
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NOT_NULL1
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' is non-NULL')
        ELSE 0
    END!

CREATE FUNCTION ASSERT_IS_NOT_NULL(A DOUBLE)
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NOT_NULL2
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' is non-NULL')
        ELSE 0
    END!

CREATE FUNCTION ASSERT_IS_NOT_NULL(A TIMESTAMP)
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NOT_NULL3
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' is non-NULL')
        ELSE 0
    END!

CREATE FUNCTION ASSERT_IS_NOT_NULL(A TIME)
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NOT_NULL4
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' is non-NULL')
        ELSE 0
    END!

CREATE FUNCTION ASSERT_IS_NOT_NULL(A VARCHAR(4000))
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NOT_NULL5
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE WHEN A IS NULL
        THEN RAISE_ERROR(ASSERT_SQLSTATE,
            QUOTE_STRING(SUBSTR(A, 1, 20) || CASE WHEN LENGTH(A) > 20 THEN '...' ELSE '' END) ||
            ' is non-NULL')
        ELSE 0
    END!

COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NOT_NULL1
    IS 'Signals ASSERT_SQLSTATE if the specified value is NULL'!
COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NOT_NULL2
    IS 'Signals ASSERT_SQLSTATE if the specified value is NULL'!
COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NOT_NULL3
    IS 'Signals ASSERT_SQLSTATE if the specified value is NULL'!
COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NOT_NULL4
    IS 'Signals ASSERT_SQLSTATE if the specified value is NULL'!
COMMENT ON SPECIFIC FUNCTION ASSERT_IS_NOT_NULL5
    IS 'Signals ASSERT_SQLSTATE if the specified value is NULL'!

-- ASSERT_EQUALS(A, B)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if A does not equal B. The function is
-- overloaded for most common types and generally should not need CASTs for
-- usage.
-------------------------------------------------------------------------------

CREATE FUNCTION ASSERT_EQUALS(A INTEGER, B INTEGER)
    RETURNS INTEGER
    SPECIFIC ASSERT_EQUALS1
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' does not equal ' || VARCHAR(B))
    END!

CREATE FUNCTION ASSERT_EQUALS(A DOUBLE, B DOUBLE)
    RETURNS INTEGER
    SPECIFIC ASSERT_EQUALS2
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' does not equal ' || VARCHAR(B))
    END!

CREATE FUNCTION ASSERT_EQUALS(A TIMESTAMP, B TIMESTAMP)
    RETURNS INTEGER
    SPECIFIC ASSERT_EQUALS3
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR_FORMAT(A) || ' does not equal ' || VARCHAR_FORMAT(B))
    END!

CREATE FUNCTION ASSERT_EQUALS(A TIME, B TIME)
    RETURNS INTEGER
    SPECIFIC ASSERT_EQUALS4
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' does not equal ' || VARCHAR(B))
    END!

CREATE FUNCTION ASSERT_EQUALS(A VARCHAR(4000), B VARCHAR(4000))
    RETURNS INTEGER
    SPECIFIC ASSERT_EQUALS5
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN 0
        ELSE RAISE_ERROR(ASSERT_SQLSTATE,
            QUOTE_STRING(SUBSTR(A, 1, 20) || CASE WHEN LENGTH(A) > 20 THEN '...' ELSE '' END) ||
            ' does not equal ' ||
            QUOTE_STRING(SUBSTR(B, 1, 20) || CASE WHEN LENGTH(B) > 20 THEN '...' ELSE '' END))
    END!

COMMENT ON SPECIFIC FUNCTION ASSERT_EQUALS1
    IS 'Signals ASSERT_SQLSTATE if A does not equal B'!
COMMENT ON SPECIFIC FUNCTION ASSERT_EQUALS2
    IS 'Signals ASSERT_SQLSTATE if A does not equal B'!
COMMENT ON SPECIFIC FUNCTION ASSERT_EQUALS3
    IS 'Signals ASSERT_SQLSTATE if A does not equal B'!
COMMENT ON SPECIFIC FUNCTION ASSERT_EQUALS4
    IS 'Signals ASSERT_SQLSTATE if A does not equal B'!
COMMENT ON SPECIFIC FUNCTION ASSERT_EQUALS5
    IS 'Signals ASSERT_SQLSTATE if A does not equal B'!

-- ASSERT_NOT_EQUALS(A, B)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if A does equal B. The function is overloaded for
-- most common types and generally should not need CASTs for usage.
-------------------------------------------------------------------------------

CREATE FUNCTION ASSERT_NOT_EQUALS(A INTEGER, B INTEGER)
    RETURNS INTEGER
    SPECIFIC ASSERT_NOT_EQUALS1
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' does not equal ' || VARCHAR(B))
        ELSE 0
    END!

CREATE FUNCTION ASSERT_NOT_EQUALS(A DOUBLE, B DOUBLE)
    RETURNS INTEGER
    SPECIFIC ASSERT_NOT_EQUALS2
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' does not equal ' || VARCHAR(B))
        ELSE 0
    END!

CREATE FUNCTION ASSERT_NOT_EQUALS(A TIMESTAMP, B TIMESTAMP)
    RETURNS INTEGER
    SPECIFIC ASSERT_NOT_EQUALS3
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR_FORMAT(A) || ' does not equal ' || VARCHAR_FORMAT(B))
        ELSE 0
    END!

CREATE FUNCTION ASSERT_NOT_EQUALS(A TIME, B TIME)
    RETURNS INTEGER
    SPECIFIC ASSERT_NOT_EQUALS4
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN RAISE_ERROR(ASSERT_SQLSTATE, VARCHAR(A) || ' does not equal ' || VARCHAR(B))
        ELSE 0
    END!

CREATE FUNCTION ASSERT_NOT_EQUALS(A VARCHAR(4000), B VARCHAR(4000))
    RETURNS INTEGER
    SPECIFIC ASSERT_NOT_EQUALS5
    LANGUAGE SQL
    CONTAINS SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
RETURN
    CASE A
        WHEN B THEN RAISE_ERROR(ASSERT_SQLSTATE,
            QUOTE_STRING(SUBSTR(A, 1, 20) || CASE WHEN LENGTH(A) > 20 THEN '...' ELSE '' END) ||
            ' does not equal ' ||
            QUOTE_STRING(SUBSTR(B, 1, 20) || CASE WHEN LENGTH(B) > 20 THEN '...' ELSE '' END))
        ELSE 0
    END!

COMMENT ON SPECIFIC FUNCTION ASSERT_NOT_EQUALS1
    IS 'Signals ASSERT_SQLSTATE if A equals B'!
COMMENT ON SPECIFIC FUNCTION ASSERT_NOT_EQUALS2
    IS 'Signals ASSERT_SQLSTATE if A equals B'!
COMMENT ON SPECIFIC FUNCTION ASSERT_NOT_EQUALS3
    IS 'Signals ASSERT_SQLSTATE if A equals B'!
COMMENT ON SPECIFIC FUNCTION ASSERT_NOT_EQUALS4
    IS 'Signals ASSERT_SQLSTATE if A equals B'!
COMMENT ON SPECIFIC FUNCTION ASSERT_NOT_EQUALS5
    IS 'Signals ASSERT_SQLSTATE if A equals B'!

-- vim: set et sw=4 sts=4:
