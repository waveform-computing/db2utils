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


-- ASSERT_SIGNALS(STATE, SQL)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if executing SQL does NOT raise SQLSTATE STATE.
-- SQL must be capable of being executed by EXECUTE IMMEDIATE, i.e. no queries
-- or SIGNAL calls.
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
    DECLARE MESSAGE VARCHAR(70);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        IF SQLSTATE <> STATE THEN
            SET NEWSTATE = ASSERT_SQLSTATE;
            SET MESSAGE = SUBSTR(SQL, 1, 20)
                || CASE WHEN LENGTH(SQL) > 20 THEN '...' ELSE '' END
                || ' signalled SQLSTATE ' || SQLSTATE
                || ' instead of ' || STATE;
            SIGNAL SQLSTATE NEWSTATE SET MESSAGE_TEXT = MESSAGE;
        END IF;
    EXECUTE IMMEDIATE SQL;
    SET NEWSTATE = ASSERT_SQLSTATE;
    SET MESSAGE = SUBSTR(SQL, 1, 20)
        || CASE WHEN LENGTH(SQL) > 20 THEN '...' ELSE '' END
        || ' did not signal SQLSTATE ' || STATE;
    SIGNAL SQLSTATE NEWSTATE SET MESSAGE_TEXT = MESSAGE;
END!

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

CREATE FUNCTION ASSERT_IS_NULL(A VARCHAR(4000))
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NULL4
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

CREATE FUNCTION ASSERT_IS_NOT_NULL(A VARCHAR(4000))
    RETURNS INTEGER
    SPECIFIC ASSERT_IS_NOT_NULL4
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

CREATE FUNCTION ASSERT_EQUALS(A VARCHAR(4000), B VARCHAR(4000))
    RETURNS INTEGER
    SPECIFIC ASSERT_EQUALS4
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

-- vim: set et sw=4 sts=4:
