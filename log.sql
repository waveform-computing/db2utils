-------------------------------------------------------------------------------
-- LOGGING FRAMEWORK
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

-- LOG ROLES
-------------------------------------------------------------------------------
-- The module has three roles associated with it which are created in the DDL
-- below:
--
-- LOG_WRITER -- Has the ability to create log messages via the LOG procedure
-- LOG_READER -- Has the ability to SELECT from the LOG table
-- LOG_ADMIN -- Has CONTROL of the LOG table
-------------------------------------------------------------------------------

CREATE ROLE LOG_ADMIN!
CREATE ROLE LOG_READER!
CREATE ROLE LOG_WRITER!

-- LOG SEVERITIES
-------------------------------------------------------------------------------
-- The module defines a set of constants and variables that serve as human
-- readable variants of the log severities, subjects, and notification
-- frequencies.  Variables are also provided for the default severity and
-- frequency.
-------------------------------------------------------------------------------

CREATE VARIABLE LOG_DEBUG        SMALLINT CONSTANT 10!
CREATE VARIABLE LOG_INFO         SMALLINT CONSTANT 20!
CREATE VARIABLE LOG_INFORMATION  SMALLINT CONSTANT 20!
CREATE VARIABLE LOG_WARN         SMALLINT CONSTANT 30!
CREATE VARIABLE LOG_WARNING      SMALLINT CONSTANT 30!
CREATE VARIABLE LOG_ERROR        SMALLINT CONSTANT 40!

CREATE VARIABLE LOG_SEVERITY SMALLINT DEFAULT LOG_INFO!

CREATE VARIABLE LOG_DATABASE  CHAR(1) CONSTANT 'D'!
CREATE VARIABLE LOG_SCHEMA    CHAR(1) CONSTANT 'S'!
CREATE VARIABLE LOG_TABLE     CHAR(1) CONSTANT 'T'!
CREATE VARIABLE LOG_VIEW      CHAR(1) CONSTANT 'V'!
CREATE VARIABLE LOG_ALIAS     CHAR(1) CONSTANT 'A'!
CREATE VARIABLE LOG_FUNC      CHAR(1) CONSTANT 'F'!
CREATE VARIABLE LOG_FUNCTION  CHAR(1) CONSTANT 'F'!
CREATE VARIABLE LOG_PROC      CHAR(1) CONSTANT 'P'!
CREATE VARIABLE LOG_PROCEDURE CHAR(1) CONSTANT 'P'!
CREATE VARIABLE LOG_METHOD    CHAR(1) CONSTANT 'M'!
CREATE VARIABLE LOG_TRIGGER   CHAR(1) CONSTANT 'R'!
CREATE VARIABLE LOG_INDEX     CHAR(1) CONSTANT 'I'!
CREATE VARIABLE LOG_SEQUENCE  CHAR(1) CONSTANT 'Q'!

CREATE VARIABLE NOTIFY_IMMEDIATE CHAR(1) CONSTANT 'I'!
CREATE VARIABLE NOTIFY_HOURLY    CHAR(1) CONSTANT 'H'!
CREATE VARIABLE NOTIFY_DAILY     CHAR(1) CONSTANT 'D'!
CREATE VARIABLE NOTIFY_WEEKLY    CHAR(1) CONSTANT 'W'!
CREATE VARIABLE NOTIFY_MONTHLY   CHAR(1) CONSTANT 'M'!

CREATE VARIABLE NOTIFY_FREQUENCY CHAR(1) DEFAULT NOTIFY_DAILY!

-- VARCHAR_EXPRESSION(EXPRESSION, TYPESCHEMA, TYPENAME)
-- VARCHAR_EXPRESSION(EXPRESSION, TYPENAME)
-------------------------------------------------------------------------------
-- This is a small utility function used to simplify construction of procedures
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

-- LOG_NOTIFICATIONS
-------------------------------------------------------------------------------
-- The LOG_NOTIFICATIONS table records the details and preferences of those
-- who wish to be notified by e-mail about new entries in the LOG table.
--
-- The RECIPIENT column contains the e-mail address of the recipient. This
-- column must be specified and is the primary key.
--
-- The SEVERITY column contains the minimum severity required to cause
-- notification of log entries to the specified RECIPIENT.
--
-- The SCHEMA column contains the name of the schema which the recipient is
-- interested in, or NULL if the recipient is interested in log entries for
-- all schemas.
--
-- The FREQUENCY columns specifies the frequency with which notifications
-- can be sent.
-------------------------------------------------------------------------------

CREATE TABLE LOG_NOTIFICATIONS (
    RECIPIENT  VARCHAR(200) NOT NULL,
    SEVERITY   SMALLINT NOT NULL,
    SCHEMA     VARCHAR(128) DEFAULT NULL,
    FREQUENCY  CHAR(1) NOT NULL
)!

CREATE UNIQUE INDEX

ALTER TABLE LOG_NOTIFICATIONS
    ADD CONSTRAINT PK PRIMARY KEY (RECIPIENT)
    ADD CONSTRAINT SEVERITY_CK CHECK (SEVERITY BETWEEN 0 AND 50)
    ADD CONSTRAINT FREQUENCY_CK CHECK (FREQUENCY IN (
        NOTIFY_IMMEDIATE,
        NOTIFY_HOURLY,
        NOTIFY_DAILY,
        NOTIFY_WEEKLY,
        NOTIFY_MONTHLY
    ))!

-- LOG
-------------------------------------------------------------------------------
-- The LOG table holds a list of administrative notifications.  The CREATED
-- column contains the timestamp of the message. The SEVERITY column indicates
-- whether the message is debugging, informational, a warning, or an error.
--
-- The SUBJECT_TYPE schema indicates what the SUBJECT_SCHEMA and SUBJECT_NAME
-- columns refer to. It accepts one of the SUBJECT_* constants defined at
-- the top of the unit.
--
-- Finally, the TEXT column contains up to 1k of text for the message itself.
-------------------------------------------------------------------------------

CREATE TABLE LOG (
    CREATED          TIMESTAMP DEFAULT CURRENT TIMESTAMP NOT NULL,
    SEVERITY         SMALLINT NOT NULL,
    SUBJECT_TYPE     CHAR(1) DEFAULT 'D' NOT NULL,
    SUBJECT_SCHEMA   VARCHAR(128) DEFAULT NULL,
    SUBJECT_NAME     VARCHAR(128) DEFAULT NULL,
    TEXT             VARCHAR(1024) NOT NULL
) COMPRESS YES!

CREATE INDEX LOG_IX1
    ON LOG (SUBJECT_SCHEMA, SUBJECT_NAME)!

CREATE INDEX LOG_IX2
    ON LOG (SUBJECT_TYPE, SUBJECT_SCHEMA, SUBJECT_NAME)!

CREATE INDEX LOG_IX3
    ON LOG (CREATED, SUBJECT_TYPE, SUBJECT_SCHEMA, SUBJECT_NAME)!

ALTER TABLE LOG
    ADD CONSTRAINT SEVERITY_CK CHECK (SEVERITY BETWEEN 0 AND 50)
    ADD CONSTRAINT SUBJECT_TYPE_CK CHECK (
        SUBJECT_TYPE IN (
            LOG_DATABASE,
            LOG_SCHEMA,
            LOG_TABLE,
            LOG_VIEW,
            LOG_ALIAS,
            LOG_FUNCTION,
            LOG_PROCEDURE,
            LOG_METHOD,
            LOG_TRIGGER,
            LOG_INDEX,
            LOG_SEQUENCE
        )
    )
    ADD CONSTRAINT SUBJECT_SCHEMA_CK CHECK (
        (SUBJECT_TYPE = LOG_DATABASE AND SUBJECT_SCHEMA IS NULL) OR
        (SUBJECT_TYPE <> LOG_DATABASE AND SUBJECT_SCHEMA IS NOT NULL)
    )
    ADD CONSTRAINT SUBJECT_NAME_CK CHECK (
        (SUBJECT_TYPE IN (LOG_DATABASE, LOG_SCHEMA) AND SUBJECT_NAME IS NULL) OR
        (SUBJECT_TYPE NOT IN (LOG_DATABASE, LOG_SCHEMA) AND SUBJECT_NAME IS NOT NULL)
    )!

GRANT CONTROL ON LOG TO ROLE LOG_ADMIN!
GRANT SELECT ON LOG TO ROLE LOG_READER!

-- LOG(SEVERITY, SUBJECT_TYPE, SUBJECT_SCHEMA, SUBJECT_NAME, TEXT)
-- LOG(SEVERITY, SUBJECT_TYPE, SUBJECT_NAME, TEXT)
-- LOG(SEVERITY, SUBJECT_NAME, TEXT)
-- LOG(SEVERITY, TEXT)
-- LOG(TEXT)
-------------------------------------------------------------------------------
-- The LOG procedure is used to create new messages in the LOG table containing
-- the specified TEXT.
--
-- If SEVERITY is specified it must be a value between 0 and 50 where the
-- higher the value, the more important the log message. The log severity
-- constants at the start of the unit are provided as suggestions of four
-- typical logging levels (debug, info, warning, and error). If SEVERITY is
-- omitted it defaults to the value of the LOG_SEVERITY variable which in
-- turn defaults to the value of the LOG_INFO constant.
--
-- If SUBJECT_TYPE is specified, it must be one of the log subject type
-- constants at the start of the unit. If SUBJECT_TYPE is omitted it defaults
-- to LOG_DATABASE when SUBJECT_NAME is also omitted, or LOG_TABLE when
-- SUBJECT_NAME is specified.
--
-- If SUBJECT_TYPE is not LOG_DATABASE, then SUBJECT_SCHEMA must contain the
-- name of the schema containing the object that the log message pertains to.
-- If SUBJECT_SCHEMA is not specified it defaults to the value of the
-- CURRENT SCHEMA special variable if SUBJECT_TYPE is not LOG_DATABASE, or
-- NULL otherwise.
--
-- If SUBJECT_TYPE is neither LOG_DATABASE nor LOG_SCHEMA, then SUBJECT_NAME
-- must contain the unqualified name of the object that the log message
-- pertains to. If not specified, SUBJECT_NAME defaults to NULL.
--
-- Finally, the TEXT parameter specifies the actual text message.
-------------------------------------------------------------------------------

CREATE PROCEDURE LOG(
    SEVERITY SMALLINT,
    SUBJECT_TYPE CHAR(1),
    SUBJECT_SCHEMA VARCHAR(128),
    SUBJECT_NAME VARCHAR(128),
    TEXT VARCHAR(1024)
)
    SPECIFIC LOG1
    MODIFIES SQL DATA
    DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO LOG (CREATED, SEVERITY, SUBJECT_TYPE, SUBJECT_SCHEMA, SUBJECT_NAME, TEXT)
    VALUES (CURRENT TIMESTAMP, SEVERITY, SUBJECT_TYPE, SUBJECT_SCHEMA, SUBJECT_NAME, TEXT);
END!

CREATE PROCEDURE LOG(
    SEVERITY SMALLINT,
    SUBJECT_TYPE CHAR(1),
    SUBJECT_NAME VARCHAR(128),
    TEXT VARCHAR(1024)
)
    SPECIFIC LOG2
    MODIFIES SQL DATA
    DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL LOG(
        SEVERITY,
        SUBJECT_TYPE,
        CASE SUBJECT_TYPE
            WHEN LOG_DATABASE THEN NULL
            ELSE CURRENT SCHEMA
        END,
        SUBJECT_NAME,
        TEXT
    );
END!

CREATE PROCEDURE LOG(SEVERITY SMALLINT, SUBJECT_NAME VARCHAR(128), TEXT VARCHAR(1024))
    SPECIFIC LOG3
    MODIFIES SQL DATA
    DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL LOG(SEVERITY, LOG_TABLE, CURRENT SCHEMA, SUBJECT_NAME, TEXT);
END!

CREATE PROCEDURE LOG(SEVERITY SMALLINT, TEXT VARCHAR(1024))
    SPECIFIC LOG4
    MODIFIES SQL DATA
    DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL LOG(SEVERITY, LOG_DATABASE, NULL, NULL, TEXT);
END!

CREATE PROCEDURE LOG(TEXT VARCHAR(1024))
    SPECIFIC LOG5
    MODIFIES SQL DATA
    DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL LOG(LOG_SEVERITY, LOG_DATABASE, NULL, NULL, TEXT);
END!

-- vim: set et sw=4 sts=4:
