-------------------------------------------------------------------------------
-- SCHEMA EVOLUTION UTILS
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
-- The following code provides a set of utilities for evolving schemas,
-- particularly views and triggers. Routines are provided to recreate
-- inoperative views and triggers, and save and restore view definitions to
-- ensure preservation of authorizations.  This functionality is more or less
-- redundant as of DB2 9.7 with its vastly improved schema evolution
-- capabilities, but may still prove useful in prior versions.
-------------------------------------------------------------------------------


-- ROLES
-------------------------------------------------------------------------------
-- The following roles grant usage and administrative rights to the objects
-- created by this module.
-------------------------------------------------------------------------------

CREATE ROLE UTILS_EVOLVE_USER!
CREATE ROLE UTILS_EVOLVE_ADMIN!

GRANT ROLE UTILS_EVOLVE_USER TO ROLE UTILS_USER!
GRANT ROLE UTILS_EVOLVE_USER TO ROLE UTILS_EVOLVE_ADMIN WITH ADMIN OPTION!
GRANT ROLE UTILS_EVOLVE_ADMIN TO ROLE UTILS_ADMIN WITH ADMIN OPTION!

-- RECREATE_VIEW(ASCHEMA, AVIEW)
-- RECREATE_VIEW(AVIEW)
-------------------------------------------------------------------------------
-- RECREATE_VIEW is a utility procedure which recreates the specified view
-- using the SQL found in the system catalog tables. It is useful for quickly
-- recreating views which have been marked inoperative after a change to one or
-- more of the view's dependencies. If ASCHEMA is omitted it defaults to the
-- current schema.
--
-- NOTE: The procedure does NOT drop the view before recreating it. This guards
-- against attempting to recreate an operative view (an inoperative view can be
-- recreated without dropping it first). That said, it will not return an error
-- in the case of attempting to recreate an operative view; the procedure will
-- simply do nothing.
--
-- NOTE: See the SAVE_AUTH procedure's description for warnings regarding the
-- loss of authorization information with inoperative views.
-------------------------------------------------------------------------------

CREATE PROCEDURE RECREATE_VIEW(ASCHEMA VARCHAR(128), AVIEW VARCHAR(128))
    SPECIFIC RECREATE_VIEW1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SAVE_PATH VARCHAR(254);
    DECLARE SAVE_SCHEMA VARCHAR(128);
    SET SAVE_PATH = CURRENT PATH;
    SET SAVE_SCHEMA = CURRENT SCHEMA;
    FOR D AS
        SELECT
            'SET SCHEMA ' || QUOTE_IDENTIFIER(QUALIFIER)   AS SET_QUALIFIER,
            'SET PATH '   || FUNC_PATH                     AS SET_PATH,
            TEXT                                           AS TEXT,
            'SET SCHEMA ' || QUOTE_IDENTIFIER(SAVE_SCHEMA) AS RESTORE_QUALIFIER,
            'SET PATH '   || SAVE_PATH                     AS RESTORE_PATH
        FROM
            SYSCAT.VIEWS
        WHERE
            VIEWSCHEMA = ASCHEMA
            AND VIEWNAME = AVIEW
            AND VALID = 'X'
    DO
        EXECUTE IMMEDIATE D.SET_QUALIFIER;
        EXECUTE IMMEDIATE D.SET_PATH;
        EXECUTE IMMEDIATE D.TEXT;
        EXECUTE IMMEDIATE D.RESTORE_QUALIFIER;
        EXECUTE IMMEDIATE D.RESTORE_PATH;
    END FOR;
END!

CREATE PROCEDURE RECREATE_VIEW(AVIEW VARCHAR(128))
    SPECIFIC RECREATE_VIEW2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL RECREATE_VIEW(CURRENT SCHEMA, AVIEW);
END!

GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_VIEW1 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_VIEW2 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_VIEW1 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_VIEW2 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC PROCEDURE RECREATE_VIEW1
    IS 'Recreates the specified inoperative view from its definition in the system catalogue'!
COMMENT ON SPECIFIC PROCEDURE RECREATE_VIEW2
    IS 'Recreates the specified inoperative view from its definition in the system catalogue'!

-- RECREATE_VIEWS(ASCHEMA)
-- RECREATE_VIEWS()
-------------------------------------------------------------------------------
-- RECREATE_VIEWS is a utility procedure which recreates all inoperative
-- views in the optionally specified schema. If ASCHEMA is omitted it defaults
-- to the CURRENT SCHEMA.
-------------------------------------------------------------------------------

CREATE PROCEDURE RECREATE_VIEWS(ASCHEMA VARCHAR(128))
    SPECIFIC RECREATE_VIEWS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SAVE_PATH VARCHAR(254);
    DECLARE SAVE_SCHEMA VARCHAR(128);
    SET SAVE_PATH = CURRENT PATH;
    SET SAVE_SCHEMA = CURRENT SCHEMA;
    FOR D AS
        SELECT
            'SET SCHEMA ' || QUOTE_IDENTIFIER(V.QUALIFIER) AS SET_QUALIFIER,
            'SET PATH '   || V.FUNC_PATH                   AS SET_PATH,
            V.TEXT                                         AS TEXT,
            'SET SCHEMA ' || QUOTE_IDENTIFIER(SAVE_SCHEMA) AS RESTORE_QUALIFIER,
            'SET PATH '   || SAVE_PATH                     AS RESTORE_PATH
        FROM
            SYSCAT.VIEWS V
            INNER JOIN SYSCAT.TABLES T
                ON V.VIEWSCHEMA = T.TABSCHEMA
                AND V.VIEWNAME = T.TABNAME
        WHERE
            V.VIEWSCHEMA = ASCHEMA
            AND V.VALID = 'X'
        ORDER BY
            T.CREATE_TIME
    DO
        EXECUTE IMMEDIATE D.SET_PATH;
        EXECUTE IMMEDIATE D.SET_QUALIFIER;
        EXECUTE IMMEDIATE D.TEXT;
        EXECUTE IMMEDIATE D.RESTORE_QUALIFIER;
        EXECUTE IMMEDIATE D.RESTORE_PATH;
    END FOR;
END!

CREATE PROCEDURE RECREATE_VIEWS()
    SPECIFIC RECREATE_VIEWS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL RECREATE_VIEWS(CURRENT SCHEMA);
END!

GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_VIEWS1 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_VIEWS2 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_VIEWS1 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_VIEWS2 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC PROCEDURE RECREATE_VIEWS1
    IS 'Recreates all inoperative views in the specified schema from their system catalogue definitions'!
COMMENT ON SPECIFIC PROCEDURE RECREATE_VIEWS2
    IS 'Recreates all inoperative views in the specified schema from their system catalogue definitions'!

-- RECREATE_TRIGGER(ASCHEMA, ATRIGGER)
-- RECREATE_TRIGGER(ATRIGGER)
-------------------------------------------------------------------------------
-- RECREATE_TRIGGER is a utility procedure which recreates the specified
-- trigger using the SQL found in the system catalog tables. It is useful for
-- quickly recreating triggers which have been marked inoperative after a
-- change to one or more of the trigger's dependencies. If ASCHEMA is omitted
-- it defaults to the current schema.
--
-- NOTE: The procedure does NOT drop the trigger before recreating it. This
-- guards against attempting to recreate an operative trigger (an inoperative
-- trigger can be recreated without dropping it first). That said, it will not
-- return an error in the case of attempting to recreate an operative trigger;
-- the procedure will simply do nothing.
-------------------------------------------------------------------------------

CREATE PROCEDURE RECREATE_TRIGGER(ASCHEMA VARCHAR(128), ATRIGGER VARCHAR(128))
    SPECIFIC RECREATE_TRIGGER1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SAVE_PATH VARCHAR(254);
    DECLARE SAVE_SCHEMA VARCHAR(128);
    SET SAVE_PATH = CURRENT PATH;
    SET SAVE_SCHEMA = CURRENT SCHEMA;
    FOR D AS
        SELECT
            'SET SCHEMA ' || QUOTE_IDENTIFIER(QUALIFIER)   AS SET_QUALIFIER,
            'SET PATH '   || FUNC_PATH                     AS SET_PATH,
            TEXT                                           AS TEXT,
            'SET SCHEMA ' || QUOTE_IDENTIFIER(SAVE_SCHEMA) AS RESTORE_QUALIFIER,
            'SET PATH '   || SAVE_PATH                     AS RESTORE_PATH
        FROM
            SYSCAT.TRIGGERS
        WHERE
            TRIGSCHEMA = ASCHEMA
            AND TRIGNAME = ATRIGGER
            AND VALID = 'X'
    DO
        EXECUTE IMMEDIATE D.SET_QUALIFIER;
        EXECUTE IMMEDIATE D.SET_PATH;
        EXECUTE IMMEDIATE D.TEXT;
        EXECUTE IMMEDIATE D.RESTORE_QUALIFIER;
        EXECUTE IMMEDIATE D.RESTORE_PATH;
    END FOR;
END!

CREATE PROCEDURE RECREATE_TRIGGER(ATRIGGER VARCHAR(128))
    SPECIFIC RECREATE_TRIGGER2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL RECREATE_TRIGGER(CURRENT SCHEMA, ATRIGGER);
END!

GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_TRIGGER1 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_TRIGGER2 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_TRIGGER1 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_TRIGGER2 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC PROCEDURE RECREATE_TRIGGER1
    IS 'Recreates the specified inoperative trigger from its definition in the system catalogue'!
COMMENT ON SPECIFIC PROCEDURE RECREATE_TRIGGER2
    IS 'Recreates the specified inoperative trigger from its definition in the system catalogue'!

-- RECREATE_TRIGGERS(ASCHEMA, ATABLE)
-- RECREATE_TRIGGERS(ATABLE)
-------------------------------------------------------------------------------
-- RECREATE_TRIGGERS is a utility procedure which recreates all inoperative
-- triggers associated with the specified table.
-------------------------------------------------------------------------------

CREATE PROCEDURE RECREATE_TRIGGERS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    SPECIFIC RECREATE_TRIGGERS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SAVE_PATH VARCHAR(254);
    DECLARE SAVE_SCHEMA VARCHAR(128);
    SET SAVE_PATH = CURRENT PATH;
    SET SAVE_SCHEMA = CURRENT SCHEMA;
    FOR D AS
        SELECT
            'SET SCHEMA ' || QUOTE_IDENTIFIER(QUALIFIER)   AS SET_QUALIFIER,
            'SET PATH '   || FUNC_PATH                     AS SET_PATH,
            TEXT                                           AS TEXT,
            'SET SCHEMA ' || QUOTE_IDENTIFIER(SAVE_SCHEMA) AS RESTORE_QUALIFIER,
            'SET PATH '   || SAVE_PATH                     AS RESTORE_PATH
        FROM
            SYSCAT.TRIGGERS
        WHERE
            TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
            AND VALID = 'X'
        ORDER BY
            CREATE_TIME
    DO
        EXECUTE IMMEDIATE D.SET_QUALIFIER;
        EXECUTE IMMEDIATE D.SET_PATH;
        EXECUTE IMMEDIATE D.TEXT;
        EXECUTE IMMEDIATE D.RESTORE_QUALIFIER;
        EXECUTE IMMEDIATE D.RESTORE_PATH;
    END FOR;
END!

CREATE PROCEDURE RECREATE_TRIGGERS(ATABLE VARCHAR(128))
    SPECIFIC RECREATE_TRIGGERS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL RECREATE_TRIGGERS(CURRENT SCHEMA, ATABLE);
END!

GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_TRIGGERS1 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_TRIGGERS2 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_TRIGGERS1 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC PROCEDURE RECREATE_TRIGGERS2 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC PROCEDURE RECREATE_TRIGGERS1
    IS 'Recreates all the inoperative triggers associated with the specified table from their definitions in the system catalogue'!
COMMENT ON SPECIFIC PROCEDURE RECREATE_TRIGGERS2
    IS 'Recreates all the inoperative triggers associated with the specified table from their definitions in the system catalogue'!

-- SAVED_VIEWS
-------------------------------------------------------------------------------
-- A simple table which replicates a portion of the SYSCAT.VIEWS view for use
-- by the SAVE_VIEW and RESTORE_VIEW procedures below.
-------------------------------------------------------------------------------

CREATE TABLE SAVED_VIEWS AS (
    SELECT
        VIEWSCHEMA,
        VIEWNAME,
        QUALIFIER,
        FUNC_PATH,
        TEXT
    FROM SYSCAT.VIEWS
)
WITH NO DATA!

CREATE UNIQUE INDEX SAVED_VIEWS_PK
    ON SAVED_VIEWS(VIEWSCHEMA, VIEWNAME)!

ALTER TABLE SAVED_VIEWS
    ADD CONSTRAINT PK PRIMARY KEY (VIEWSCHEMA, VIEWNAME)!

GRANT CONTROL ON TABLE SAVED_VIEWS TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

-- SAVE_VIEW(ASCHEMA, AVIEW)
-- SAVE_VIEW(AVIEW)
-------------------------------------------------------------------------------
-- SAVE_VIEW is a utility procedure which saves the definition of the specified
-- view to the SAVED_VIEWS table above. This saved definition can then be
-- restored with the RESTORE_VIEW procedure declared below. SAVE_VIEW and
-- RESTORE_VIEW also implicitly call SAVE_AUTH and RESTORE_AUTH to preserve the
-- authorizations of the view. This is in contrast to inoperative views
-- recreated with RECREATE_VIEW which lose authorization information.
-------------------------------------------------------------------------------

CREATE PROCEDURE SAVE_VIEW(ASCHEMA VARCHAR(128), AVIEW VARCHAR(128))
    SPECIFIC SAVE_VIEW1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL SAVE_AUTH(ASCHEMA, AVIEW);
    MERGE INTO SAVED_VIEWS AS DEST
        USING (
            SELECT VIEWSCHEMA, VIEWNAME, QUALIFIER, FUNC_PATH, TEXT
            FROM SYSCAT.VIEWS
            WHERE VIEWSCHEMA = ASCHEMA
            AND VIEWNAME = AVIEW
        ) AS SRC
        ON SRC.VIEWSCHEMA = DEST.VIEWSCHEMA
        AND SRC.VIEWNAME = DEST.VIEWNAME
        WHEN MATCHED THEN
            UPDATE SET (
                QUALIFIER,
                FUNC_PATH,
                TEXT
            ) = (
                SRC.QUALIFIER,
                SRC.FUNC_PATH,
                SRC.TEXT
            )
        WHEN NOT MATCHED THEN
            INSERT (
                VIEWSCHEMA,
                VIEWNAME,
                QUALIFIER,
                FUNC_PATH,
                TEXT
            )
            VALUES (
                SRC.VIEWSCHEMA,
                SRC.VIEWNAME,
                SRC.QUALIFIER,
                SRC.FUNC_PATH,
                SRC.TEXT
            );
END!

CREATE PROCEDURE SAVE_VIEW(AVIEW VARCHAR(128))
    SPECIFIC SAVE_VIEW2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL SAVE_VIEW(CURRENT SCHEMA, AVIEW);
END!

GRANT EXECUTE ON SPECIFIC PROCEDURE SAVE_VIEW1 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE SAVE_VIEW2 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE SAVE_VIEW1 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC PROCEDURE SAVE_VIEW2 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC PROCEDURE SAVE_VIEW1
    IS 'Saves the authorizations and definition of the specified view for later restoration with RESTORE_VIEW'!
COMMENT ON SPECIFIC PROCEDURE SAVE_VIEW2
    IS 'Saves the authorizations and definition of the specified view for later restoration with RESTORE_VIEW'!

-- SAVE_VIEWS(ASCHEMA)
-- SAVE_VIEWS()
-------------------------------------------------------------------------------
-- SAVE_VIEWS is a utility procedure which saves the definitions of all views
-- in the optionally specified schema to the SAVED_VIEWS table above. If
-- ASCHEMA is omitted it defaults to the CURRENT SCHEMA.
-------------------------------------------------------------------------------

CREATE PROCEDURE SAVE_VIEWS(ASCHEMA VARCHAR(128))
    SPECIFIC SAVE_VIEWS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    MERGE INTO SAVED_VIEWS AS DEST
        USING (
            SELECT VIEWSCHEMA, VIEWNAME, QUALIFIER, FUNC_PATH, TEXT
            FROM SYSCAT.VIEWS
            WHERE VIEWSCHEMA = ASCHEMA
        ) AS SRC
        ON SRC.VIEWSCHEMA = DEST.VIEWSCHEMA
        AND SRC.VIEWNAME = DEST.VIEWNAME
        WHEN MATCHED THEN
            UPDATE SET (
                QUALIFIER,
                FUNC_PATH,
                TEXT
            ) = (
                SRC.QUALIFIER,
                SRC.FUNC_PATH,
                SRC.TEXT
            )
        WHEN NOT MATCHED THEN
            INSERT (
                VIEWSCHEMA,
                VIEWNAME,
                QUALIFIER,
                FUNC_PATH,
                TEXT
            )
            VALUES (
                SRC.VIEWSCHEMA,
                SRC.VIEWNAME,
                SRC.QUALIFIER,
                SRC.FUNC_PATH,
                SRC.TEXT
            );
    -- Can't directly use SAVE_AUTHS as that'll also save table authorizations
    -- which we don't want. Instead we call SAVE_AUTH for each view definition
    -- that we save...
    FOR D AS
        SELECT VIEWSCHEMA, VIEWNAME
        FROM SYSCAT.VIEWS
        WHERE VIEWSCHEMA = ASCHEMA
    DO
        CALL SAVE_AUTH(D.VIEWSCHEMA, D.VIEWNAME);
    END FOR;
END!

CREATE PROCEDURE SAVE_VIEWS()
    SPECIFIC SAVE_VIEWS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL SAVE_VIEWS(CURRENT SCHEMA);
END!

GRANT EXECUTE ON SPECIFIC PROCEDURE SAVE_VIEWS1 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE SAVE_VIEWS2 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE SAVE_VIEWS1 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC PROCEDURE SAVE_VIEWS2 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC PROCEDURE SAVE_VIEWS1
    IS 'Saves the authorizations and definitions of all views in the specified schema for later restoration with RESTORE_VIEWS'!
COMMENT ON SPECIFIC PROCEDURE SAVE_VIEWS2
    IS 'Saves the authorizations and definitions of all views in the specified schema for later restoration with RESTORE_VIEWS'!

-- RESTORE_VIEW(ASCHEMA, AVIEW)
-- RESTORE_VIEW(AVIEW)
-------------------------------------------------------------------------------
-- RESTORE_VIEW is a utility procedure which restores the specified view using
-- the SQL found in the SAVED_VIEWS table, which is populated initially by a
-- call to SAVE_VIEW or SAVE_VIEWS. It also implicitly calls RESTORE_AUTH just
-- as SAVE_VIEW calls SAVE_AUTH to ensure that authorizations are not lost.
-- This is the primary difference between using SAVE_VIEW / RESTORE_VIEW and
-- using DB2's inoperative view mechanism with the RECREATE_VIEW procedure.
-- Another use of these procedures is in recreating views which need to be
-- dropped surrounding the update of a UDF.
-------------------------------------------------------------------------------

CREATE PROCEDURE RESTORE_VIEW(ASCHEMA VARCHAR(128), AVIEW VARCHAR(128))
    SPECIFIC RESTORE_VIEW1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE SAVE_PATH VARCHAR(254);
    DECLARE SAVE_SCHEMA VARCHAR(128);
    SET SAVE_PATH = CURRENT PATH;
    SET SAVE_SCHEMA = CURRENT SCHEMA;
    FOR D AS
        SELECT
            'SET SCHEMA ' || QUOTE_IDENTIFIER(QUALIFIER)   AS SET_QUALIFIER,
            'SET PATH '   || FUNC_PATH                     AS SET_PATH,
            TEXT                                           AS TEXT,
            'SET SCHEMA ' || QUOTE_IDENTIFIER(SAVE_SCHEMA) AS RESTORE_QUALIFIER,
            'SET PATH '   || SAVE_PATH                     AS RESTORE_PATH
        FROM
            SAVED_VIEWS
        WHERE
            VIEWSCHEMA = ASCHEMA
            AND VIEWNAME = AVIEW
    DO
        EXECUTE IMMEDIATE D.SET_QUALIFIER;
        EXECUTE IMMEDIATE D.SET_PATH;
        EXECUTE IMMEDIATE D.TEXT;
        EXECUTE IMMEDIATE D.RESTORE_QUALIFIER;
        EXECUTE IMMEDIATE D.RESTORE_PATH;
    END FOR;
    CALL RESTORE_AUTH(ASCHEMA, AVIEW);
    DELETE FROM SAVED_VIEWS
        WHERE VIEWSCHEMA = ASCHEMA
        AND VIEWNAME = AVIEW;
END!

CREATE PROCEDURE RESTORE_VIEW(AVIEW VARCHAR(128))
    SPECIFIC RESTORE_VIEW2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL RESTORE_VIEW(CURRENT SCHEMA, AVIEW);
END!

GRANT EXECUTE ON SPECIFIC PROCEDURE RESTORE_VIEW1 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RESTORE_VIEW2 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RESTORE_VIEW1 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC PROCEDURE RESTORE_VIEW2 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC PROCEDURE RESTORE_VIEW1
    IS 'Restores the specified view which was previously saved with SAVE_VIEW'!
COMMENT ON SPECIFIC PROCEDURE RESTORE_VIEW2
    IS 'Restores the specified view which was previously saved with SAVE_VIEW'!

-- RESTORE_VIEWS(ASCHEMA)
-- RESTORE_VIEWS()
-------------------------------------------------------------------------------
-- RESTORE_VIEWS is a utility procedure which restores all the views in the
-- optionally specified schema from the SAVED_VIEWS table above. If ASCHEMA is
-- omitted it defaults to the CURRENT SCHEMA.
-------------------------------------------------------------------------------

CREATE PROCEDURE RESTORE_VIEWS(ASCHEMA VARCHAR(128))
    SPECIFIC RESTORE_VIEWS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    FOR D AS
        SELECT VIEWNAME
        FROM SAVED_VIEWS
        WHERE VIEWSCHEMA = ASCHEMA
    DO
        CALL RESTORE_VIEW(ASCHEMA, D.VIEWNAME);
    END FOR;
END!

CREATE PROCEDURE RESTORE_VIEWS()
    SPECIFIC RESTORE_VIEWS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL RESTORE_VIEWS(CURRENT SCHEMA);
END!

GRANT EXECUTE ON SPECIFIC PROCEDURE RESTORE_VIEWS1 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RESTORE_VIEWS2 TO ROLE UTILS_EVOLVE_USER!
GRANT EXECUTE ON SPECIFIC PROCEDURE RESTORE_VIEWS1 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC PROCEDURE RESTORE_VIEWS2 TO ROLE UTILS_EVOLVE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC PROCEDURE RESTORE_VIEWS1
    IS 'Restores all views in the specified schema which were previously saved with SAVE_VIEWS'!
COMMENT ON SPECIFIC PROCEDURE RESTORE_VIEWS2
    IS 'Restores all views in the specified schema which were previously saved with SAVE_VIEWS'!

-- vim: set et sw=4 sts=4:
