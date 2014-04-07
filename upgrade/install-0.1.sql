CONNECT TO SAMPLE!
SET SCHEMA UTILS!
SET PATH SYSTEM PATH, USER, UTILS!
-------------------------------------------------------------------------------
-- SQL UTILITIES
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
-- The following functions are used fairly extensively in the other modules for
-- constructing SQL with SQL, including the appropriate escaping.
-------------------------------------------------------------------------------

-- QUOTE_STRING(ASTRING)
-------------------------------------------------------------------------------
-- Returns ASTRING surrounded by single quotes and performs any necessary
-- escaping within the string to make it valid SQL. For example, single quotes
-- within ASTRING are doubled, and control characters like CR or LF are
-- returned as concatenated hex-strings
-------------------------------------------------------------------------------

CREATE FUNCTION QUOTE_STRING(ASTRING VARCHAR(4000))
    RETURNS VARCHAR(4000)
    SPECIFIC QUOTE_STRING1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
BEGIN ATOMIC
    DECLARE I SMALLINT DEFAULT 1;
    DECLARE RESULT VARCHAR(4000) DEFAULT '';
    DECLARE IN_HEX CHAR(1);
    IF ASTRING IS NULL THEN
        RETURN NULL;
    END IF;
    SET IN_HEX = CASE
        WHEN ASCII(SUBSTR(ASTRING, I, 1)) BETWEEN 32 AND 127 THEN 'N'
        ELSE 'Y'
    END;
    SET RESULT = CASE IN_HEX
        WHEN 'Y' THEN 'X'''
        ELSE ''''
    END;
    WHILE I <= LENGTH(ASTRING) DO
        IF ASCII(SUBSTR(ASTRING, I, 1)) BETWEEN 32 AND 127 THEN
            IF IN_HEX = 'Y' THEN
                SET RESULT = RESULT || ''' || ''';
                SET IN_HEX = 'N';
            END IF;
        ELSE
            IF IN_HEX = 'N' THEN
                SET RESULT = RESULT || ''' || X''';
                SET IN_HEX = 'Y';
            END IF;
        END IF;
        SET RESULT = RESULT ||
            CASE IN_HEX
                WHEN 'Y' THEN HEX(SUBSTR(ASTRING, I, 1))
                ELSE REPLACE(SUBSTR(ASTRING, I, 1), '''', '''''')
            END;
        SET I = I + 1;
    END WHILE;
    RETURN RESULT || '''';
END!

COMMENT ON SPECIFIC FUNCTION QUOTE_STRING1
    IS 'Returns ASTRING surrounded by single quotes with all necessary escaping. Useful when constructing SQL for EXECUTE IMMEDIATE within a procedure'!

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
    CASE
        WHEN AIDENT IS NULL THEN NULL
        WHEN
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

COMMENT ON SPECIFIC FUNCTION QUOTE_STRING1
    IS 'If AIDENT is an identifier which requires quoting, returns AIDENT surrounded by double quotes with all contained double quotes doubled. Useful when constructing SQL for EXECUTE IMMEDIATE within a procedure'!

-- vim: set et sw=4 sts=4:
-------------------------------------------------------------------------------
-- AUTHORIZATION UTILITIES
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
-- The following routines aid in manipulating authorizations en masse in the
-- database. The allow all authorizations associated with a given user, group
-- or role to be transferred to other users, groups, or roles, removed
-- entirely, or queried as a whole.
--
-- In each routine, grantees are identified by two parameters, AUTH_NAME which
-- holds the name of the grantee and AUTH_TYPE which holds the type of the
-- grantee where U=User, G=Group, and R=Role. Typically the AUTH_TYPE parameter
-- can be omitted in which case the type will be determined automatically if
-- possible.
-------------------------------------------------------------------------------

-- AUTH_TYPE(AUTH_NAME)
-------------------------------------------------------------------------------
-- This is a utility function used by the COPY_AUTH procedure, and other
-- associated procedures, below. Given an authorization name, this scalar
-- function returns U, G, or R to indicate that the name is a user, group, or
-- role respectively (based on the content of the system catalog tables). If
-- the name is defined, U is returned, unless the name is 'PUBLIC' in which
-- case G is returned (for consistency with the catalog tables). If the name
-- represents multiple authorization types, SQLSTATE 21000 is raised.
-------------------------------------------------------------------------------

CREATE FUNCTION AUTH_TYPE(AUTH_NAME VARCHAR(128))
    RETURNS VARCHAR(1)
    SPECIFIC AUTH_TYPE1
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    VALUES COALESCE((
        SELECT GRANTEETYPE FROM SYSCAT.DBAUTH              WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.ROLEAUTH            WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.TBSPACEAUTH         WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.WORKLOADAUTH        WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.SECURITYLABELACCESS WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.PASSTHRUAUTH        WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.SCHEMAAUTH          WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.TABAUTH             WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.COLAUTH             WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.INDEXAUTH           WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.PACKAGEAUTH         WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.VARIABLEAUTH        WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.SEQUENCEAUTH        WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.XSROBJECTAUTH       WHERE GRANTEE = AUTH_NAME UNION
        SELECT GRANTEETYPE FROM SYSCAT.ROUTINEAUTH         WHERE GRANTEE = AUTH_NAME UNION
        SELECT 'R'         FROM SYSCAT.ROLES               WHERE ROLENAME = AUTH_NAME
    ), CASE AUTH_NAME WHEN 'PUBLIC' THEN 'G' ELSE 'U' END)!

COMMENT ON SPECIFIC FUNCTION AUTH_TYPE1
    IS 'Utility routine used by other routines to determine the type of an authorization name when it isn''t explicitly given'!

-- AUTHS_HELD(AUTH_NAME, AUTH_TYPE, INCLUDE_COLUMNS, INCLUDE_PERSONAL)
-- AUTHS_HELD(AUTH_NAME, INCLUDE_COLUMNS, INCLUDE_PERSONAL)
-- AUTHS_HELD(AUTH_NAME, INCLUDE_COLUMNS)
-- AUTHS_HELD(AUTH_NAME)
-------------------------------------------------------------------------------
-- This is a utility function used by the COPY_AUTH procedure, and other
-- associated procedures, below. Given an authorization name and type, and a
-- couple of flags, this table function returns the details of all the
-- authorizations held by that name. The information returned is sufficient for
-- comparison of authorizations and generation of GRANT/REVOKE statements. The
-- AUTH_TYPE parameter can be omitted in which case the AUTH_TYPE function
-- above will be used to determine the type of AUTH_NAME. If specified, it must
-- have a value of 'U', 'G', or 'R' for user, group or role respectively.
--
-- The INCLUDE_COLUMNS parameter specifies whether column-level REFERENCES
-- and UPDATES authorziations are included ('Y') or excluded ('N'). This is
-- useful when generating REVOKE statements from the result (column level
-- authorizations cannot be revoked directly). This parameter is optional
-- and defaults to 'N' if omitted.
--
-- The INCLUDE_PERSONAL parameter specifies whether, in the case where
-- AUTH_NAME is a user, the content of the user's personal schema will be
-- included in the result set ('Y') or not ('N'). This parameter is optional
-- and defaults to 'N' if omitted.
-------------------------------------------------------------------------------

CREATE FUNCTION AUTHS_HELD(
    AUTH_NAME VARCHAR(128),
    AUTH_TYPE VARCHAR(1),
    INCLUDE_COLUMNS VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    RETURNS TABLE (
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        AUTH VARCHAR(140),
        SUFFIX VARCHAR(20),
        LEVEL SMALLINT
    )
    SPECIFIC AUTHS_HELD1
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    WITH DB_AUTHS_1 AS (
        SELECT *
        FROM SYSCAT.DBAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
    ),
    DB_AUTHS_2(AUTH) AS (
        SELECT 'BINDADD'                   FROM DB_AUTHS_1 WHERE BINDADDAUTH         = 'Y' UNION ALL
        SELECT 'CONNECT'                   FROM DB_AUTHS_1 WHERE CONNECTAUTH         = 'Y' UNION ALL
        SELECT 'CREATETAB'                 FROM DB_AUTHS_1 WHERE CREATETABAUTH       = 'Y' UNION ALL
        SELECT 'DBADM'                     FROM DB_AUTHS_1 WHERE DBADMAUTH           = 'Y' UNION ALL
        SELECT 'CREATE_EXTERNAL_ROUTINE'   FROM DB_AUTHS_1 WHERE EXTERNALROUTINEAUTH = 'Y' UNION ALL
        SELECT 'CREATE_NOT_FENCED_ROUTINE' FROM DB_AUTHS_1 WHERE NOFENCEAUTH         = 'Y' UNION ALL
        SELECT 'IMPLICIT_SCHEMA'           FROM DB_AUTHS_1 WHERE IMPLSCHEMAAUTH      = 'Y' UNION ALL
        SELECT 'LOAD'                      FROM DB_AUTHS_1 WHERE LOADAUTH            = 'Y' UNION ALL
        SELECT 'QUIESCE_CONNECT'           FROM DB_AUTHS_1 WHERE QUIESCECONNECTAUTH  = 'Y' UNION ALL
        SELECT 'SECADM'                    FROM DB_AUTHS_1 WHERE SECURITYADMAUTH     = 'Y'
    ),
    DB_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'DATABASE',
            '',
            AUTH,
            '',
            0
        FROM DB_AUTHS_2
    ),
    ROLE_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            '',
            '',
            'ROLE ' || QUOTE_IDENTIFIER(ROLENAME),
            CASE ADMIN WHEN 'Y' THEN 'WITH ADMIN OPTION' ELSE '' END,
            CASE ADMIN WHEN 'Y' THEN 1 ELSE 0 END
        FROM SYSCAT.ROLEAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
    ),
    SURROGATE_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            CASE SURROGATEAUTHIDTYPE
                WHEN 'G' THEN 'PUBLIC'
                WHEN 'U' THEN 'USER'
            END,
            CASE SURROGATEAUTHIDTYPE
                WHEN 'G' THEN ''
                WHEN 'U' THEN SURROGATEAUTHID
            END,
            'SETSESSIONUSER',
            '',
            0
        FROM SYSCAT.SURROGATEAUTHIDS
        WHERE TRUSTEDID = AUTH_NAME
            AND TRUSTEDIDTYPE = AUTH_TYPE
    ),
    TBSPACE_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'TABLESPACE',
            QUOTE_IDENTIFIER(TBSPACE),
            'USE',
            CASE USEAUTH WHEN 'G' THEN 'WITH GRANT OPTION' ELSE '' END,
            CASE USEAUTH WHEN 'G' THEN 1 ELSE 0 END
        FROM SYSCAT.TBSPACEAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND USEAUTH IN ('Y', 'G')
    ),
    WORKLOAD_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'WORKLOAD',
            QUOTE_IDENTIFIER(WORKLOADNAME),
            'USAGE',
            '',
            0
        FROM SYSCAT.WORKLOADAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND USAGEAUTH = 'Y'
    ),
    SECLABEL_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            '',
            '',
            'SECURITY LABEL ' || QUOTE_IDENTIFIER(P.SECPOLICYNAME) || '.' || QUOTE_IDENTIFIER(L.SECLABELNAME),
            'FOR ' || CASE A.ACCESSTYPE
                WHEN 'B' THEN 'ALL'
                WHEN 'R' THEN 'READ'
                WHEN 'W' THEN 'WRITE'
            END || ' ACCESS',
            CASE A.ACCESSTYPE WHEN 'B' THEN 1 ELSE 0 END
        FROM
            SYSCAT.SECURITYLABELACCESS A
            INNER JOIN SYSCAT.SECURITYLABELS L ON A.SECLABELID = L.SECLABELID
            INNER JOIN SYSCAT.SECURITYPOLICIES P ON A.SECPOLICYID = P.SECPOLICYID
        WHERE A.GRANTEE = AUTH_NAME
            AND A.GRANTEETYPE = AUTH_TYPE
    ),
    SERVER_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'SERVER',
            QUOTE_IDENTIFIER(SERVERNAME),
            'PASSTHRU',
            '',
            0
        FROM SYSCAT.PASSTHRUAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
    ),
    SCHEMA_AUTHS_1 AS (
        SELECT *
        FROM SYSCAT.SCHEMAAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> SCHEMANAME
            )
    ),
    SCHEMA_AUTHS_2(SCHEMANAME, AUTH, GRANTABLE) AS (
        SELECT SCHEMANAME, 'ALTERIN',  ALTERINAUTH  FROM SCHEMA_AUTHS_1 WHERE ALTERINAUTH  IN ('Y', 'G') UNION ALL
        SELECT SCHEMANAME, 'CREATEIN', CREATEINAUTH FROM SCHEMA_AUTHS_1 WHERE CREATEINAUTH IN ('Y', 'G') UNION ALL
        SELECT SCHEMANAME, 'DROPIN',   DROPINAUTH   FROM SCHEMA_AUTHS_1 WHERE DROPINAUTH   IN ('Y',' G')
    ),
    SCHEMA_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'SCHEMA',
            QUOTE_IDENTIFIER(SCHEMANAME),
            AUTH,
            CASE GRANTABLE WHEN 'G' THEN 'WITH GRANT OPTION' ELSE '' END,
            CASE GRANTABLE WHEN 'G' THEN 1 ELSE 0 END
        FROM SCHEMA_AUTHS_2
    ),
    TABLE_AUTHS_1 AS (
        SELECT *
        FROM SYSCAT.TABAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> TABSCHEMA
            )
    ),
    TABLE_AUTHS_2(TABSCHEMA, TABNAME, AUTH, GRANTABLE) AS (
        SELECT TABSCHEMA, TABNAME, 'CONTROL',    'Y'        FROM TABLE_AUTHS_1 WHERE CONTROLAUTH = 'Y'        UNION ALL
        SELECT TABSCHEMA, TABNAME, 'ALTER',      ALTERAUTH  FROM TABLE_AUTHS_1 WHERE ALTERAUTH  IN ('Y', 'G') UNION ALL
        SELECT TABSCHEMA, TABNAME, 'DELETE',     DELETEAUTH FROM TABLE_AUTHS_1 WHERE DELETEAUTH IN ('Y', 'G') UNION ALL
        SELECT TABSCHEMA, TABNAME, 'INDEX',      INDEXAUTH  FROM TABLE_AUTHS_1 WHERE INDEXAUTH  IN ('Y', 'G') UNION ALL
        SELECT TABSCHEMA, TABNAME, 'INSERT',     INSERTAUTH FROM TABLE_AUTHS_1 WHERE INSERTAUTH IN ('Y', 'G') UNION ALL
        SELECT TABSCHEMA, TABNAME, 'REFERENCES', REFAUTH    FROM TABLE_AUTHS_1 WHERE REFAUTH    IN ('Y', 'G') UNION ALL
        SELECT TABSCHEMA, TABNAME, 'SELECT',     SELECTAUTH FROM TABLE_AUTHS_1 WHERE SELECTAUTH IN ('Y', 'G') UNION ALL
        SELECT TABSCHEMA, TABNAME, 'UPDATE',     UPDATEAUTH FROM TABLE_AUTHS_1 WHERE UPDATEAUTH IN ('Y', 'G') 
    ),
    TABLE_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'TABLE',
            QUOTE_IDENTIFIER(TABSCHEMA) || '.' || QUOTE_IDENTIFIER(TABNAME),
            AUTH,
            CASE GRANTABLE WHEN 'G' THEN 'WITH GRANT OPTION' ELSE '' END,
            CASE GRANTABLE WHEN 'G' THEN 1 ELSE 0 END
        FROM TABLE_AUTHS_2
    ),
    COLUMN_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'TABLE',
            QUOTE_IDENTIFIER(TABSCHEMA) || '.' || QUOTE_IDENTIFIER(TABNAME),
            CASE PRIVTYPE
                WHEN 'R' THEN 'REFERENCES'
                WHEN 'U' THEN 'UPDATE'
            END || '(' || COLNAME || ')',
            CASE GRANTABLE WHEN 'G' THEN 'WITH GRANT OPTION' ELSE '' END,
            CASE GRANTABLE WHEN 'G' THEN 1 ELSE 0 END
        FROM SYSCAT.COLAUTH
        WHERE
            GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND INCLUDE_COLUMNS = 'Y'
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> TABSCHEMA
            )
    ),
    INDEX_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'INDEX',
            QUOTE_IDENTIFIER(INDSCHEMA) || '.' || QUOTE_IDENTIFIER(INDNAME),
            'CONTROL',
            '',
            0
        FROM SYSCAT.INDEXAUTH
        WHERE
            GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND CONTROLAUTH = 'Y'
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> INDSCHEMA
            )
    ),
    PACKAGE_AUTHS_1 AS (
        SELECT *
        FROM SYSCAT.PACKAGEAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> PKGSCHEMA
            )
    ),
    PACKAGE_AUTHS_2(PKGSCHEMA, PKGNAME, AUTH, GRANTABLE) AS (
        SELECT PKGSCHEMA, PKGNAME, 'CONTROL', CONTROLAUTH FROM PACKAGE_AUTHS_1 WHERE CONTROLAUTH IN ('Y', 'G') UNION ALL
        SELECT PKGSCHEMA, PKGNAME, 'BIND',    BINDAUTH    FROM PACKAGE_AUTHS_1 WHERE BINDAUTH    IN ('Y', 'G') UNION ALL
        SELECT PKGSCHEMA, PKGNAME, 'EXECUTE', EXECUTEAUTH FROM PACKAGE_AUTHS_1 WHERE EXECUTEAUTH IN ('Y', 'G')
    ),
    PACKAGE_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'PACKAGE',
            QUOTE_IDENTIFIER(PKGSCHEMA) || '.' || QUOTE_IDENTIFIER(PKGNAME),
            AUTH,
            CASE GRANTABLE WHEN 'G' THEN 'WITH GRANT OPTION' ELSE '' END,
            CASE GRANTABLE WHEN 'G' THEN 1 ELSE 0 END
        FROM PACKAGE_AUTHS_2
    ),
    VARIABLE_AUTHS_1 AS (
        SELECT *
        FROM SYSCAT.VARIABLEAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> VARSCHEMA
            )
    ),
    VARIABLE_AUTHS_2(VARSCHEMA, VARNAME, AUTH, GRANTABLE) AS (
        SELECT VARSCHEMA, VARNAME, 'READ',  READAUTH  FROM VARIABLE_AUTHS_1 WHERE READAUTH  IN ('Y', 'G') UNION ALL
        SELECT VARSCHEMA, VARNAME, 'WRITE', WRITEAUTH FROM VARIABLE_AUTHS_1 WHERE WRITEAUTH IN ('Y', 'G')
    ),
    VARIABLE_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'VARIABLE',
            QUOTE_IDENTIFIER(VARSCHEMA) || '.' || QUOTE_IDENTIFIER(VARNAME),
            AUTH,
            CASE GRANTABLE WHEN 'G' THEN 'WITH GRANT OPTION' ELSE '' END,
            CASE GRANTABLE WHEN 'G' THEN 1 ELSE 0 END
        FROM VARIABLE_AUTHS_2
    ),
    SEQUENCE_AUTHS_1 AS (
        SELECT *
        FROM SYSCAT.SEQUENCEAUTH
        WHERE GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> SEQSCHEMA
            )
    ),
    SEQUENCE_AUTHS_2(SEQSCHEMA, SEQNAME, AUTH, GRANTABLE) AS (
        SELECT SEQSCHEMA, SEQNAME, 'ALTER', ALTERAUTH FROM SEQUENCE_AUTHS_1 WHERE ALTERAUTH IN ('Y', 'G') UNION ALL
        SELECT SEQSCHEMA, SEQNAME, 'USAGE', USAGEAUTH FROM SEQUENCE_AUTHS_1 WHERE USAGEAUTH IN ('Y', 'G')
    ),
    SEQUENCE_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'SEQUENCE',
            QUOTE_IDENTIFIER(SEQSCHEMA) || '.' || QUOTE_IDENTIFIER(SEQNAME),
            AUTH,
            CASE GRANTABLE WHEN 'G' THEN 'WITH GRANT OPTION' ELSE '' END,
            CASE GRANTABLE WHEN 'G' THEN 1 ELSE 0 END
        FROM SEQUENCE_AUTHS_2
    ),
    XSR_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            'XSROBJECT',
            QUOTE_IDENTIFIER(O.OBJECTSCHEMA) || '.' || QUOTE_IDENTIFIER(O.OBJECTNAME),
            'USAGE',
            '',
            0
        FROM
            SYSCAT.XSROBJECTAUTH A
            INNER JOIN SYSCAT.XSROBJECTS O
                ON A.OBJECTID = O.OBJECTID
        WHERE
            GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND USAGEAUTH = 'Y'
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> O.OBJECTSCHEMA
            )
    ),
    ROUTINE_AUTHS(OBJECT_TYPE, OBJECT_ID, AUTH, SUFFIX, LEVEL) AS (
        SELECT
            CASE WHEN SPECIFICNAME IS NOT NULL
                THEN 'SPECIFIC '
                ELSE ''
            END ||
            CASE ROUTINETYPE
                WHEN 'F' THEN 'FUNCTION'
                WHEN 'P' THEN 'PROCEDURE'
            END,
            QUOTE_IDENTIFIER(SCHEMA) || '.' ||
            CASE WHEN SPECIFICNAME IS NOT NULL
                THEN QUOTE_IDENTIFIER(SPECIFICNAME)
                ELSE '*'
            END,
            'EXECUTE',
            CASE EXECUTEAUTH WHEN 'G' THEN 'WITH GRANT OPTION' ELSE '' END,
            CASE EXECUTEAUTH WHEN 'G' THEN 1 ELSE 0 END
        FROM SYSCAT.ROUTINEAUTH
        WHERE
            GRANTEE = AUTH_NAME
            AND GRANTEETYPE = AUTH_TYPE
            AND EXECUTEAUTH IN ('Y', 'G')
            AND (
                INCLUDE_PERSONAL = 'Y'
                OR AUTH_TYPE <> 'U'
                OR AUTH_NAME <> SCHEMA
            )
    )
    SELECT * FROM DB_AUTHS        UNION
    SELECT * FROM ROLE_AUTHS      UNION
    SELECT * FROM SURROGATE_AUTHS UNION
    SELECT * FROM TBSPACE_AUTHS   UNION
    SELECT * FROM WORKLOAD_AUTHS  UNION
    SELECT * FROM SECLABEL_AUTHS  UNION
    SELECT * FROM SERVER_AUTHS    UNION
    SELECT * FROM SCHEMA_AUTHS    UNION
    SELECT * FROM TABLE_AUTHS     UNION
    SELECT * FROM COLUMN_AUTHS    UNION
    SELECT * FROM INDEX_AUTHS     UNION
    SELECT * FROM PACKAGE_AUTHS   UNION
    SELECT * FROM VARIABLE_AUTHS  UNION
    SELECT * FROM SEQUENCE_AUTHS  UNION
    SELECT * FROM XSR_AUTHS       UNION
    SELECT * FROM ROUTINE_AUTHS!

CREATE FUNCTION AUTHS_HELD(
    AUTH_NAME VARCHAR(128),
    INCLUDE_COLUMNS VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    RETURNS TABLE (
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        AUTH VARCHAR(140),
        SUFFIX VARCHAR(20),
        LEVEL SMALLINT
    )
    SPECIFIC AUTHS_HELD2
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    SELECT *
    FROM TABLE(AUTHS_HELD(
        AUTH_NAME,
        AUTH_TYPE(AUTH_NAME),
        INCLUDE_COLUMNS,
        INCLUDE_PERSONAL
    )) AS T!

CREATE FUNCTION AUTHS_HELD(
    AUTH_NAME VARCHAR(128),
    INCLUDE_COLUMNS VARCHAR(1)
)
    RETURNS TABLE (
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        AUTH VARCHAR(140),
        SUFFIX VARCHAR(20),
        LEVEL SMALLINT
    )
    SPECIFIC AUTHS_HELD3
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    SELECT *
    FROM TABLE(AUTHS_HELD(
        AUTH_NAME,
        AUTH_TYPE(AUTH_NAME),
        INCLUDE_COLUMNS,
        'N'
    )) AS T!

CREATE FUNCTION AUTHS_HELD(
    AUTH_NAME VARCHAR(128)
)
    RETURNS TABLE (
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        AUTH VARCHAR(140),
        SUFFIX VARCHAR(20),
        LEVEL SMALLINT
    )
    SPECIFIC AUTHS_HELD4
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    SELECT *
    FROM TABLE(AUTHS_HELD(
        AUTH_NAME,
        AUTH_TYPE(AUTH_NAME),
        'N',
        'N'
    )) AS T!

COMMENT ON SPECIFIC FUNCTION AUTHS_HELD1
    IS 'Utility table function which returns all the authorizations held by a specific name'!
COMMENT ON SPECIFIC FUNCTION AUTHS_HELD2
    IS 'Utility table function which returns all the authorizations held by a specific name'!
COMMENT ON SPECIFIC FUNCTION AUTHS_HELD3
    IS 'Utility table function which returns all the authorizations held by a specific name'!
COMMENT ON SPECIFIC FUNCTION AUTHS_HELD4
    IS 'Utility table function which returns all the authorizations held by a specific name'!

-- AUTH_DIFF(SOURCE, SOURCE_TYPE, DEST, DEST_TYPE, INCLUDE_COLUMNS, INCLUDE_PERSONAL)
-- AUTH_DIFF(SOURCE, DEST, INCLUDE_COLUMNS, INCLUDE_PERSONAL)
-- AUTH_DIFF(SOURCE, DEST, INCLUDE_COLUMNS)
-- AUTH_DIFF(SOURCE, DEST)
-------------------------------------------------------------------------------
-- This utility function determines the difference in authorizations held by
-- two different entities. Essentially it takes the authorizations of the
-- SOURCE entity and "subtracts" the authorizations of the DEST entity, the
-- result being the authorizations that need to be granted to DEST to give it
-- the same level of access as SOURCE. The optional SOURCE_TYPE and DEST_TYPE
-- parameters indicate the type of SOURCE and DEST respectively and may be
-- 'U', 'G', or 'R', for user, group, or role respectively. If omitted, the
-- types of SOURCE and DEST will be determined by the AUTH_TYPE function above.
--
-- The INCLUDE_COLUMNS parameter determines if column level authorizations are
-- included in the results ('Y') or not ('N'). Defaults to 'N' if omitted.
--
-- The optional INCLUDE_PERSONAL parameter determines whether, in the case
-- where SOURCE is a user, the content of the user's personal schema will be
-- included in the result set ('Y') or not ('N'). Defaults to 'N' if omitted.
-------------------------------------------------------------------------------

CREATE FUNCTION AUTH_DIFF(
    SOURCE VARCHAR(128),
    SOURCE_TYPE VARCHAR(1),
    DEST VARCHAR(128),
    DEST_TYPE VARCHAR(1),
    INCLUDE_COLUMNS VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    RETURNS TABLE(
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        AUTH VARCHAR(140),
        SUFFIX VARCHAR(20),
        LEVEL SMALLINT
    )
    SPECIFIC AUTH_DIFF1
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    WITH SOURCE_AUTHS AS (
        SELECT * FROM TABLE(AUTHS_HELD(
            SOURCE,
            SOURCE_TYPE,
            INCLUDE_COLUMNS,
            INCLUDE_PERSONAL
        )) AS T
    ),
    DEST_AUTHS AS (
        SELECT * FROM TABLE(AUTHS_HELD(
            DEST, 
            DEST_TYPE,
            INCLUDE_COLUMNS,
            INCLUDE_PERSONAL
        )) AS T
    ),
    MISSING_AUTHS AS (
        SELECT OBJECT_TYPE, OBJECT_ID, AUTH FROM SOURCE_AUTHS EXCEPT
        SELECT OBJECT_TYPE, OBJECT_ID, AUTH FROM DEST_AUTHS
    ),
    MISSING_DIFF AS (
        SELECT SA.*
        FROM
            MISSING_AUTHS MA
            INNER JOIN SOURCE_AUTHS SA
                ON MA.OBJECT_TYPE = SA.OBJECT_TYPE
                AND MA.OBJECT_ID = SA.OBJECT_ID
                AND MA.AUTH = SA.AUTH
    ),
    UPGRADE_AUTHS AS (
        SELECT OBJECT_TYPE, OBJECT_ID, AUTH FROM SOURCE_AUTHS INTERSECT
        SELECT OBJECT_TYPE, OBJECT_ID, AUTH FROM DEST_AUTHS
    ),
    UPGRADE_DIFF AS (
        SELECT SA.*
        FROM
            UPGRADE_AUTHS UA
            INNER JOIN SOURCE_AUTHS SA
                ON UA.OBJECT_TYPE = SA.OBJECT_TYPE
                AND UA.OBJECT_ID = SA.OBJECT_ID
                AND UA.AUTH = SA.AUTH
            INNER JOIN DEST_AUTHS DA
                ON UA.OBJECT_TYPE = DA.OBJECT_TYPE
                AND UA.OBJECT_ID = DA.OBJECT_ID
                AND UA.AUTH = DA.AUTH
        WHERE SA.LEVEL > DA.LEVEL
    )
    SELECT * FROM MISSING_DIFF UNION
    SELECT * FROM UPGRADE_DIFF!

CREATE FUNCTION AUTH_DIFF(
    SOURCE VARCHAR(128),
    DEST VARCHAR(128),
    INCLUDE_COLUMNS VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    RETURNS TABLE(
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        AUTH VARCHAR(140),
        SUFFIX VARCHAR(20),
        LEVEL SMALLINT
    )
    SPECIFIC AUTH_DIFF2
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    SELECT *
    FROM TABLE(AUTH_DIFF(
        SOURCE,
        AUTH_TYPE(SOURCE),
        DEST,
        AUTH_TYPE(DEST),
        INCLUDE_COLUMNS,
        INCLUDE_PERSONAL
    )) AS T!

CREATE FUNCTION AUTH_DIFF(
    SOURCE           VARCHAR(128),
    DEST             VARCHAR(128),
    INCLUDE_COLUMNS  VARCHAR(1)
)
    RETURNS TABLE(
        OBJECT_TYPE  VARCHAR(18),
        OBJECT_ID    VARCHAR(262),
        AUTH         VARCHAR(140),
        SUFFIX       VARCHAR(20),
        LEVEL        SMALLINT
    )
    SPECIFIC AUTH_DIFF3
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    SELECT *
    FROM TABLE(AUTH_DIFF(
        SOURCE,
        AUTH_TYPE(SOURCE),
        DEST,
        AUTH_TYPE(DEST),
        INCLUDE_COLUMNS,
        'N'
    )) AS T!

CREATE FUNCTION AUTH_DIFF(
    SOURCE           VARCHAR(128),
    DEST             VARCHAR(128)
)
    RETURNS TABLE(
        OBJECT_TYPE  VARCHAR(18),
        OBJECT_ID    VARCHAR(262),
        AUTH         VARCHAR(140),
        SUFFIX       VARCHAR(20),
        LEVEL        SMALLINT
    )
    SPECIFIC AUTH_DIFF4
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    SELECT *
    FROM TABLE(AUTH_DIFF(
        SOURCE,
        AUTH_TYPE(SOURCE),
        DEST,
        AUTH_TYPE(DEST),
        'N',
        'N'
    )) AS T!

COMMENT ON SPECIFIC FUNCTION AUTH_DIFF1
    IS 'Utility table function which returns the difference between the authorities held by two names'!
COMMENT ON SPECIFIC FUNCTION AUTH_DIFF2
    IS 'Utility table function which returns the difference between the authorities held by two names'!
COMMENT ON SPECIFIC FUNCTION AUTH_DIFF3
    IS 'Utility table function which returns the difference between the authorities held by two names'!
COMMENT ON SPECIFIC FUNCTION AUTH_DIFF4
    IS 'Utility table function which returns the difference between the authorities held by two names'!

-- COPY_AUTH(SOURCE, SOURCE_TYPE, DEST, DEST_TYPE, INCLUDE_PERSONAL)
-- COPY_AUTH(SOURCE, DEST, INCLUDE_PERSONAL)
-- COPY_AUTH(SOURCE, DEST)
-------------------------------------------------------------------------------
-- COPY_AUTH is a procedure which copies all authorizations from the source
-- grantee (SOURCE) to the destination grantee (DEST). Note that the
-- implementation does not preserve the grantor, although technically this
-- would be possible by utilizing the SET SESSION USER facility introduced by
-- DB2 9, nor does it remove extra permissions that the destination grantee
-- already possessed prior to the call. Furthermore, method authorizations are
-- not copied.
--
-- The optional SOURCE_TYPE and DEST_TYPE parameters specify whether SOURCE and
-- DEST refer to a user ('U'), group ('G'), or role ('R') respectively. If
-- omitted the procedure will use the AUTH_TYPE function above to determine the
-- type.
--
-- The optional INCLUDE_PERSONAL parameter specifies whether to include the
-- authorizations for SOURCE's personal schema ('Y') or not ('N'). Defaults to
-- 'N' if omitted, and has no effect in the case where SOURCE is not a user.
-------------------------------------------------------------------------------

CREATE FUNCTION COPY$LIST(
    SOURCE VARCHAR(128),
    SOURCE_TYPE VARCHAR(1),
    DEST VARCHAR(128),
    DEST_TYPE VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    RETURNS TABLE (
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        DDL VARCHAR(2000)
    )
    SPECIFIC COPY$LIST
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    SELECT
        OBJECT_TYPE,
        OBJECT_ID,
        'GRANT ' || AUTH ||
        CASE OBJECT_TYPE
            WHEN '' THEN ''
            ELSE
                CASE OBJECT_TYPE
                    WHEN 'TABLESPACE' THEN ' OF '
                    ELSE ' ON '
                END || OBJECT_TYPE || ' ' || OBJECT_ID
        END || ' TO ' ||
        CASE DEST_TYPE
            WHEN 'U' THEN 'USER ' || QUOTE_IDENTIFIER(DEST)
            WHEN 'R' THEN 'ROLE ' || QUOTE_IDENTIFIER(DEST)
            WHEN 'G' THEN
                CASE DEST
                    WHEN 'PUBLIC' THEN DEST
                    ELSE 'GROUP ' || QUOTE_IDENTIFIER(DEST)
                END
        END || ' ' || SUFFIX AS DDL
    FROM
        TABLE(AUTH_DIFF(
            SOURCE,
            SOURCE_TYPE,
            DEST,
            DEST_TYPE,
            CHAR('Y'),
            INCLUDE_PERSONAL
        )) AS T!

CREATE PROCEDURE COPY_AUTH(
    SOURCE VARCHAR(128),
    SOURCE_TYPE VARCHAR(1),
    DEST VARCHAR(128),
    DEST_TYPE VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    SPECIFIC COPY_AUTH1
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE EXIT HANDLER FOR SQLSTATE '21000'
        SIGNAL SQLSTATE '80002'
        SET MESSAGE_TEXT = 'Ambiguous type for authorization name';
    FOR D AS
        SELECT DDL
        FROM TABLE(COPY$LIST(SOURCE, SOURCE_TYPE, DEST, DEST_TYPE, INCLUDE_PERSONAL))
    DO
        EXECUTE IMMEDIATE D.DDL;
    END FOR;
END!

CREATE PROCEDURE COPY_AUTH(
    SOURCE VARCHAR(128),
    DEST VARCHAR(128),
    INCLUDE_PERSONAL VARCHAR(1)
)
    SPECIFIC COPY_AUTH2
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    CALL COPY_AUTH(SOURCE, AUTH_TYPE(SOURCE), DEST, AUTH_TYPE(DEST), INCLUDE_PERSONAL);
END!

CREATE PROCEDURE COPY_AUTH(
    SOURCE VARCHAR(128),
    DEST VARCHAR(128)
)
    SPECIFIC COPY_AUTH3
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    CALL COPY_AUTH(SOURCE, AUTH_TYPE(SOURCE), DEST, AUTH_TYPE(DEST), 'N');
END!

COMMENT ON SPECIFIC PROCEDURE COPY_AUTH1
    IS 'Grants all authorities held by the source to the target, provided they are not already held (i.e. does not "re-grant" authorities already held)'!
COMMENT ON SPECIFIC PROCEDURE COPY_AUTH2
    IS 'Grants all authorities held by the source to the target, provided they are not already held (i.e. does not "re-grant" authorities already held)'!
COMMENT ON SPECIFIC PROCEDURE COPY_AUTH3
    IS 'Grants all authorities held by the source to the target, provided they are not already held (i.e. does not "re-grant" authorities already held)'!

-- REMOVE_AUTH(AUTH_NAME, AUTH_TYPE, INCLUDE_PERSONAL)
-- REMOVE_AUTH(AUTH_NAME, INCLUDE_PERSONAL)
-- REMOVE_AUTH(AUTH_NAME)
-------------------------------------------------------------------------------
-- REMOVE_AUTH is a procedure which removes all authorizations from the entity
-- specified by AUTH_NAME, and optionally AUTH_TYPE. If AUTH_TYPE is omitted
-- the AUTH_TYPE function above will be used to determine it. Otherwise, it
-- must be 'U', 'G', or 'R', standing for user, group or role respectively.
--
-- The optional INCLUDE_PERSONAL parameter indicates whether authorizations
-- covering a user's personal schema are affected, in the case where AUTH_NAME
-- refers to a user. If omitted, it defaults to 'N', meaning the user will
-- still have access to all objects within their personal schema afterward.
--
-- Note: this routine will not handle revoking column level authorizations,
-- i.e. REFERENCES and UPDATES, which cannot be revoked directly but rather
-- have to be revoked overall at the table level. Any such authorziations must
-- be handled manually.
-------------------------------------------------------------------------------

CREATE FUNCTION REMOVE$LIST(
    AUTH_NAME VARCHAR(128),
    AUTH_TYPE VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    RETURNS TABLE (
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        DDL VARCHAR(2000)
    )
    SPECIFIC REMOVE$LIST
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
    LANGUAGE SQL
RETURN
    SELECT
        OBJECT_TYPE,
        OBJECT_ID,
        'REVOKE ' || AUTH ||
        CASE OBJECT_TYPE
            WHEN '' THEN ''
            ELSE
                CASE OBJECT_TYPE
                    WHEN 'TABLESPACE' THEN ' OF '
                    ELSE ' ON '
                END || OBJECT_TYPE || ' ' || OBJECT_ID
        END || ' FROM ' ||
        CASE AUTH_TYPE
            WHEN 'U' THEN 'USER ' || QUOTE_IDENTIFIER(AUTH_NAME)
            WHEN 'R' THEN 'ROLE ' || QUOTE_IDENTIFIER(AUTH_NAME)
            WHEN 'G' THEN
                CASE AUTH_NAME
                    WHEN 'PUBLIC' THEN AUTH_NAME
                    ELSE 'GROUP ' || QUOTE_IDENTIFIER(AUTH_NAME)
                END
        END || ' ' ||
        CASE OBJECT_TYPE
            WHEN 'SPECIFIC FUNCTION'  THEN 'RESTRICT'
            WHEN 'SPECIFIC PROCEDURE' THEN 'RESTRICT'
            WHEN 'FUNCTION'           THEN 'RESTRICT'
            WHEN 'PROCEDURE'          THEN 'RESTRICT'
            ELSE ''
        END AS DDL
    FROM
        TABLE(AUTHS_HELD(
            AUTH_NAME,
            AUTH_TYPE,
            'N',
            INCLUDE_PERSONAL
        )) AS T!

CREATE PROCEDURE REMOVE_AUTH(
    AUTH_NAME VARCHAR(128),
    AUTH_TYPE VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    SPECIFIC REMOVE_AUTH1
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    DECLARE EXIT HANDLER FOR SQLSTATE '21000'
        SIGNAL SQLSTATE '80002'
        SET MESSAGE_TEXT = 'Ambiguous type for authorization name';
    FOR D AS
        SELECT DDL
        FROM TABLE(REMOVE$LIST(AUTH_NAME, AUTH_TYPE, INCLUDE_PERSONAL))
    DO
        EXECUTE IMMEDIATE D.DDL;
    END FOR;
END!

CREATE PROCEDURE REMOVE_AUTH(
    AUTH_NAME VARCHAR(128),
    INCLUDE_PERSONAL CHAR(1)
)
    SPECIFIC REMOVE_AUTH2
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    CALL REMOVE_AUTH(AUTH_NAME, AUTH_TYPE(AUTH_NAME), INCLUDE_PERSONAL);
END!

CREATE PROCEDURE REMOVE_AUTH(
    AUTH_NAME VARCHAR(128)
)
    SPECIFIC REMOVE_AUTH3
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    CALL REMOVE_AUTH(AUTH_NAME, AUTH_TYPE(AUTH_NAME), 'N');
END!

COMMENT ON SPECIFIC PROCEDURE REMOVE_AUTH1
    IS 'Removes all authorities held by the specified name'!
COMMENT ON SPECIFIC PROCEDURE REMOVE_AUTH2
    IS 'Removes all authorities held by the specified name'!
COMMENT ON SPECIFIC PROCEDURE REMOVE_AUTH3
    IS 'Removes all authorities held by the specified name'!

-- MOVE_AUTH(SOURCE, SOURCE_TYPE, DEST, DEST_TYPE, INCLUDE_PERSONAL)
-- MOVE_AUTH(SOURCE, DEST, INCLUDE_PERSONAL)
-- MOVE_AUTH(SOURCE, DEST)
-------------------------------------------------------------------------------
-- MOVE_AUTH is a procedure which moves all authorizations from the source
-- grantee (SOURCE) to the destination grantee (DEST). Like COPY_AUTH, this
-- procedure does not preserve the grantor, and method authorizations are not
-- moved. Essentially this procedure combines COPY_AUTH and REMOVE_AUTH to
-- copy authorizations from SOURCE to DEST and then remove them from SOURCE.
--
-- The optional SOURCE_TYPE and DEST_TYPE parameters specify whether SOURCE and
-- DEST refer to a user ('U'), group ('G'), or role ('R') respectively. If
-- omitted the procedure will use the AUTH_TYPE function above to determine the
-- type.
--
-- The optional INCLUDE_PERSONAL parameter specifies whether to include the
-- authorizations for SOURCE's personal schema ('Y') or not ('N'). Defaults to
-- 'N' if omitted, and has no effect in the case where SOURCE is not a user.
--
-- Note that column authorizations will be copied, but cannot be removed by
-- REMOVE_AUTH. These should be handled separately.
-------------------------------------------------------------------------------

CREATE PROCEDURE MOVE_AUTH(
    SOURCE VARCHAR(128),
    SOURCE_TYPE VARCHAR(1),
    DEST VARCHAR(128),
    DEST_TYPE VARCHAR(1),
    INCLUDE_PERSONAL VARCHAR(1)
)
    SPECIFIC MOVE_AUTH1
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    CALL COPY_AUTH(SOURCE, SOURCE_TYPE, DEST, DEST_TYPE, INCLUDE_PERSONAL);
    CALL REMOVE_AUTH(SOURCE, SOURCE_TYPE, INCLUDE_PERSONAL);
END!

CREATE PROCEDURE MOVE_AUTH(
    SOURCE VARCHAR(128),
    DEST VARCHAR(128),
    INCLUDE_PERSONAL VARCHAR(1)
)
    SPECIFIC MOVE_AUTH2
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    CALL MOVE_AUTH(SOURCE, AUTH_TYPE(SOURCE), DEST, AUTH_TYPE(DEST), INCLUDE_PERSONAL);
END!

CREATE PROCEDURE MOVE_AUTH(
    SOURCE VARCHAR(128),
    DEST VARCHAR(128)
)
    SPECIFIC MOVE_AUTH3
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    MODIFIES SQL DATA
    LANGUAGE SQL
BEGIN ATOMIC
    CALL MOVE_AUTH(SOURCE, AUTH_TYPE(SOURCE), DEST, AUTH_TYPE(DEST), 'N');
END!

COMMENT ON SPECIFIC PROCEDURE MOVE_AUTH1
    IS 'Moves all authorities held by the source to the target, provided they are not already held'!
COMMENT ON SPECIFIC PROCEDURE MOVE_AUTH2
    IS 'Moves all authorities held by the source to the target, provided they are not already held'!
COMMENT ON SPECIFIC PROCEDURE MOVE_AUTH3
    IS 'Moves all authorities held by the source to the target, provided they are not already held'!

-- SAVED_AUTH
-------------------------------------------------------------------------------
-- A simple table which replicates the structure of the SYSCAT.TABAUTH view for
-- use by the SAVE_AUTH and RESTORE_AUTH procedures below.
-------------------------------------------------------------------------------

CREATE TABLE SAVED_AUTH LIKE SYSCAT.TABAUTH!

CREATE UNIQUE INDEX SAVED_AUTH_PK
    ON SAVED_AUTH (
        TABSCHEMA,
        TABNAME,
        GRANTOR,
        GRANTEE,
        GRANTEETYPE
    )!

ALTER TABLE SAVED_AUTH
    ADD CONSTRAINT PK PRIMARY KEY (TABSCHEMA, TABNAME, GRANTOR, GRANTEE, GRANTEETYPE)!

COMMENT ON TABLE SAVED_AUTH
    IS 'Utility table used for temporary storage of authorizations by SAVE_AUTH, SAVE_AUTHS, RESTORE_AUTH and RESTORE_AUTHS et al'!

-- SAVE_AUTH(ASCHEMA, ATABLE)
-- SAVE_AUTH(ATABLE)
-------------------------------------------------------------------------------
-- SAVE_AUTH is a utility procedure which copies the authorization settings for
-- the specified table or view to the SAVED_AUTH table above. These saved
-- settings can then be restored with the RESTORE_AUTH procedure declared
-- below. These procedures are primarily intended for use in conjunction with
-- the other schema evolution functions (like RECREATE_VIEWS()).
--
-- NOTE: Column specific authorizations (stored in SYSCAT.COLAUTH) are NOT
-- saved and restored by these procedures.
--
-- NOTE: SAVE_AUTH and RESTORE_AUTH are not used directly by RECREATE_VIEW[S]
-- because when a view is marked inoperative, all authorization information is
-- immediately wiped from SYSCAT.TABAUTH. Hence, there is nothing to restore by
-- the time RECREATE_VIEW[S] is run. You must call SAVE_AUTH *before*
-- performing the operation that will invalidate the view, and RESTORE_AUTH
-- *after* running RECREATE_VIEW[S]. Alternatively, you may wish to use the
-- SAVE_VIEW and RESTORE_VIEW procedures instead, which rely on SAVE_AUTH and
-- RESTORE_AUTH implicitly.
-------------------------------------------------------------------------------

CREATE PROCEDURE SAVE_AUTH(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    SPECIFIC SAVE_AUTH1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    MERGE INTO SAVED_AUTH AS DEST
        USING (
            SELECT *
            FROM SYSCAT.TABAUTH
            WHERE TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
        ) AS SRC
        ON SRC.TABSCHEMA = DEST.TABSCHEMA
        AND SRC.TABNAME = DEST.TABNAME
        AND SRC.GRANTOR = DEST.GRANTOR
        AND SRC.GRANTEE = DEST.GRANTEE
        AND SRC.GRANTEETYPE = DEST.GRANTEETYPE
        WHEN MATCHED THEN
            UPDATE SET
                GRANTORTYPE = SRC.GRANTORTYPE,
                CONTROLAUTH = SRC.CONTROLAUTH,
                ALTERAUTH = SRC.ALTERAUTH,
                DELETEAUTH = SRC.DELETEAUTH,
                INDEXAUTH = SRC.INDEXAUTH,
                INSERTAUTH = SRC.INSERTAUTH,
                REFAUTH = SRC.REFAUTH,
                SELECTAUTH = SRC.SELECTAUTH,
                UPDATEAUTH = SRC.UPDATEAUTH
        WHEN NOT MATCHED THEN
            INSERT VALUES (
                SRC.GRANTOR,
                SRC.GRANTORTYPE,
                SRC.GRANTEE,
                SRC.GRANTEETYPE,
                SRC.TABSCHEMA,
                SRC.TABNAME,
                SRC.CONTROLAUTH,
                SRC.ALTERAUTH,
                SRC.DELETEAUTH,
                SRC.INDEXAUTH,
                SRC.INSERTAUTH,
                SRC.REFAUTH,
                SRC.SELECTAUTH,
                SRC.UPDATEAUTH
            );
END!

CREATE PROCEDURE SAVE_AUTH(ATABLE VARCHAR(128))
    SPECIFIC SAVE_AUTH2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL SAVE_AUTH(CURRENT SCHEMA, ATABLE);
END!

COMMENT ON SPECIFIC PROCEDURE SAVE_AUTH1
    IS 'Saves the authorizations of the specified relation for later restoration with the RESTORE_AUTH procedure'!
COMMENT ON SPECIFIC PROCEDURE SAVE_AUTH2
    IS 'Saves the authorizations of the specified relation for later restoration with the RESTORE_AUTH procedure'!

-- SAVE_AUTHS(ASCHEMA)
-- SAVE_AUTHS()
-------------------------------------------------------------------------------
-- SAVE_AUTHS is a utility procedure which copies the authorization settings
-- for all tables in the specified schema to the SAVED_AUTH table above. If no
-- schema is specified the current schema is used.
-------------------------------------------------------------------------------

CREATE PROCEDURE SAVE_AUTHS(ASCHEMA VARCHAR(128))
    SPECIFIC SAVE_AUTHS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    MERGE INTO SAVED_AUTH AS DEST
        USING (
            SELECT *
            FROM SYSCAT.TABAUTH
            WHERE TABSCHEMA = ASCHEMA
        ) AS SRC
        ON SRC.TABSCHEMA = DEST.TABSCHEMA
        AND SRC.TABNAME = DEST.TABNAME
        AND SRC.GRANTOR = DEST.GRANTOR
        AND SRC.GRANTEE = DEST.GRANTEE
        AND SRC.GRANTEETYPE = DEST.GRANTEETYPE
        WHEN MATCHED THEN
            UPDATE SET
                GRANTORTYPE = SRC.GRANTORTYPE,
                CONTROLAUTH = SRC.CONTROLAUTH,
                ALTERAUTH = SRC.ALTERAUTH,
                DELETEAUTH = SRC.DELETEAUTH,
                INDEXAUTH = SRC.INDEXAUTH,
                INSERTAUTH = SRC.INSERTAUTH,
                REFAUTH = SRC.REFAUTH,
                SELECTAUTH = SRC.SELECTAUTH,
                UPDATEAUTH = SRC.UPDATEAUTH
        WHEN NOT MATCHED THEN
            INSERT VALUES (
                SRC.GRANTOR,
                SRC.GRANTORTYPE,
                SRC.GRANTEE,
                SRC.GRANTEETYPE,
                SRC.TABSCHEMA,
                SRC.TABNAME,
                SRC.CONTROLAUTH,
                SRC.ALTERAUTH,
                SRC.DELETEAUTH,
                SRC.INDEXAUTH,
                SRC.INSERTAUTH,
                SRC.REFAUTH,
                SRC.SELECTAUTH,
                SRC.UPDATEAUTH
            );
END!

CREATE PROCEDURE SAVE_AUTHS()
    SPECIFIC SAVE_AUTHS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL SAVE_AUTHS(CURRENT SCHEMA);
END!

COMMENT ON SPECIFIC PROCEDURE SAVE_AUTHS1
    IS 'Saves the authorizations of all relations in the specified schema for later restoration with the RESTORE_AUTH procedure'!
COMMENT ON SPECIFIC PROCEDURE SAVE_AUTHS2
    IS 'Saves the authorizations of all relations in the specified schema for later restoration with the RESTORE_AUTH procedure'!

-- RESTORE_AUTH(ASCHEMA, ATABLE)
-- RESTORE_AUTH(ATABLE)
-------------------------------------------------------------------------------
-- RESTORE_AUTH is a utility procedure which restores the authorization
-- privileges for a table or view, previously saved by the SAVE_AUTH procedure
-- defined above.
--
-- NOTE: Privileges may not be precisely restored. Specifically, the grantor in
-- the restored privileges may be different to the original grantor if you are
-- not the user that originally granted the privileges, or the original
-- privileges were granted by the system. Furthermore, column specific
-- authorizations (stored in SYSCAT.COLAUTH) are NOT saved and restored by
-- these procedures.
-------------------------------------------------------------------------------

CREATE PROCEDURE RESTORE_AUTH(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    SPECIFIC RESTORE_AUTH1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    FOR D AS
        SELECT
            'GRANT CONTROL ON '
                || QUOTE_IDENTIFIER(TABSCHEMA)
                || '.'
                || QUOTE_IDENTIFIER(TABNAME)
                || ' TO '
                || CASE GRANTEETYPE
                    WHEN 'U' THEN 'USER ' || QUOTE_IDENTIFIER(GRANTEE)
                    WHEN 'R' THEN 'ROLE ' || QUOTE_IDENTIFIER(GRANTEE)
                    WHEN 'G' THEN
                        CASE GRANTEE
                            WHEN 'PUBLIC' THEN 'PUBLIC'
                            ELSE 'GROUP ' || QUOTE_IDENTIFIER(GRANTEE)
                        END
                END AS DDL
        FROM SAVED_AUTH
        WHERE CONTROLAUTH = 'Y'
            AND TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
        UNION ALL
        SELECT
            'GRANT '
                || SUBSTR(
                   CASE ALTERAUTH  WHEN 'Y' THEN ',ALTER'      ELSE '' END
                || CASE DELETEAUTH WHEN 'Y' THEN ',DELETE'     ELSE '' END
                || CASE INDEXAUTH  WHEN 'Y' THEN ',INDEX'      ELSE '' END
                || CASE INSERTAUTH WHEN 'Y' THEN ',INSERT'     ELSE '' END
                || CASE REFAUTH    WHEN 'Y' THEN ',REFERENCES' ELSE '' END
                || CASE SELECTAUTH WHEN 'Y' THEN ',SELECT'     ELSE '' END
                || CASE UPDATEAUTH WHEN 'Y' THEN ',UPDATE'     ELSE '' END, 2)
                || ' ON '
                || QUOTE_IDENTIFIER(TABSCHEMA)
                || '.'
                || QUOTE_IDENTIFIER(TABNAME)
                || ' TO '
                || CASE GRANTEETYPE
                    WHEN 'U' THEN 'USER ' || QUOTE_IDENTIFIER(GRANTEE)
                    WHEN 'R' THEN 'ROLE ' || QUOTE_IDENTIFIER(GRANTEE)
                    WHEN 'G' THEN
                        CASE GRANTEE
                            WHEN 'PUBLIC' THEN 'PUBLIC'
                            ELSE 'GROUP ' || QUOTE_IDENTIFIER(GRANTEE)
                        END
                END AS DDL
        FROM SAVED_AUTH
        WHERE CONTROLAUTH = 'N'
            AND TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
            AND (
                ALTERAUTH = 'Y'
                OR DELETEAUTH = 'Y'
                OR INDEXAUTH = 'Y'
                OR INSERTAUTH = 'Y'
                OR REFAUTH = 'Y'
                OR SELECTAUTH = 'Y'
                OR UPDATEAUTH = 'Y'
            )
        UNION ALL
        SELECT
            'GRANT '
                || SUBSTR(
                   CASE ALTERAUTH  WHEN 'G' THEN ',ALTER'      ELSE '' END
                || CASE DELETEAUTH WHEN 'G' THEN ',DELETE'     ELSE '' END
                || CASE INDEXAUTH  WHEN 'G' THEN ',INDEX'      ELSE '' END
                || CASE INSERTAUTH WHEN 'G' THEN ',INSERT'     ELSE '' END
                || CASE REFAUTH    WHEN 'G' THEN ',REFERENCES' ELSE '' END
                || CASE SELECTAUTH WHEN 'G' THEN ',SELECT'     ELSE '' END
                || CASE UPDATEAUTH WHEN 'G' THEN ',UPDATE'     ELSE '' END, 2)
                || ' ON '
                || QUOTE_IDENTIFIER(TABSCHEMA)
                || '.'
                || QUOTE_IDENTIFIER(TABNAME)
                || ' TO '
                || CASE GRANTEETYPE
                    WHEN 'U' THEN 'USER ' || QUOTE_IDENTIFIER(GRANTEE)
                    WHEN 'R' THEN 'ROLE ' || QUOTE_IDENTIFIER(GRANTEE)
                    WHEN 'G' THEN
                        CASE GRANTEE
                            WHEN 'PUBLIC' THEN 'PUBLIC'
                            ELSE 'GROUP ' || QUOTE_IDENTIFIER(GRANTEE)
                        END
                END
                || ' WITH GRANT OPTION' AS DDL
        FROM SAVED_AUTH
        WHERE CONTROLAUTH = 'N'
            AND TABSCHEMA = ASCHEMA
            AND TABNAME = ATABLE
            AND (
                ALTERAUTH = 'G'
                OR DELETEAUTH = 'G'
                OR INDEXAUTH = 'G'
                OR INSERTAUTH = 'G'
                OR REFAUTH = 'G'
                OR SELECTAUTH = 'G'
                OR UPDATEAUTH = 'G'
            )
    DO
        EXECUTE IMMEDIATE D.DDL;
    END FOR;
    DELETE FROM SAVED_AUTH
        WHERE TABSCHEMA = ASCHEMA
        AND TABNAME = ATABLE;
END!

CREATE PROCEDURE RESTORE_AUTH(ATABLE VARCHAR(128))
    SPECIFIC RESTORE_AUTH2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL RESTORE_AUTH(CURRENT SCHEMA, ATABLE);
END!

COMMENT ON SPECIFIC PROCEDURE RESTORE_AUTH1
    IS 'Restores authorizations previously saved by SAVE_AUTH for the specified table'!
COMMENT ON SPECIFIC PROCEDURE RESTORE_AUTH2
    IS 'Restores authorizations previously saved by SAVE_AUTH for the specified table'!

-- RESTORE_AUTHS(ASCHEMA)
-- RESTORE_AUTHS()
-------------------------------------------------------------------------------
-- RESTORE_AUTHS is a utility procedure which restores the authorization
-- settings for all tables in the specified schema from the SAVED_AUTH table
-- above. If no schema is specified, the current schema is used.
--
-- NOTE: The procedure only attempts to restore settings for those tables or
-- views which currently exist, and for which settings were previously saved.
-- If you use SAVE_AUTHS on a schema, drop several objects from the schema and
-- then call RESTORE_AUTHS on that schema, the procedure will succeed with no
-- error, although several authorization settings have not been restored.
-- Furthermore, the settings that are not restored are removed from the
-- SAVED_AUTHS table.
-------------------------------------------------------------------------------

CREATE PROCEDURE RESTORE_AUTHS(ASCHEMA VARCHAR(128))
    SPECIFIC RESTORE_AUTHS1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    FOR D AS
        SELECT T.TABNAME
        FROM
            SYSCAT.TABLES T INNER JOIN SAVED_AUTH S
                ON T.TABSCHEMA = S.TABSCHEMA
                AND T.TABNAME = S.TABNAME
        WHERE T.TABSCHEMA = ASCHEMA
    DO
        CALL RESTORE_AUTH(ASCHEMA, D.TABNAME);
    END FOR;
    DELETE FROM SAVED_AUTH
        WHERE TABSCHEMA = ASCHEMA;
END!

CREATE PROCEDURE RESTORE_AUTHS()
    SPECIFIC RESTORE_AUTHS2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    FOR D AS
        SELECT T.TABSCHEMA, T.TABNAME
        FROM
            SYSCAT.TABLES T INNER JOIN SAVED_AUTH S
                ON T.TABSCHEMA = S.TABSCHEMA
                AND T.TABNAME = S.TABNAME
    DO
        CALL RESTORE_AUTH(D.TABSCHEMA, D.TABNAME);
    END FOR;
    DELETE FROM SAVED_AUTH;
END!

COMMENT ON SPECIFIC PROCEDURE RESTORE_AUTHS1
    IS 'Restores the authorizations of all relations in the specified schema that were previously saved with SAVE_AUTHS'!
COMMENT ON SPECIFIC PROCEDURE RESTORE_AUTHS2
    IS 'Restores the authorizations of all relations in the specified schema that were previously saved with SAVE_AUTHS'!

-- vim: set et sw=4 sts=4:
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
-------------------------------------------------------------------------------
-- DATE, TIME, AND TIMESTAMP UTILITIES
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
-- The following code defines a considerably expanded set of functions for
-- dealing with datetime values.
-------------------------------------------------------------------------------

-- PRIOR_DAYOFWEEK(ADATE, ADOW)
-- PRIOR_DAYOFWEEK(ADOW)
-------------------------------------------------------------------------------
-- Returns the specified day of the week prior to the given date. Days of the
-- week are specified in the same fashion as the DAYOFWEEK function (i.e.
-- 1=Sunday, 2=Monday, ... 7=Saturday). If ADATE is omitted the current date
-- is used.
-------------------------------------------------------------------------------

CREATE FUNCTION PRIOR_DAYOFWEEK(ADATE DATE, ADOW INTEGER)
    RETURNS DATE
    SPECIFIC PRIOR_DAYOFWEEK1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ADATE - (MOD(DAYOFWEEK(ADATE) + (6 - ADOW), 7) + 1) DAYS!

CREATE FUNCTION PRIOR_DAYOFWEEK(ADATE TIMESTAMP, ADOW INTEGER)
    RETURNS DATE
    SPECIFIC PRIOR_DAYOFWEEK2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    PRIOR_DAYOFWEEK(DATE(ADATE), ADOW)!

CREATE FUNCTION PRIOR_DAYOFWEEK(ADATE VARCHAR(26), ADOW INTEGER)
    RETURNS DATE
    SPECIFIC PRIOR_DAYOFWEEK3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    PRIOR_DAYOFWEEK(DATE(ADATE), ADOW)!

CREATE FUNCTION PRIOR_DAYOFWEEK(ADOW INTEGER)
    RETURNS DATE
    SPECIFIC PRIOR_DAYOFWEEK4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN PRIOR_DAYOFWEEK(CURRENT DATE, ADOW)!

COMMENT ON SPECIFIC FUNCTION PRIOR_DAYOFWEEK1
    IS 'Returns the latest date earlier than ADATE, which is also a particular day of the week, ADOW (1=Sunday, 2=Monday, 6=Saturday, etc.)'!
COMMENT ON SPECIFIC FUNCTION PRIOR_DAYOFWEEK2
    IS 'Returns the latest date earlier than ADATE, which is also a particular day of the week, ADOW (1=Sunday, 2=Monday, 6=Saturday, etc.)'!
COMMENT ON SPECIFIC FUNCTION PRIOR_DAYOFWEEK3
    IS 'Returns the latest date earlier than ADATE, which is also a particular day of the week, ADOW (1=Sunday, 2=Monday, 6=Saturday, etc.)'!
COMMENT ON SPECIFIC FUNCTION PRIOR_DAYOFWEEK4
    IS 'Returns the latest date earlier than ADATE, which is also a particular day of the week, ADOW (1=Sunday, 2=Monday, 6=Saturday, etc.)'!

-- NEXT_DAYOFWEEK(ADATE, ADOW)
-- NEXT_DAYOFWEEK(ADOW)
-------------------------------------------------------------------------------
-- Returns the specified day of the week following the given date. Days of the
-- week are specified in the same fashion as the DAYOFWEEK function (i.e.
-- 1=Sunday, 2=Monday, ... 7=Saturday). If ADATE is omitted the current
-- date is used.
-------------------------------------------------------------------------------

CREATE FUNCTION NEXT_DAYOFWEEK(ADATE DATE, ADOW INTEGER)
    RETURNS DATE
    SPECIFIC NEXT_DAYOFWEEK1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ADATE + (7 - MOD(7 + DAYOFWEEK(ADATE) - ADOW, 7)) DAYS!

CREATE FUNCTION NEXT_DAYOFWEEK(ADATE TIMESTAMP, ADOW INTEGER)
    RETURNS DATE
    SPECIFIC NEXT_DAYOFWEEK2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    NEXT_DAYOFWEEK(DATE(ADATE), ADOW)!

CREATE FUNCTION NEXT_DAYOFWEEK(ADATE VARCHAR(26), ADOW INTEGER)
    RETURNS DATE
    SPECIFIC NEXT_DAYOFWEEK3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    NEXT_DAYOFWEEK(DATE(ADATE), ADOW)!

CREATE FUNCTION NEXT_DAYOFWEEK(ADOW INTEGER)
    RETURNS DATE
    SPECIFIC NEXT_DAYOFWEEK4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    NEXT_DAYOFWEEK(CURRENT DATE, ADOW)!

COMMENT ON SPECIFIC FUNCTION NEXT_DAYOFWEEK1
    IS 'Returns the earliest date later than ADATE, which is also a particular day of the week, ADOW (1=Sunday, 2=Monday, 6=Saturday, etc.)'!
COMMENT ON SPECIFIC FUNCTION NEXT_DAYOFWEEK2
    IS 'Returns the earliest date later than ADATE, which is also a particular day of the week, ADOW (1=Sunday, 2=Monday, 6=Saturday, etc.)'!
COMMENT ON SPECIFIC FUNCTION NEXT_DAYOFWEEK3
    IS 'Returns the earliest date later than ADATE, which is also a particular day of the week, ADOW (1=Sunday, 2=Monday, 6=Saturday, etc.)'!
COMMENT ON SPECIFIC FUNCTION NEXT_DAYOFWEEK4
    IS 'Returns the earliest date later than ADATE, which is also a particular day of the week, ADOW (1=Sunday, 2=Monday, 6=Saturday, etc.)'!

-- SECONDS(ATIMESTAMP)
-------------------------------------------------------------------------------
-- Returns an integer representation of a TIMESTAMP. This function is a
-- combination of the DAYS and MIDNIGHT_SECONDS functions. The result is a
-- BIGINT (64-bit integer value) representing the number of seconds since one
-- day before 0001-01-01 at 00:00:00. The one day offset is due to the
-- operation of the DAYS function.
-------------------------------------------------------------------------------

CREATE FUNCTION SECONDS(ATIMESTAMP TIMESTAMP)
    RETURNS BIGINT
    SPECIFIC SECONDS1
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    (DAYS(ATIMESTAMP) * BIGINT(24 * 60 * 60) + MIDNIGHT_SECONDS(ATIMESTAMP))!

CREATE FUNCTION SECONDS(ATIMESTAMP DATE)
    RETURNS BIGINT
    SPECIFIC SECONDS2
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DAYS(ATIMESTAMP) * BIGINT(24 * 60 * 60)!

CREATE FUNCTION SECONDS(ATIMESTAMP VARCHAR(26))
    RETURNS BIGINT
    SPECIFIC SECONDS3
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE LENGTH(ATIMESTAMP)
        WHEN 10 THEN SECONDS(DATE(ATIMESTAMP))
        ELSE SECONDS(TIMESTAMP(ATIMESTAMP))
    END!

COMMENT ON SPECIFIC FUNCTION SECONDS1
    IS 'Returns an integer representation of the specified TIMESTAMP. The inverse of this function is TIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION SECONDS2
    IS 'Returns an integer representation of the specified TIMESTAMP. The inverse of this function is TIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION SECONDS3
    IS 'Returns an integer representation of the specified TIMESTAMP. The inverse of this function is TIMESTAMP'!

-- DATE(AYEAR, AMONTH, ADAY)
-- DATE(AYEAR, ADAY)
-------------------------------------------------------------------------------
-- Returns the DATE value with the components specified by AYEAR, AMONTH, and
-- ADAY, or alternatively AYEAR and ADOY the latter of which is the day of year
-- to construct a DATE for.
-------------------------------------------------------------------------------

CREATE FUNCTION DATE(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER)
    RETURNS DATE
    SPECIFIC DATE1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DATE(CHAR(
        RIGHT(DIGITS(AYEAR), 4) || '-' ||
        RIGHT(DIGITS(AMONTH), 2) || '-' ||
        RIGHT(DIGITS(ADAY), 2), 10))!

CREATE FUNCTION DATE(AYEAR INTEGER, ADOY INTEGER)
    RETURNS DATE
    SPECIFIC DATE2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DATE(CHAR(RIGHT(DIGITS(AYEAR), 4) || RIGHT(DIGITS(ADOY), 3), 7))!

COMMENT ON SPECIFIC FUNCTION DATE1
    IS 'Returns a DATE constructed from the specified year, month and day'!
COMMENT ON SPECIFIC FUNCTION DATE2
    IS 'Returns a DATE constructed from the specified year and day-of-year'!

-- TIME(AHOUR, AMINUTE, ASECONDS)
-- TIME(ASECONDS)
-------------------------------------------------------------------------------
-- Returns a TIME with the components specified by AHOUR, AMINUTE and ASECOND
-- in the first case. In the second case, returns a TIME ASECONDS after
-- midnight. If ASECONDS represents a period longer than a day, the value used
-- is ASECONDS mod 86400 (the "date" portion of the seconds value is removed
-- before calculation). This function is essentially the reverse of the
-- MIDNIGHT_SECONDS function.
-------------------------------------------------------------------------------

CREATE FUNCTION TIME(AHOUR INTEGER, AMINUTE INTEGER, ASECOND INTEGER)
    RETURNS TIME
    SPECIFIC TIME1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIME(CHAR(
        RIGHT(DIGITS(AHOUR), 2) || ':' ||
        RIGHT(DIGITS(AMINUTE), 2) || ':' ||
        RIGHT(DIGITS(ASECOND), 2), 8))!

CREATE FUNCTION TIME(ASECONDS BIGINT)
    RETURNS TIME
    SPECIFIC TIME2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
BEGIN ATOMIC
    DECLARE H, M, S, T INTEGER;
    SET T = MOD(ASECONDS, (24 * 60 * 60));
    SET H = T / (60 * 60);
    SET M = MOD(T / 60, 60);
    SET S = MOD(T, 60);
    RETURN TIME(CHAR(
        RIGHT(DIGITS(H), 2) || ':' ||
        RIGHT(DIGITS(M), 2) || ':' ||
        RIGHT(DIGITS(S), 2), 8));
END!

CREATE FUNCTION TIME(ASECONDS INTEGER)
    RETURNS TIME
    SPECIFIC TIME3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIME(BIGINT(ASECONDS))!

COMMENT ON SPECIFIC FUNCTION TIME1
    IS 'Constructs a TIME from the specified hours, minutes and seconds'!
COMMENT ON SPECIFIC FUNCTION TIME2
    IS 'Constructs a TIME from the specified seconds after midnight'!
COMMENT ON SPECIFIC FUNCTION TIME3
    IS 'Constructs a TIME from the specified seconds after midnight'!

-- TIMESTAMP(ASECONDS)
-------------------------------------------------------------------------------
-- Returns a TIMESTAMP ASECONDS seconds after 0001-01-00 00:00:00. This
-- function is essentially the reverse of the SECONDS function. The ASECONDS
-- value MUST be greater than 86400 (it must include a "date" portion)
-- otherwise the returned value has an invalid year of 0000 and an error will
-- occur.
-------------------------------------------------------------------------------

CREATE FUNCTION TIMESTAMP(ASECONDS BIGINT)
    RETURNS TIMESTAMP
    SPECIFIC TIMESTAMP1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(ASECONDS / (24 * 60 * 60)), TIME(ASECONDS))!

CREATE FUNCTION TIMESTAMP(
    AYEAR INTEGER,
    AMONTH INTEGER,
    ADAY INTEGER,
    AHOUR INTEGER,
    AMINUTE INTEGER,
    ASECOND INTEGER,
    AMICROSECOND INTEGER
)
    RETURNS TIMESTAMP
    SPECIFIC TIMESTAMP2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(CHAR(
        RIGHT(DIGITS(AYEAR), 4) || '-' ||
        RIGHT(DIGITS(AMONTH), 2) || '-' ||
        RIGHT(DIGITS(ADAY), 2) || ' ' ||
        RIGHT(DIGITS(AHOUR), 2) || ':' ||
        RIGHT(DIGITS(AMINUTE), 2) || ':' ||
        RIGHT(DIGITS(ASECOND), 2) || '.' ||
        RIGHT(DIGITS(AMICROSECOND), 6), 26))!

COMMENT ON SPECIFIC FUNCTION TIMESTAMP1
    IS 'Constructs a TIMESTAMP from the specified seconds after the epoch. This is the inverse function of SECONDS'!
COMMENT ON SPECIFIC FUNCTION TIMESTAMP2
    IS 'Constructs a TIMESTAMP from the specified year, month, day, hours, minutes, seconds, and microseconds'!

-- YEAR_ISO(ADATE)
-------------------------------------------------------------------------------
-- Returns the year of ADATE, unless the ISO week number of ADATE belongs to
-- the prior year, in which case the prior year is returned.
-------------------------------------------------------------------------------

CREATE FUNCTION YEAR_ISO(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC YEAR_ISO1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE WHEN DAYOFYEAR(ADATE) <= 7 AND WEEK_ISO(ADATE) >= 52
        THEN YEAR(ADATE) - 1
        ELSE YEAR(ADATE)
    END!

CREATE FUNCTION YEAR_ISO(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC YEAR_ISO2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    YEAR_ISO(DATE(ADATE))!

CREATE FUNCTION YEAR_ISO(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC YEAR_ISO3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    YEAR_ISO(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION YEAR_ISO1
    IS 'Returns the year of ADATE, unless the ISO week of ADATE exists in the prior year in which case that year is returned'!
COMMENT ON SPECIFIC FUNCTION YEAR_ISO2
    IS 'Returns the year of ADATE, unless the ISO week of ADATE exists in the prior year in which case that year is returned'!
COMMENT ON SPECIFIC FUNCTION YEAR_ISO3
    IS 'Returns the year of ADATE, unless the ISO week of ADATE exists in the prior year in which case that year is returned'!

-- MONTHSTART(AYEAR, AMONTH)
-- MONTHSTART(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the first day of AMONTH in AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION MONTHSTART(AYEAR INTEGER, AMONTH INTEGER)
    RETURNS DATE
    SPECIFIC MONTHSTART1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DATE(AYEAR, AMONTH, 1)!

CREATE FUNCTION MONTHSTART(ADATE DATE)
    RETURNS DATE
    SPECIFIC MONTHSTART2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ADATE - (DAY(ADATE) - 1) DAYS!

CREATE FUNCTION MONTHSTART(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC MONTHSTART3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHSTART(DATE(ADATE))!

CREATE FUNCTION MONTHSTART(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC MONTHSTART4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHSTART(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION MONTHSTART1
    IS 'Returns the first day of month AMONTH in the year AYEAR'!
COMMENT ON SPECIFIC FUNCTION MONTHSTART2
    IS 'Returns the first day of the month that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION MONTHSTART3
    IS 'Returns the first day of the month that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION MONTHSTART4
    IS 'Returns the first day of the month that ADATE exists within'!

-- MONTHEND(AYEAR, AMONTH)
-- MONTHEND(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the final day of AMONTH in AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION MONTHEND(AYEAR INTEGER, AMONTH INTEGER)
    RETURNS DATE
    SPECIFIC MONTHEND1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE AMONTH
        WHEN 12 THEN
            MONTHSTART(AYEAR + 1, 1)
        ELSE
            MONTHSTART(AYEAR, AMONTH + 1)
    END - 1 DAY!

CREATE FUNCTION MONTHEND(ADATE DATE)
    RETURNS DATE
    SPECIFIC MONTHEND2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ((ADATE - (DAY(ADATE) - 1) DAYS) + 1 MONTH) - 1 DAY!

CREATE FUNCTION MONTHEND(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC MONTHEND3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHEND(DATE(ADATE))!

CREATE FUNCTION MONTHEND(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC MONTHEND4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHEND(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION MONTHEND1
    IS 'Returns the last day of month AMONTH in the year AYEAR'!
COMMENT ON SPECIFIC FUNCTION MONTHEND2
    IS 'Returns the last day of the month that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION MONTHEND3
    IS 'Returns the last day of the month that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION MONTHEND4
    IS 'Returns the last day of the month that ADATE exists within'!

-- MONTHWEEK(ADATE)
-------------------------------------------------------------------------------
-- Returns the week of the month of ADATE, where weeks start on a Sunday. The
-- result will be in the range 1-6 as partial weeks are permitted. For example,
-- if the first day of a month is a Saturday, it will be counted as week 1,
-- which lasts one day. The next day, Sunday, will start week 2.
-------------------------------------------------------------------------------

CREATE FUNCTION MONTHWEEK(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC MONTHWEEK1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEK(ADATE) - WEEK(MONTHSTART(ADATE)) + 1!

CREATE FUNCTION MONTHWEEK(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC MONTHWEEK2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHWEEK(DATE(ADATE))!

CREATE FUNCTION MONTHWEEK(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC MONTHWEEK3
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHWEEK(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION MONTHWEEK1
    IS 'Returns the week of the month that ADATE exists within (weeks start on a Sunday, result will be in the range 1-6)'!
COMMENT ON SPECIFIC FUNCTION MONTHWEEK2
    IS 'Returns the week of the month that ADATE exists within (weeks start on a Sunday, result will be in the range 1-6)'!
COMMENT ON SPECIFIC FUNCTION MONTHWEEK3
    IS 'Returns the week of the month that ADATE exists within (weeks start on a Sunday, result will be in the range 1-6)'!

-- MONTHWEEK_ISO(ADATE)
-------------------------------------------------------------------------------
-- Returns the week of the month of ADATE, where weeks start on a Monday. The
-- result will be in the range 1-6 as partial weeks are permitted. For example,
-- if the first day of a month is a Sunday, it will be counted as week 1, which
-- lasts one day. The next day, Monday, will start week 2.
-------------------------------------------------------------------------------

CREATE FUNCTION MONTHWEEK_ISO(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC MONTHWEEK_ISO1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ((DAYS(ADATE) - DAYS(PRIOR_DAYOFWEEK(MONTHSTART(ADATE) + 1 DAY, 2))) / 7) + 1!

CREATE FUNCTION MONTHWEEK_ISO(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC MONTHWEEK_ISO2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHWEEK_ISO(DATE(ADATE))!

CREATE FUNCTION MONTHWEEK_ISO(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC MONTHWEEK_ISO3
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHWEEK_ISO(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION MONTHWEEK_ISO1
    IS 'Returns the week of the month that ADATE exists within (weeks start on a Monday, result will be in the range 1-6)'!
COMMENT ON SPECIFIC FUNCTION MONTHWEEK_ISO2
    IS 'Returns the week of the month that ADATE exists within (weeks start on a Monday, result will be in the range 1-6)'!
COMMENT ON SPECIFIC FUNCTION MONTHWEEK_ISO3
    IS 'Returns the week of the month that ADATE exists within (weeks start on a Monday, result will be in the range 1-6)'!

-- QUARTERSTART(AYEAR, AQUARTER)
-- QUARTERSTART(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the first day of AQUARTER in AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION QUARTERSTART(AYEAR INTEGER, AQUARTER INTEGER)
    RETURNS DATE
    SPECIFIC QUARTERSTART1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DATE(AYEAR, ((AQUARTER - 1) * 3) + 1, 1)!

CREATE FUNCTION QUARTERSTART(ADATE DATE)
    RETURNS DATE
    SPECIFIC QUARTERSTART2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DATE(YEAR(ADATE), ((QUARTER(ADATE) - 1) * 3) + 1, 1)!

CREATE FUNCTION QUARTERSTART(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC QUARTERSTART3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTERSTART(DATE(ADATE))!

CREATE FUNCTION QUARTERSTART(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC QUARTERSTART4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTERSTART(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION QUARTERSTART1
    IS 'Returns the first day of quarter AQUARTER in the year AYEAR'!
COMMENT ON SPECIFIC FUNCTION QUARTERSTART2
    IS 'Returns the first day of the quarter that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION QUARTERSTART3
    IS 'Returns the first day of the quarter that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION QUARTERSTART4
    IS 'Returns the first day of the quarter that ADATE exists within'!

-- QUARTEREND(AYEAR, AQUARTER)
-- QUARTEREND(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the final day of AQUARTER in AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION QUARTEREND(AYEAR INTEGER, AQUARTER INTEGER)
    RETURNS DATE
    SPECIFIC QUARTEREND1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE AQUARTER
        WHEN 4 THEN
            QUARTERSTART(AYEAR + 1, 1)
        ELSE
            QUARTERSTART(AYEAR, AQUARTER + 1)
    END - 1 DAY!

CREATE FUNCTION QUARTEREND(ADATE DATE)
    RETURNS DATE
    SPECIFIC QUARTEREND2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTEREND(YEAR(ADATE), QUARTER(ADATE))!

CREATE FUNCTION QUARTEREND(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC QUARTEREND3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTEREND(DATE(ADATE))!

CREATE FUNCTION QUARTEREND(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC QUARTEREND4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTEREND(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION QUARTEREND1
    IS 'Returns the last day of quarter AQUARTER in the year AYEAR'!
COMMENT ON SPECIFIC FUNCTION QUARTEREND2
    IS 'Returns the last day of the quarter that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION QUARTEREND3
    IS 'Returns the last day of the quarter that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION QUARTEREND4
    IS 'Returns the last day of the quarter that ADATE exists within'!

-- QUARTERWEEK(ADATE)
-------------------------------------------------------------------------------
-- Returns the week of the month of the ADATE, where weeks start on a Sunday.
-------------------------------------------------------------------------------

CREATE FUNCTION QUARTERWEEK(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC QUARTERWEEK1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEK(ADATE) - WEEK(QUARTERSTART(ADATE)) + 1!

CREATE FUNCTION QUARTERWEEK(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC QUARTERWEEK2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTERWEEK(DATE(ADATE))!

CREATE FUNCTION QUARTERWEEK(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC QUARTERWEEK3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTERWEEK(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION QUARTERWEEK1
    IS 'Returns the week of the quarter that ADATE exists within (weeks start on a Sunday, result will be in the range 1-6)'!
COMMENT ON SPECIFIC FUNCTION QUARTERWEEK2
    IS 'Returns the week of the quarter that ADATE exists within (weeks start on a Sunday, result will be in the range 1-6)'!
COMMENT ON SPECIFIC FUNCTION QUARTERWEEK3
    IS 'Returns the week of the quarter that ADATE exists within (weeks start on a Sunday, result will be in the range 1-6)'!

-- QUARTERWEEK_ISO(ADATE)
-------------------------------------------------------------------------------
-- Returns the week of the month of the ADATE, where weeks start on a Monday.
-------------------------------------------------------------------------------

CREATE FUNCTION QUARTERWEEK_ISO(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC QUARTERWEEK_ISO1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ((DAYS(ADATE) - DAYS(PRIOR_DAYOFWEEK(QUARTERSTART(ADATE) + 1 DAY, 2))) / 7) + 1!

CREATE FUNCTION QUARTERWEEK_ISO(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC QUARTERWEEK_ISO2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTERWEEK_ISO(DATE(ADATE))!

CREATE FUNCTION QUARTERWEEK_ISO(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC QUARTERWEEK_ISO3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    QUARTERWEEK_ISO(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION QUARTERWEEK_ISO1
    IS 'Returns the week of the quarter that ADATE exists within (weeks start on a Monday, result will be in the range 1-6)'!
COMMENT ON SPECIFIC FUNCTION QUARTERWEEK_ISO2
    IS 'Returns the week of the quarter that ADATE exists within (weeks start on a Monday, result will be in the range 1-6)'!
COMMENT ON SPECIFIC FUNCTION QUARTERWEEK_ISO3
    IS 'Returns the week of the quarter that ADATE exists within (weeks start on a Monday, result will be in the range 1-6)'!

-- YEARSTART(AYEAR)
-- YEARSTART(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the first day of AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION YEARSTART(AYEAR INTEGER)
    RETURNS DATE
    SPECIFIC YEARSTART1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DATE(AYEAR, 1)!

CREATE FUNCTION YEARSTART(ADATE DATE)
    RETURNS DATE
    SPECIFIC YEARSTART2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ADATE - (DAYOFYEAR(ADATE) - 1) DAYS!

CREATE FUNCTION YEARSTART(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC YEARSTART3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    YEARSTART(DATE(ADATE))!

CREATE FUNCTION YEARSTART(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC YEARSTART4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    YEARSTART(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION YEARSTART1
    IS 'Returns the first day of year AYEAR'!
COMMENT ON SPECIFIC FUNCTION YEARSTART2
    IS 'Returns the first day of the year that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION YEARSTART3
    IS 'Returns the first day of the year that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION YEARSTART4
    IS 'Returns the first day of the year that ADATE exists within'!

-- YEAREND(AYEAR)
-- YEAREND(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the last day of AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION YEAREND(AYEAR INTEGER)
    RETURNS DATE
    SPECIFIC YEAREND1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DATE(AYEAR, 12, 31)!

CREATE FUNCTION YEAREND(ADATE DATE)
    RETURNS DATE
    SPECIFIC YEAREND2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    YEARSTART(ADATE + 1 YEAR) - 1 DAY!

CREATE FUNCTION YEAREND(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC YEAREND3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    YEAREND(DATE(ADATE))!

CREATE FUNCTION YEAREND(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC YEAREND4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    YEAREND(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION YEAREND1
    IS 'Returns the last day of year AYEAR'!
COMMENT ON SPECIFIC FUNCTION YEAREND2
    IS 'Returns the last day of the year that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION YEAREND3
    IS 'Returns the last day of the year that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION YEAREND4
    IS 'Returns the last day of the year that ADATE exists within'!

-- WEEKSTART(AYEAR, AWEEK)
-- WEEKSTART(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the first date (always a Sunday) of AWEEK
-- within AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION WEEKSTART(AYEAR INTEGER, AWEEK INTEGER)
    RETURNS DATE
    SPECIFIC WEEKSTART1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    YEARSTART(AYEAR) -
        (DAYOFWEEK(YEARSTART(AYEAR)) - 1) DAYS +
        ((AWEEK - 1) * 7) DAYS!

CREATE FUNCTION WEEKSTART(ADATE DATE)
    RETURNS DATE
    SPECIFIC WEEKSTART2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ADATE - (DAYOFWEEK(ADATE) - 1) DAYS!

CREATE FUNCTION WEEKSTART(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC WEEKSTART3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSTART(DATE(ADATE))!

CREATE FUNCTION WEEKSTART(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC WEEKSTART4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSTART(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION WEEKSTART1
    IS 'Returns the first day (Sunday) of AWEEK in AYEAR'!
COMMENT ON SPECIFIC FUNCTION WEEKSTART2
    IS 'Returns the first day (Sunday) of the week that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKSTART3
    IS 'Returns the first day (Sunday) of the week that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKSTART4
    IS 'Returns the first day (Sunday) of the week that ADATE exists within'!

-- WEEKEND(AYEAR, AWEEK)
-- WEEKEND(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the last day (always a Saturday) of AWEEK
-- within AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION WEEKEND(AYEAR INTEGER, AWEEK INTEGER)
    RETURNS DATE
    SPECIFIC WEEKEND1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSTART(AYEAR, AWEEK) + 6 DAYS!

CREATE FUNCTION WEEKEND(ADATE DATE)
    RETURNS DATE
    SPECIFIC WEEKEND2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ADATE + (7 - DAYOFWEEK(ADATE)) DAYS!

CREATE FUNCTION WEEKEND(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC WEEKEND3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKEND(DATE(ADATE))!

CREATE FUNCTION WEEKEND(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC WEEKEND4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKEND(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION WEEKEND1
    IS 'Returns the last day (Saturday) of AWEEK in AYEAR'!
COMMENT ON SPECIFIC FUNCTION WEEKEND2
    IS 'Returns the last day (Saturday) of the week that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKEND3
    IS 'Returns the last day (Saturday) of the week that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKEND4
    IS 'Returns the last day (Saturday) of the week that ADATE exists within'!

-- WEEKSTART_ISO(AYEAR, AWEEK)
-- WEEKSTART_ISO(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the first day (always a Monday) of AWEEK
-- within AYEAR according to the ISO8601 standard.
-------------------------------------------------------------------------------

CREATE FUNCTION WEEKSTART_ISO(AYEAR INTEGER, AWEEK INTEGER)
    RETURNS DATE
    SPECIFIC WEEKSTART_ISO1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DATE(AYEAR, 1, 4) -
        (DAYOFWEEK_ISO(DATE(AYEAR, 1, 4)) - 1) DAYS +
        ((AWEEK - 1) * 7) DAYS!

CREATE FUNCTION WEEKSTART_ISO(ADATE DATE)
    RETURNS DATE
    SPECIFIC WEEKSTART_ISO2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ADATE - (DAYOFWEEK_ISO(ADATE) - 1) DAYS!

CREATE FUNCTION WEEKSTART_ISO(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC WEEKSTART_ISO3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSTART_ISO(DATE(ADATE))!

CREATE FUNCTION WEEKSTART_ISO(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC WEEKSTART_ISO4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSTART_ISO(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION WEEKSTART_ISO1
    IS 'Returns the first day (Monday) of AWEEK in AYEAR'!
COMMENT ON SPECIFIC FUNCTION WEEKSTART_ISO2
    IS 'Returns the first day (Monday) of the week that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKSTART_ISO3
    IS 'Returns the first day (Monday) of the week that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKSTART_ISO4
    IS 'Returns the first day (Monday) of the week that ADATE exists within'!

-- WEEKEND_ISO(AYEAR, AWEEK)
-- WEEKEND_ISO(ADATE)
-------------------------------------------------------------------------------
-- Returns a DATE value representing the last day (always a Sunday) of AWEEK
-- within AYEAR according to the ISO8601 standard.
-------------------------------------------------------------------------------

CREATE FUNCTION WEEKEND_ISO(AYEAR INTEGER, AWEEK INTEGER)
    RETURNS DATE
    SPECIFIC WEEKEND_ISO1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSTART_ISO(AYEAR, AWEEK) + 6 DAYS!

CREATE FUNCTION WEEKEND_ISO(ADATE DATE)
    RETURNS DATE
    SPECIFIC WEEKEND_ISO2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    ADATE + (7 - DAYOFWEEK_ISO(ADATE)) DAYS!

CREATE FUNCTION WEEKEND_ISO(ADATE TIMESTAMP)
    RETURNS DATE
    SPECIFIC WEEKEND_ISO3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKEND_ISO(DATE(ADATE))!

CREATE FUNCTION WEEKEND_ISO(ADATE VARCHAR(26))
    RETURNS DATE
    SPECIFIC WEEKEND_ISO4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKEND_ISO(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION WEEKEND_ISO1
    IS 'Returns the last day (Sunday) of AWEEK in AYEAR'!
COMMENT ON SPECIFIC FUNCTION WEEKEND_ISO2
    IS 'Returns the last day (Sunday) of the week that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKEND_ISO3
    IS 'Returns the last day (Sunday) of the week that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKEND_ISO4
    IS 'Returns the last day (Sunday) of the week that ADATE exists within'!

-- WEEKSINYEAR(AYEAR)
-- WEEKSINYEAR(ADATE)
-------------------------------------------------------------------------------
-- Returns the number of weeks within AYEAR.
-------------------------------------------------------------------------------

CREATE FUNCTION WEEKSINYEAR(AYEAR INTEGER)
    RETURNS SMALLINT
    SPECIFIC WEEKSINYEAR1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEK(DATE(AYEAR, 12, 31))!

CREATE FUNCTION WEEKSINYEAR(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC WEEKSINYEAR2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINYEAR(YEAR(ADATE))!

CREATE FUNCTION WEEKSINYEAR(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC WEEKSINYEAR3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINYEAR(DATE(ADATE))!

CREATE FUNCTION WEEKSINYEAR(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC WEEKSINYEAR4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINYEAR(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION WEEKSINYEAR1
    IS 'Returns the number of weeks in AYEAR'!
COMMENT ON SPECIFIC FUNCTION WEEKSINYEAR2
    IS 'Returns the number of weeks in the year that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKSINYEAR3
    IS 'Returns the number of weeks in the year that ADATE exists within'!
COMMENT ON SPECIFIC FUNCTION WEEKSINYEAR4
    IS 'Returns the number of weeks in the year that ADATE exists within'!

-- WEEKSINYEAR_ISO(AYEAR)
-- WEEKSINYEAR_ISO(ADATE)
-------------------------------------------------------------------------------
-- Returns the number of weeks in AYEAR according to the ISO8601 standard.
-------------------------------------------------------------------------------

CREATE FUNCTION WEEKSINYEAR_ISO(AYEAR INTEGER)
    RETURNS SMALLINT
    SPECIFIC WEEKSINYEAR_ISO1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEK_ISO(DATE(AYEAR, 12, 28))!

CREATE FUNCTION WEEKSINYEAR_ISO(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC WEEKSINYEAR_ISO2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINYEAR_ISO(YEAR(ADATE))!

CREATE FUNCTION WEEKSINYEAR_ISO(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC WEEKSINYEAR_ISO3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINYEAR_ISO(DATE(ADATE))!

CREATE FUNCTION WEEKSINYEAR_ISO(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC WEEKSINYEAR_ISO4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINYEAR_ISO(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION WEEKSINYEAR_ISO1
    IS 'Returns the number of weeks in AYEAR according to the ISO8601 standard'!
COMMENT ON SPECIFIC FUNCTION WEEKSINYEAR_ISO2
    IS 'Returns the number of weeks in the year that ADATE exists within according to the ISO8601 standard'!
COMMENT ON SPECIFIC FUNCTION WEEKSINYEAR_ISO3
    IS 'Returns the number of weeks in the year that ADATE exists within according to the ISO8601 standard'!
COMMENT ON SPECIFIC FUNCTION WEEKSINYEAR_ISO4
    IS 'Returns the number of weeks in the year that ADATE exists within according to the ISO8601 standard'!

-- WEEKSINMONTH(AYEAR, AMONTH)
-- WEEKSINMONTH(ADATE)
-------------------------------------------------------------------------------
-- Returns the number of weeks in AMONTH (within AYEAR).
-------------------------------------------------------------------------------

CREATE FUNCTION WEEKSINMONTH(AYEAR INTEGER, AMONTH INTEGER)
    RETURNS SMALLINT
    SPECIFIC WEEKSINMONTH1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHWEEK(MONTHEND(AYEAR, AMONTH))!

CREATE FUNCTION WEEKSINMONTH(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC WEEKSINMONTH2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHWEEK(MONTHEND(ADATE))!

CREATE FUNCTION WEEKSINMONTH(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC WEEKSINMONTH3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINMONTH(DATE(ADATE))!

CREATE FUNCTION WEEKSINMONTH(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC WEEKSINMONTH4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINMONTH(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH1
    IS 'Returns the number of weeks (ranging from Sunday to Saturday, including partials) in AMONTH in AYEAR'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH2
    IS 'Returns the number of weeks (randing from Sunday to Saturday, including partials) in the month in which ADATE exists'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH3
    IS 'Returns the number of weeks (randing from Sunday to Saturday, including partials) in the month in which ADATE exists'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH4
    IS 'Returns the number of weeks (randing from Sunday to Saturday, including partials) in the month in which ADATE exists'!

-- WEEKSINMONTH_ISO(AYEAR, AMONTH)
-- WEEKSINMONTH_ISO(ADATE)
-------------------------------------------------------------------------------
-- Returns the number of weeks in AMONTH (within AYEAR).
-------------------------------------------------------------------------------

CREATE FUNCTION WEEKSINMONTH_ISO(AYEAR INTEGER, AMONTH INTEGER)
    RETURNS SMALLINT
    SPECIFIC WEEKSINMONTH_ISO1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHWEEK_ISO(MONTHEND(AYEAR, AMONTH))!

CREATE FUNCTION WEEKSINMONTH_ISO(ADATE DATE)
    RETURNS SMALLINT
    SPECIFIC WEEKSINMONTH_ISO2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MONTHWEEK_ISO(MONTHEND(ADATE))!

CREATE FUNCTION WEEKSINMONTH_ISO(ADATE TIMESTAMP)
    RETURNS SMALLINT
    SPECIFIC WEEKSINMONTH_ISO3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINMONTH_ISO(DATE(ADATE))!

CREATE FUNCTION WEEKSINMONTH_ISO(ADATE VARCHAR(26))
    RETURNS SMALLINT
    SPECIFIC WEEKSINMONTH_ISO4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WEEKSINMONTH_ISO(DATE(ADATE))!

COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH_ISO1
    IS 'Returns the number of weeks (ranging from Monday to Sunday, including partials) in AMONTH in AYEAR'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH_ISO2
    IS 'Returns the number of weeks (randing from Monday to Sunday, including partials) in the month in which ADATE exists'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH_ISO3
    IS 'Returns the number of weeks (randing from Monday to Sunday, including partials) in the month in which ADATE exists'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH_ISO4
    IS 'Returns the number of weeks (randing from Monday to Sunday, including partials) in the month in which ADATE exists'!

-- HOURSTART(AYEAR, AMONTH, ADAY, AHOUR)
-- HOURSTART(ATIMESTAMP)
-------------------------------------------------------------------------------
-- Returns a TIMESTAMP value representing the first microsecond of AHOUR in the
-- date given by AYEAR, AMONTH, and ADAY, or of the timestamp given by
-- ATIMESTAMP.
-------------------------------------------------------------------------------

CREATE FUNCTION HOURSTART(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER)
    RETURNS TIMESTAMP
    SPECIFIC HOURSTART1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(AYEAR, AMONTH, ADAY), TIME(AHOUR, 0, 0))!

CREATE FUNCTION HOURSTART(ATIMESTAMP TIMESTAMP)
    RETURNS TIMESTAMP
    SPECIFIC HOURSTART2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(ATIMESTAMP), TIME(HOUR(ATIMESTAMP), 0, 0))!

CREATE FUNCTION HOURSTART(ATIMESTAMP VARCHAR(26))
    RETURNS TIMESTAMP
    SPECIFIC HOURSTART3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    HOURSTART(TIMESTAMP(ATIMESTAMP))!

COMMENT ON SPECIFIC FUNCTION HOURSTART1
    IS 'Returns a TIMESTAMP at the start of AHOUR on the date AYEAR, AMONTH, ADAY'!
COMMENT ON SPECIFIC FUNCTION HOURSTART2
    IS 'Returns a TIMESTAMP at the start of the hour of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION HOURSTART3
    IS 'Returns a TIMESTAMP at the start of the hour of ATIMESTAMP'!

-- HOUREND(AYEAR, AMONTH, ADAY, AHOUR)
-- HOUREND(ATIMESTAMP)
-------------------------------------------------------------------------------
-- Returns a TIMESTAMP value representing the last microsecond of AHOUR in the
-- date given by AYEAR, AMONTH, and ADAY, or of the timestamp given by
-- ATIMESTAMP.
-------------------------------------------------------------------------------

CREATE FUNCTION HOUREND(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER)
    RETURNS TIMESTAMP
    SPECIFIC HOUREND1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(AYEAR, AMONTH, ADAY), TIME(AHOUR, 0, 0)) + 1 HOUR - 1 MICROSECOND!

CREATE FUNCTION HOUREND(ATIMESTAMP TIMESTAMP)
    RETURNS TIMESTAMP
    SPECIFIC HOUREND2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(ATIMESTAMP), TIME(HOUR(ATIMESTAMP), 0, 0)) + 1 HOUR - 1 MICROSECOND!

CREATE FUNCTION HOUREND(ATIMESTAMP VARCHAR(26))
    RETURNS TIMESTAMP
    SPECIFIC HOUREND3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    HOUREND(TIMESTAMP(ATIMESTAMP))!

COMMENT ON SPECIFIC FUNCTION HOUREND1
    IS 'Returns a TIMESTAMP at the end of AHOUR on the date AYEAR, AMONTH, ADAY'!
COMMENT ON SPECIFIC FUNCTION HOUREND2
    IS 'Returns a TIMESTAMP at the end of the hour of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION HOUREND3
    IS 'Returns a TIMESTAMP at the end of the hour of ATIMESTAMP'!

-- MINUTESTART(AYEAR, AMONTH, ADAY, AHOUR, AMINUTE)
-- MINUTESTART(ATIMESTAMP)
-------------------------------------------------------------------------------
-- Returns a TIMESTAMP value representing the first microsecond of AMINUTE of
-- AHOUR in the date given by AYEAR, AMONTH, and ADAY, or of the timestamp
-- given by ATIMESTAMP.
-------------------------------------------------------------------------------

CREATE FUNCTION MINUTESTART(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER, AMINUTE INTEGER)
    RETURNS TIMESTAMP
    SPECIFIC MINUTESTART1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(AYEAR, AMONTH, ADAY), TIME(AHOUR, AMINUTE, 0))!

CREATE FUNCTION MINUTESTART(ATIMESTAMP TIMESTAMP)
    RETURNS TIMESTAMP
    SPECIFIC MINUTESTART2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(ATIMESTAMP), TIME(HOUR(ATIMESTAMP), MINUTE(ATIMESTAMP), 0))!

CREATE FUNCTION MINUTESTART(ATIMESTAMP VARCHAR(26))
    RETURNS TIMESTAMP
    SPECIFIC MINUTESTART3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MINUTESTART(TIMESTAMP(ATIMESTAMP))!

COMMENT ON SPECIFIC FUNCTION MINUTESTART1
    IS 'Returns a TIMESTAMP at the start of AHOUR:AMINUTE on the date AYEAR, AMONTH, ADAY'!
COMMENT ON SPECIFIC FUNCTION MINUTESTART2
    IS 'Returns a TIMESTAMP at the start of the minute of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION MINUTESTART3
    IS 'Returns a TIMESTAMP at the start of the minute of ATIMESTAMP'!

-- MINUTEEND(AYEAR, AMONTH, ADAY, AHOUR, AMINUTE)
-- MINUTEEND(ATIMESTAMP)
-------------------------------------------------------------------------------
-- Returns a TIMESTAMP value representing the last microsecond of AMINUTE of
-- AHOUR in the date given by AYEAR, AMONTH, and ADAY, or of the timestamp
-- given by ATIMESTAMP.
-------------------------------------------------------------------------------

CREATE FUNCTION MINUTEEND(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER, AMINUTE INTEGER)
    RETURNS TIMESTAMP
    SPECIFIC MINUTEEND1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(AYEAR, AMONTH, ADAY), TIME(AHOUR, AMINUTE, 0)) + 1 MINUTE - 1 MICROSECOND!

CREATE FUNCTION MINUTEEND(ATIMESTAMP TIMESTAMP)
    RETURNS TIMESTAMP
    SPECIFIC MINUTEEND2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(ATIMESTAMP), TIME(HOUR(ATIMESTAMP), MINUTE(ATIMESTAMP), 0)) + 1 MINUTE - 1 MICROSECOND!

CREATE FUNCTION MINUTEEND(ATIMESTAMP VARCHAR(26))
    RETURNS TIMESTAMP
    SPECIFIC MINUTEEND3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    MINUTEEND(TIMESTAMP(ATIMESTAMP))!

COMMENT ON SPECIFIC FUNCTION MINUTEEND1
    IS 'Returns a TIMESTAMP at the end of AHOUR:AMINUTE on the date AYEAR, AMONTH, ADAY'!
COMMENT ON SPECIFIC FUNCTION MINUTEEND2
    IS 'Returns a TIMESTAMP at the end of the minute of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION MINUTEEND3
    IS 'Returns a TIMESTAMP at the end of the minute of ATIMESTAMP'!

-- SECONDSTART(AYEAR, AMONTH, ADAY, AHOUR, AMINUTE, ASECOND)
-- SECONDSTART(ATIMESTAMP)
-------------------------------------------------------------------------------
-- Returns a TIMESTAMP value representing the first microsecond of ASECOND of
-- AMINUTE of AHOUR in the date given by AYEAR, AMONTH, and ADAY, or of the
-- timestamp given by ATIMESTAMP.
-------------------------------------------------------------------------------

CREATE FUNCTION SECONDSTART(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER, AMINUTE INTEGER, ASECOND INTEGER)
    RETURNS TIMESTAMP
    SPECIFIC SECONDSTART1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(AYEAR, AMONTH, ADAY), TIME(AHOUR, AMINUTE, ASECOND))!

CREATE FUNCTION SECONDSTART(ATIMESTAMP TIMESTAMP)
    RETURNS TIMESTAMP
    SPECIFIC SECONDSTART2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(ATIMESTAMP), TIME(HOUR(ATIMESTAMP), MINUTE(ATIMESTAMP), SECOND(ATIMESTAMP)))!

CREATE FUNCTION SECONDSTART(ATIMESTAMP VARCHAR(26))
    RETURNS TIMESTAMP
    SPECIFIC SECONDSTART3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SECONDSTART(TIMESTAMP(ATIMESTAMP))!

COMMENT ON SPECIFIC FUNCTION SECONDSTART1
    IS 'Returns a TIMESTAMP at the start of AHOUR:AMINUTE:ASECOND on the date AYEAR, AMONTH, ADAY'!
COMMENT ON SPECIFIC FUNCTION SECONDSTART2
    IS 'Returns a TIMESTAMP at the start of the minute of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION SECONDSTART3
    IS 'Returns a TIMESTAMP at the start of the minute of ATIMESTAMP'!

-- SECONDEND(AYEAR, AMONTH, ADAY, AHOUR, AMINUTE, ASECOND)
-- SECONDEND(ATIMESTAMP)
-------------------------------------------------------------------------------
-- Returns a TIMESTAMP value representing the last microsecond of ASECOND of
-- AMINUTE of AHOUR in the date given by AYEAR, AMONTH, and ADAY, or of the
-- timestamp given by ATIMESTAMP.
-------------------------------------------------------------------------------

CREATE FUNCTION SECONDEND(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER, AMINUTE INTEGER, ASECOND INTEGER)
    RETURNS TIMESTAMP
    SPECIFIC SECONDEND1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(AYEAR, AMONTH, ADAY), TIME(AHOUR, AMINUTE, ASECOND)) + 1 SECOND - 1 MICROSECOND!

CREATE FUNCTION SECONDEND(ATIMESTAMP TIMESTAMP)
    RETURNS TIMESTAMP
    SPECIFIC SECONDEND2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TIMESTAMP(DATE(ATIMESTAMP), TIME(HOUR(ATIMESTAMP), MINUTE(ATIMESTAMP), SECOND(ATIMESTAMP))) + 1 SECOND - 1 MICROSECOND!

CREATE FUNCTION SECONDEND(ATIMESTAMP VARCHAR(26))
    RETURNS TIMESTAMP
    SPECIFIC SECONDEND3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SECONDEND(TIMESTAMP(ATIMESTAMP))!

COMMENT ON SPECIFIC FUNCTION SECONDEND1
    IS 'Returns a TIMESTAMP at the end of AHOUR:AMINUTE:ASECOND on the date AYEAR, AMONTH, ADAY'!
COMMENT ON SPECIFIC FUNCTION SECONDEND2
    IS 'Returns a TIMESTAMP at the end of the minute of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION SECONDEND3
    IS 'Returns a TIMESTAMP at the end of the minute of ATIMESTAMP'!

-- DATE_RANGE(START, FINISH, STEP)
-- DATE_RANGE(START, FINISH)
-------------------------------------------------------------------------------
-- Generates a range of dates from START to FINISH inclusive, advancing in
-- increments given by the date duration STEP. Date durations are DECIMAL(8,0)
-- values structured as YYYYMMDD. Hence the following call:
--
--   DATE_RANGE('2006-01-01', '2006-01-31', '00000001')
--
-- Would generate all dates from the 1st of January 2006 to the 31st January
-- 2006. If STEP is ommitted it defaults to 1 day.
-------------------------------------------------------------------------------

CREATE FUNCTION DATE_RANGE(START DATE, FINISH DATE, STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    -- The I counter in the recursive query exists simply to suppress the "may
    -- contain an infinite loop" warning. The value 37000 chosen as the limit
    -- allows the function to generate approximately a century's worth of dates
    -- which ought to be enough for most purposes. Adjust the limit if your
    -- users require larger ranges
    WITH RANGE(I, D) AS (
        (VALUES (1, START))
        UNION ALL
        (SELECT I + 1, D + STEP FROM RANGE WHERE I <= 37000 AND D + STEP <= FINISH)
    )
    SELECT D
    FROM RANGE!

CREATE FUNCTION DATE_RANGE(START DATE, FINISH TIMESTAMP, STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, DATE(FINISH), STEP)) AS T!

CREATE FUNCTION DATE_RANGE(START TIMESTAMP, FINISH DATE, STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(DATE(START), FINISH, STEP)) AS T!

CREATE FUNCTION DATE_RANGE(START TIMESTAMP, FINISH TIMESTAMP, STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(DATE(START), DATE(FINISH), STEP)) AS T!

CREATE FUNCTION DATE_RANGE(START DATE, FINISH VARCHAR(26), STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE5
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, DATE(FINISH), STEP)) AS T!

CREATE FUNCTION DATE_RANGE(START VARCHAR(26), FINISH DATE, STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE6
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(DATE(START), FINISH, STEP)) AS T!

CREATE FUNCTION DATE_RANGE(START VARCHAR(26), FINISH VARCHAR(26), STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE7
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(DATE(START), DATE(FINISH), STEP)) AS T!

CREATE FUNCTION DATE_RANGE(START TIMESTAMP, FINISH VARCHAR(26), STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE8
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(DATE(START), DATE(FINISH), STEP)) AS T!

CREATE FUNCTION DATE_RANGE(START VARCHAR(26), FINISH TIMESTAMP, STEP DECIMAL(8, 0))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE9
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(DATE(START), DATE(FINISH), STEP)) AS T!

CREATE FUNCTION DATE_RANGE(START DATE, FINISH DATE)
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE10
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

CREATE FUNCTION DATE_RANGE(START DATE, FINISH TIMESTAMP)
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE11
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

CREATE FUNCTION DATE_RANGE(START TIMESTAMP, FINISH DATE)
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE12
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

CREATE FUNCTION DATE_RANGE(START TIMESTAMP, FINISH TIMESTAMP)
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE13
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

CREATE FUNCTION DATE_RANGE(START DATE, FINISH VARCHAR(26))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE14
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

CREATE FUNCTION DATE_RANGE(START VARCHAR(26), FINISH DATE)
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE15
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

CREATE FUNCTION DATE_RANGE(START VARCHAR(26), FINISH VARCHAR(26))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE16
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

CREATE FUNCTION DATE_RANGE(START TIMESTAMP, FINISH VARCHAR(26))
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE17
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

CREATE FUNCTION DATE_RANGE(START VARCHAR(26), FINISH TIMESTAMP)
    RETURNS TABLE(D DATE)
    SPECIFIC DATE_RANGE18
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    SELECT *
    FROM TABLE(DATE_RANGE(START, FINISH, DECIMAL(1, 8, 0))) AS T!

COMMENT ON SPECIFIC FUNCTION DATE_RANGE1
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE2
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE3
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE4
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE5
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE6
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE7
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE8
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE9
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE10
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE11
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE12
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE13
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE14
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE15
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE16
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE17
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!
COMMENT ON SPECIFIC FUNCTION DATE_RANGE18
    IS 'Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP with each row (where STEP is an 8 digit duration formatted as YYYYMMDD which defaults to 1 day)'!

-- TS_FORMAT(AFORMAT, ATIMESTAMP)
-------------------------------------------------------------------------------
-- A slightly more useful version of the built-in TIMESTAMP_FORMAT function
-- which actually allows you to specify more than one format :-). Accepts
-- the following template substitution patterns:
--
-- Template Meaning
-- ======== ===================================================================
-- %a       Locale's abbreviated weekday name
-- %A       Locale's full weekday name
-- %b       Locale's abbreviated month name
-- %B       Locale's full month name
-- %c       Locale's appropriate date and time representation
-- %C       The century number (year/100) [00-99]
-- %d       Day of the month as a decimal number [01-31]
-- %D       Equivalent to %m/%d/%y (US format)
-- %e       Like %d, but with leading space instead of zero
-- %F       Equivalent to %Y-%m-%d (ISO8601 format)
-- %G       ISO8601 year with century as a decimal number
-- %g       ISO8601 year without century as a decimal number
-- %h       Half of the year as a decimal number [1-2] [EXTENSION]
-- %H       Hour (24-hr clock) as a decimal number [00-23]
-- %I       Hour (12-hr clock) as a decimal number [01-12]
-- %j       Day of the year as a decimal number [001-366]
-- %k       Like %H with leading space instead of zero
-- %l       Like %I with leading space instead of zero
-- %m       Month as a decimal number [01-12]
-- %M       Minute as a decimal number [00-59]
-- %n       Newline character (X'0A')
-- %p       Locale's equivalent of either AM or PM
-- %P       Like %p but lowercase
-- %q       Quarter of the year as decimal number [1-4]
-- %S       Second as a decimal number [00-61]
-- %t       A tab character (X'09')
-- %T       Equivalent to %H:%M:%S
-- %u       Weekday as a decimal number [1(Monday)-7]
-- %U       Week number of the year (Sunday as the first day of the week) as a
--          decimal number [01-54]
-- %V       ISO8601 Week number of the year (Monday as the first day of the
--          week) as a decimal number [01-53]
-- %w       Weekday as a decimal number [1(Sunday)-7]
-- %W       Equivalent to %V
-- %x       Locale's appropriate date representation
-- %X       Locale's appropriate time representation
-- %y       Year without century as a decimal number [00-99]
-- %Y       Year with century as a decimal number
-- %Z       Time zone offset (no characters if no time zone exists)
-- %%       A literal "%" character
-- ======== ===================================================================
--
-- The above definitions are mostly equivalent to the strftime() C function,
-- with the following differences:
--
-- %h is an extension
-- %q is an extension
-- %Ex is not implemented
-- %Ox is not implemented
-- %U uses 1 instead of 0 as the first value
-- %w uses 1 instead of 0 as the first value
-- %W uses the ISO8601 algorithm
--
-- The function also accepts length specifiers and the _, -, and 0 flags
-- between the % and template substitution character. The # and ^ flags are
-- accepted, but ignored.
-------------------------------------------------------------------------------

-- Utility sub-routine 1
CREATE FUNCTION TS$PAD(VALUE VARCHAR(11), MINLEN INTEGER, PAD VARCHAR(1))
    RETURNS VARCHAR(100)
    SPECIFIC TS$PAD
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE WHEN LENGTH(VALUE) < MINLEN
        THEN REPEAT(PAD, MINLEN - LENGTH(VALUE)) || VALUE
        ELSE VALUE
    END!

-- Utility sub-routine 2
CREATE FUNCTION TS$FMT(VALUE INTEGER, FLAGS VARCHAR(5), MINLEN INTEGER, PAD VARCHAR(1))
    RETURNS VARCHAR(100)
    SPECIFIC TS$FMT
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TS$PAD(RTRIM(CHAR(VALUE)), MINLEN,
        CASE
            WHEN POSSTR(FLAGS, '_') > 0 THEN ' '
            WHEN POSSTR(FLAGS, '0') > 0 THEN '0'
            WHEN POSSTR(FLAGS, '-') > 0 THEN ''
            ELSE PAD
        END)!

-- Main routine
CREATE FUNCTION TS_FORMAT(AFORMAT VARCHAR(100), ATIMESTAMP TIMESTAMP)
    RETURNS VARCHAR(100)
    SPECIFIC TS_FORMAT1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
BEGIN ATOMIC
    DECLARE I SMALLINT;
    DECLARE J SMALLINT;
    DECLARE RESULT VARCHAR(100);
    DECLARE FLAGS VARCHAR(5);
    DECLARE MINLEN INTEGER;
    SET I = 1;
    SET RESULT = '';
    WHILE I <= LENGTH(AFORMAT) DO
        IF SUBSTR(AFORMAT, I, 1) = '%' AND I < LENGTH(AFORMAT) THEN
            SET I = I + 1;
            -- Extract the optional flags
            SET J = I;
            WHILE I < LENGTH(AFORMAT) AND LOCATE(SUBSTR(AFORMAT, J, 1), '_-0^#') > 0 DO
                SET J = J + 1;
            END WHILE;
            IF J > I THEN
                SET FLAGS = SUBSTR(AFORMAT, I, J - I);
                SET I = J;
            ELSE
                SET FLAGS = '';
            END IF;
            -- Extract the optional minimum length specification
            SET J = I;
            WHILE J < LENGTH(AFORMAT) AND LOCATE(SUBSTR(AFORMAT, J, 1), '0123456789') > 0 DO
                SET J = J + 1;
            END WHILE;
            IF J > I THEN
                SET MINLEN = INT(SUBSTR(AFORMAT, I, J - I));
                SET I = J;
            ELSE
                SET MINLEN = NULL;
            END IF;
            -- Act on the format specification
            SET RESULT = RESULT ||
                CASE SUBSTR(AFORMAT, I, 1)
                    WHEN '%' THEN '%'
                    WHEN 'a' THEN LEFT(DAYNAME(ATIMESTAMP), 3)
                    WHEN 'A' THEN DAYNAME(ATIMESTAMP)
                    WHEN 'b' THEN LEFT(MONTHNAME(ATIMESTAMP), 3)
                    WHEN 'B' THEN MONTHNAME(ATIMESTAMP)
                    WHEN 'c' THEN CHAR(DATE(ATIMESTAMP), LOCAL) || ' ' || CHAR(TIME(ATIMESTAMP), LOCAL)
                    WHEN 'C' THEN TS$FMT(YEAR(ATIMESTAMP) / 100,             FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'd' THEN TS$FMT(DAY(ATIMESTAMP),                    FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'D' THEN INSERT(CHAR(DATE(ATIMESTAMP), USA), 7, 2, '')
                    WHEN 'e' THEN TS$FMT(DAY(ATIMESTAMP),                    FLAGS, COALESCE(MINLEN, 2), ' ')
                    WHEN 'F' THEN CHAR(DATE(ATIMESTAMP), ISO)
                    WHEN 'g' THEN TS$FMT(MOD(YEAR_ISO(ATIMESTAMP), 100),     FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'G' THEN TS$FMT(YEAR_ISO(ATIMESTAMP),               FLAGS, COALESCE(MINLEN, 4), '0')
                    WHEN 'h' THEN TS$FMT(((MONTH(ATIMESTAMP) - 1) / 6) + 1,  FLAGS, COALESCE(MINLEN, 1), '0')
                    WHEN 'H' THEN TS$FMT(HOUR(ATIMESTAMP),                   FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'I' THEN TS$FMT(MOD(HOUR(ATIMESTAMP) + 11, 12) + 1, FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'j' THEN TS$FMT(DAYOFYEAR(ATIMESTAMP),              FLAGS, COALESCE(MINLEN, 3), '0')
                    WHEN 'k' THEN TS$FMT(HOUR(ATIMESTAMP),                   FLAGS, COALESCE(MINLEN, 2), ' ')
                    WHEN 'l' THEN TS$FMT(MOD(HOUR(ATIMESTAMP) + 11, 12) + 1, FLAGS, COALESCE(MINLEN, 2), ' ')
                    WHEN 'm' THEN TS$FMT(MONTH(ATIMESTAMP),                  FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'M' THEN TS$FMT(MINUTE(ATIMESTAMP),                 FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'n' THEN X'0A'
                    WHEN 'p' THEN CASE WHEN HOUR(ATIMESTAMP) < 12 THEN 'AM' ELSE 'PM' END
                    WHEN 'P' THEN CASE WHEN HOUR(ATIMESTAMP) < 12 THEN 'am' ELSE 'pm' END
                    WHEN 'q' THEN TS$FMT(QUARTER(ATIMESTAMP),                FLAGS, COALESCE(MINLEN, 1), '0')
                    WHEN 'S' THEN TS$FMT(SECOND(ATIMESTAMP),                 FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 't' THEN X'09'
                    WHEN 'T' THEN CHAR(TIME(ATIMESTAMP), JIS)
                    WHEN 'u' THEN TS$FMT(DAYOFWEEK_ISO(ATIMESTAMP),          FLAGS, COALESCE(MINLEN, 1), '0')
                    WHEN 'U' THEN TS$FMT(WEEK(ATIMESTAMP),                   FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'V' THEN TS$FMT(WEEK_ISO(ATIMESTAMP),               FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'w' THEN TS$FMT(DAYOFWEEK(ATIMESTAMP),              FLAGS, COALESCE(MINLEN, 1), '0')
                    WHEN 'W' THEN TS$FMT(WEEK_ISO(ATIMESTAMP),               FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'x' THEN CHAR(DATE(ATIMESTAMP), LOCAL)
                    WHEN 'X' THEN CHAR(TIME(ATIMESTAMP), LOCAL)
                    WHEN 'y' THEN TS$FMT(MOD(YEAR(ATIMESTAMP), 100),         FLAGS, COALESCE(MINLEN, 2), '0')
                    WHEN 'Y' THEN TS$FMT(YEAR(ATIMESTAMP),                   FLAGS, COALESCE(MINLEN, 4), '0')
                    WHEN 'Z' THEN
                        CASE WHEN CURRENT TIMEZONE < 0 THEN '-' ELSE '+' END ||
                        TRANSLATE('AB:CD', DIGITS(CURRENT TIMEZONE), 'ABCDEF')
                    ELSE ''
                END;
        ELSE
            SET RESULT = RESULT || SUBSTR(AFORMAT, I, 1);
        END IF;
        SET I = I + 1;
    END WHILE;
    RETURN RESULT;
END!

CREATE FUNCTION TS_FORMAT(AFORMAT VARCHAR(100), ATIMESTAMP DATE)
    RETURNS VARCHAR(100)
    SPECIFIC TS_FORMAT2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TS_FORMAT(AFORMAT, TIMESTAMP(ATIMESTAMP, '00:00:00'))!

CREATE FUNCTION TS_FORMAT(AFORMAT VARCHAR(100), ATIMESTAMP TIME)
    RETURNS VARCHAR(100)
    SPECIFIC TS_FORMAT3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TS_FORMAT(AFORMAT, TIMESTAMP('0001-01-01', ATIMESTAMP))!

CREATE FUNCTION TS_FORMAT(AFORMAT VARCHAR(100), ATIMESTAMP VARCHAR(26))
    RETURNS VARCHAR(100)
    SPECIFIC TS_FORMAT4
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    TS_FORMAT(AFORMAT, TIMESTAMP(ATIMESTAMP))!

COMMENT ON SPECIFIC FUNCTION TS$PAD
    IS 'Internal utility sub-routine for TS_FORMAT'!
COMMENT ON SPECIFIC FUNCTION TS$FMT
    IS 'Internal utility sub-routine for TS_FORMAT'!
COMMENT ON SPECIFIC FUNCTION TS_FORMAT1
    IS 'A version of C''s strftime() for DB2. Formats ATIMESTAMP according to the AFORMAT string, containing %-prefixed templates which will be replaced with elements of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION TS_FORMAT2
    IS 'A version of C''s strftime() for DB2. Formats ATIMESTAMP according to the AFORMAT string, containing %-prefixed templates which will be replaced with elements of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION TS_FORMAT3
    IS 'A version of C''s strftime() for DB2. Formats ATIMESTAMP according to the AFORMAT string, containing %-prefixed templates which will be replaced with elements of ATIMESTAMP'!
COMMENT ON SPECIFIC FUNCTION TS_FORMAT4
    IS 'A version of C''s strftime() for DB2. Formats ATIMESTAMP according to the AFORMAT string, containing %-prefixed templates which will be replaced with elements of ATIMESTAMP'!

-- VACATIONS
-------------------------------------------------------------------------------
-- Defines non-weekend vacation dates to be taken into account by the
-- WORKINGDAY function defined below. A trigger on the table ensures that
-- weekend dates cannot be inserted.
-------------------------------------------------------------------------------

CREATE TABLE VACATIONS (
    LOCATION     CHAR(5) NOT NULL,
    VACATION     DATE NOT NULL,
    DESCRIPTION  VARCHAR(100) NOT NULL DEFAULT ''
)!

CREATE UNIQUE INDEX VACATIONS_PK
    ON VACATIONS (LOCATION, VACATION)
    INCLUDE (DESCRIPTION)
    CLUSTER!

ALTER TABLE VACATIONS
    ADD CONSTRAINT PK PRIMARY KEY (LOCATION, VACATION)!

CREATE TRIGGER VACATIONS_INSERT
    NO CASCADE BEFORE INSERT ON VACATIONS
    REFERENCING NEW AS NEW
    FOR EACH ROW
WHEN (
    DAYOFWEEK(NEW.VACATION) IN (1, 7)
)
BEGIN ATOMIC
    SIGNAL SQLSTATE '75001'
        SET MESSAGE_TEXT = 'Cannot insert a weekend (Saturday / Sunday) date into VACATIONS';
END!

CREATE TRIGGER VACATIONS_UPDATE
    NO CASCADE BEFORE UPDATE OF VACATION ON VACATIONS
    REFERENCING OLD AS OLD NEW AS NEW
    FOR EACH ROW
WHEN (
    DAYOFWEEK(NEW.VACATION) IN (1, 7)
)
BEGIN ATOMIC
    SIGNAL SQLSTATE '75001'
        SET MESSAGE_TEXT = 'Cannot change a date to a weekend (Saturday / Sunday) in VACATIONS';
END!

COMMENT ON TABLE VACATIONS
    IS 'Utility table used to define additional non-weekend vacations for the WORKINGDAY function'!
COMMENT ON VACATIONS (
    LOCATION    IS 'The location to which the vacation day is applicable; location format is user-defined',
    VACATION    IS 'The date of the vacation day',
    DESCRIPTION IS 'An optional description of the vacation day (e.g. "Bank Holiday")'
)!

-- WORKINGDAY(ADATE, RELATIVE_TO, ALOCATION)
-- WORKINGDAY(ADATE, RELATIVE_TO)
-- WORKINGDAY(ADATE, ALOCATION)
-- WORKINGDAY(ADATE)
-------------------------------------------------------------------------------
-- The WORKINGDAY function calculates the working day of a specified date
-- relative to another date. The working day is defined as the number of days
-- which are not Saturday or Sunday from the starting date to the specified
-- date, plus one. Hence, if the starting date is neither a Saturday nor a
-- Sunday, it is working day 1, the next non-weekend-day is working day 2 and
-- so on.
--
-- Requesting the working day of a Saturday or a Sunday will return the working
-- day value of the prior Friday; it is not an error to query the working day
-- of a weekend day, you should instead check for this in the calling code.
--
-- If the RELATIVE_TO parameter is omitted it will default to the start of the
-- month of the ADATE parameter. In other words, by default this function
-- calculates the working day of the month of a given date.
--
-- If you wish to take into account more than merely weekend days when
-- calculating working days, insert values into the associated VACATIONS table.
-- If a vacation date occurs between the starting date and the target date
-- (inclusive), it will count as another weekend date resulting in a working
-- day one less than would otherwise be calculated. Note that the VACATIONS
-- table will only be used when you specify a value for the optional ALOCATION
-- parameter. This parameter is used to filter the content of the VACATIONS
-- table under the assumption that different locations, most likely countries,
-- will have different public holidays.
-------------------------------------------------------------------------------

CREATE FUNCTION WORKINGDAY$DAY(ADATE DATE, RELATIVE_TO DATE)
    RETURNS INTEGER
    SPECIFIC WORKINGDAY$DAY
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DAYS(ADATE) - DAYS(RELATIVE_TO) + 1!

CREATE FUNCTION WORKINGDAY$SDOW(RELATIVE_TO DATE)
    RETURNS INTEGER
    SPECIFIC WORKINGDAY$SDOW
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    DAYOFWEEK_ISO(RELATIVE_TO)!

CREATE FUNCTION WORKINGDAY(ADATE DATE, RELATIVE_TO DATE)
    RETURNS INTEGER
    SPECIFIC WORKINGDAY1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WORKINGDAY$DAY(ADATE, RELATIVE_TO) - (
        ((WORKINGDAY$DAY(ADATE, RELATIVE_TO) + WORKINGDAY$SDOW(RELATIVE_TO)) / 7) +
        ((WORKINGDAY$DAY(ADATE, RELATIVE_TO) + WORKINGDAY$SDOW(RELATIVE_TO) - 1) / 7) -
        (WORKINGDAY$SDOW(RELATIVE_TO) / 7)
    )!

CREATE FUNCTION WORKINGDAY(ADATE DATE, RELATIVE_TO DATE, ALOCATION CHAR(5))
    RETURNS INTEGER
    SPECIFIC WORKINGDAY2
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    WORKINGDAY(ADATE, RELATIVE_TO) - (
        SELECT COUNT(*)
        FROM VACATIONS
        WHERE VACATION BETWEEN RELATIVE_TO AND ADATE
        AND LOCATION = ALOCATION
    )!

CREATE FUNCTION WORKINGDAY(ADATE DATE, ALOCATION CHAR(5))
    RETURNS INTEGER
    SPECIFIC WORKINGDAY3
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    WORKINGDAY(ADATE, MONTHSTART(ADATE), ALOCATION)!

CREATE FUNCTION WORKINGDAY(ADATE DATE)
    RETURNS INTEGER
    SPECIFIC WORKINGDAY4
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    WORKINGDAY(ADATE, MONTHSTART(ADATE))!

COMMENT ON SPECIFIC FUNCTION WORKINGDAY1
    IS 'Calculates the working day of a specified date relative to another date which defaults to the start of the month'!
COMMENT ON SPECIFIC FUNCTION WORKINGDAY2
    IS 'Calculates the working day of a specified date relative to another date which defaults to the start of the month'!
COMMENT ON SPECIFIC FUNCTION WORKINGDAY3
    IS 'Calculates the working day of a specified date relative to another date which defaults to the start of the month'!
COMMENT ON SPECIFIC FUNCTION WORKINGDAY4
    IS 'Calculates the working day of a specified date relative to another date which defaults to the start of the month'!

-- vim: set et sw=4 sts=4:
-------------------------------------------------------------------------------
-- DROP SCHEMA UTILITY
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

-- DROP_SCHEMA(ASCHEMA)
-------------------------------------------------------------------------------
-- DROP_SCHEMA is a utility procedure which drops all objects (tables, views,
-- triggers, sequences, aliases, etc.) in a schema and then drops the schema.
-- It is primarily intended to make destruction of user-owned schemas easier
-- (in the event that a user no longer requires access) but can also be used
-- to make writing upgrade scripts easier.
--
-- NOTE: this procedure is effectively redundant since DB2 9.5 which includes
-- the built-in procedure ADMIN_DROP_SCHEMA, albeit with a somewhat more
-- complicated calling convention.
-------------------------------------------------------------------------------

CREATE FUNCTION DROP$LIST(ASCHEMA VARCHAR(128))
    RETURNS TABLE(
        CREATE_TIME TIMESTAMP,
        DDL    VARCHAR(1000)
    )
    SPECIFIC DROP$LIST
    READS SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
RETURN
    WITH DROP_LIST (CREATE_TIME, SCHEMA_NAME, DDL) AS (
        SELECT
            CREATE_TIME,
            TABSCHEMA AS SCHEMA_NAME,
            'DROP ' || CASE TYPE
                WHEN 'A' THEN 'ALIAS'
                WHEN 'H' THEN 'TABLE'
                WHEN 'N' THEN 'NICKNAME'
                WHEN 'S' THEN 'TABLE'
                WHEN 'T' THEN 'TABLE'
                WHEN 'U' THEN 'TABLE'
                WHEN 'V' THEN 'VIEW'
                WHEN 'W' THEN 'VIEW'
            END || ' ' || QUOTE_IDENTIFIER(TABSCHEMA) || '.' || QUOTE_IDENTIFIER(TABNAME) AS DDL
        FROM SYSCAT.TABLES
        UNION
        SELECT
            CREATE_TIME,
            TRIGSCHEMA AS SCHEMA_NAME,
            'DROP TRIGGER ' || QUOTE_IDENTIFIER(TRIGSCHEMA) || '.' || QUOTE_IDENTIFIER(TRIGNAME) AS DDL
        FROM SYSCAT.TRIGGERS
        UNION
        SELECT
            CREATE_TIME,
            ROUTINESCHEMA AS SCHEMA_NAME,
            'DROP ' || CASE ROUTINETYPE
                WHEN 'F' THEN 'SPECIFIC FUNCTION'
                WHEN 'M' THEN 'SPECIFIC METHOD'
                WHEN 'P' THEN 'SPECIFIC PROCEDURE'
            END || ' ' || QUOTE_IDENTIFIER(ROUTINESCHEMA) || '.' || QUOTE_IDENTIFIER(SPECIFICNAME) AS DDL
        FROM SYSCAT.ROUTINES
        UNION
        SELECT
            CREATE_TIME,
            TYPESCHEMA AS SCHEMA_NAME,
            'DROP TYPE ' || QUOTE_IDENTIFIER(TYPESCHEMA) || '.' || QUOTE_IDENTIFIER(TYPENAME) AS DDL
        FROM SYSCAT.DATATYPES
        UNION
        SELECT
            CREATE_TIME,
            SEQSCHEMA AS SCHEMA_NAME,
            'DROP SEQUENCE ' || QUOTE_IDENTIFIER(SEQSCHEMA) || '.' || QUOTE_IDENTIFIER(SEQNAME) AS DDL
        FROM SYSCAT.SEQUENCES
        UNION
        SELECT
            CREATE_TIME,
            SCHEMANAME AS SCHEMA_NAME,
            'DROP SCHEMA ' || QUOTE_IDENTIFIER(SCHEMANAME) || ' RESTRICT' AS DDL
        FROM SYSCAT.SCHEMATA
    )
    SELECT CREATE_TIME, DDL
    FROM DROP_LIST
    WHERE SCHEMA_NAME = ASCHEMA!

CREATE PROCEDURE DROP_SCHEMA(ASCHEMA VARCHAR(128))
    SPECIFIC DROP_SCHEMA1
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    FOR D AS
        SELECT DDL
        FROM TABLE(DROP$LIST(ASCHEMA))
        ORDER BY CREATE_TIME DESC
    DO
        EXECUTE IMMEDIATE D.DDL;
    END FOR;
END!

COMMENT ON SPECIFIC PROCEDURE DROP_SCHEMA1
    IS 'Drops ASCHEMA and all objects within it'!

-- vim: set et sw=4 sts=4:
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

COMMENT ON SPECIFIC PROCEDURE RESTORE_VIEWS1
    IS 'Restores all views in the specified schema which were previously saved with SAVE_VIEWS'!
COMMENT ON SPECIFIC PROCEDURE RESTORE_VIEWS2
    IS 'Restores all views in the specified schema which were previously saved with SAVE_VIEWS'!

-- vim: set et sw=4 sts=4:
-------------------------------------------------------------------------------
-- EXCEPTIONS TABLE UTILITIES
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
-- The following code is adapted from the examples in the Exceptions Tables
-- section of the DB2 InfoCenter. Stored procedures are provided for creating
-- exceptions tables and analysis views based on existing tables.
-------------------------------------------------------------------------------

-- CREATE_EXCEPTION_TABLE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, DEST_TBSPACE)
-- CREATE_EXCEPTION_TABLE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE)
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
-- of SOURCE_TABLE with a suffix of '_EXCEPTIONS'. If SOURCE_SCHEMA and
-- DEST_SCHEMA are not specified they default to the value of CURRENT SCHEMA.
--
-- All authorizations present on the source table will be copied to the
-- destination table.
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
    SOURCE_SCHEMA VARCHAR(128),
    SOURCE_TABLE VARCHAR(128),
    DEST_SCHEMA VARCHAR(128),
    DEST_TABLE VARCHAR(128)
)
    SPECIFIC CREATE_EXCEPTION_TABLE2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_TABLE(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_TABLE, (
        SELECT TBSPACE
        FROM SYSCAT.TABLES
        WHERE TABSCHEMA = CURRENT SCHEMA
        AND TABNAME = SOURCE_TABLE
    ));
END!

CREATE PROCEDURE CREATE_EXCEPTION_TABLE(
    SOURCE_TABLE VARCHAR(128),
    DEST_TABLE VARCHAR(128),
    DEST_TBSPACE VARCHAR(18)
)
    SPECIFIC CREATE_EXCEPTION_TABLE3
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_TABLE(
        CURRENT SCHEMA,
        SOURCE_TABLE,
        CURRENT SCHEMA,
        DEST_TABLE,
        DEST_TBSPACE
    );
END!

CREATE PROCEDURE CREATE_EXCEPTION_TABLE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128))
    SPECIFIC CREATE_EXCEPTION_TABLE4
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_TABLE(
        CURRENT SCHEMA,
        SOURCE_TABLE,
        CURRENT SCHEMA,
        DEST_TABLE
    );
END!

CREATE PROCEDURE CREATE_EXCEPTION_TABLE(SOURCE_TABLE VARCHAR(128))
    SPECIFIC CREATE_EXCEPTION_TABLE5
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_EXCEPTION_TABLE(SOURCE_TABLE, SOURCE_TABLE || '_EXCEPTIONS');
END!

COMMENT ON SPECIFIC PROCEDURE CREATE_EXCEPTION_TABLE1
    IS 'Creates an exception table based on the structure of the specified table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_EXCEPTION_TABLE2
    IS 'Creates an exception table based on the structure of the specified table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_EXCEPTION_TABLE3
    IS 'Creates an exception table based on the structure of the specified table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_EXCEPTION_TABLE4
    IS 'Creates an exception table based on the structure of the specified table'!
COMMENT ON SPECIFIC PROCEDURE CREATE_EXCEPTION_TABLE5
    IS 'Creates an exception table based on the structure of the specified table'!

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
        || '        SUBSTR(EXCEPT_MSG, 12, INTEGER(DECIMAL(VARCHAR(SUBSTR(EXCEPT_MSG, 7, 5)), 5, 0))),'
        || '        EXCEPT_TS,'
        || '        1,'
        || '        15 + INTEGER(DECIMAL(VARCHAR(SUBSTR(EXCEPT_MSG, 7, 5)), 5, 0))'
        || '    FROM ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE)
        || '    UNION ALL'
        || '    SELECT '
        ||          COLS
        || '        EXCEPT_MSG,'
        || '        CHAR(SUBSTR(EXCEPT_MSG, J, 1)),'
        || '        SUBSTR(EXCEPT_MSG, J + 6, INTEGER(DECIMAL(VARCHAR(SUBSTR(EXCEPT_MSG, J + 1, 5)), 5, 0))),'
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

COMMENT ON SPECIFIC PROCEDURE CREATE_EXCEPTION_VIEW1
    IS 'Creates a view based on the specified exception table which interprets the content of the EXCEPT_MSG column'!
COMMENT ON SPECIFIC PROCEDURE CREATE_EXCEPTION_VIEW2
    IS 'Creates a view based on the specified exception table which interprets the content of the EXCEPT_MSG column'!
COMMENT ON SPECIFIC PROCEDURE CREATE_EXCEPTION_VIEW3
    IS 'Creates a view based on the specified exception table which interprets the content of the EXCEPT_MSG column'!

-- vim: set et sw=4 sts=4:
-------------------------------------------------------------------------------
-- EXPORT, IMPORT, LOAD UTILITIES
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
-- The following code can be used to generate EXPORT, IMPORT and LOAD
-- statements for many tables. The advantage over the the standard db2move
-- utility is firstly that arbitrary SQL queries can be used to precisely
-- define the set of tables to generate statements for, and also that
-- parameters are provided to handle tables containing generated and identity
-- columns gracefully (db2move tends to barf on these).
-------------------------------------------------------------------------------

-- TABLE_COLUMNS(ASCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- TABLE_COLUMNS(ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- TABLE_COLUMNS(ATABLE)
-------------------------------------------------------------------------------
-- This function is a utility subroutine for various functions and procedures
-- below. It returns a string containing a comma-separated list of the columns
-- in the specified table in the order that they exist in the table.
--
-- If ASCHEMA is omitted it defaults to the current schema. If the optional
-- INCLUDE_GENERATED parameter is 'Y' (the default), GENERATED ALWAYS columns
-- will be included, otherwise they are excluded. GENERATED BY DEFAULT columns
-- are always included. If the optional INCLUDE_IDENTITY parameter is 'Y' (the
-- default), IDENTITY columns will be included, otherwise they are excluded.
-------------------------------------------------------------------------------

CREATE FUNCTION TABLE_COLUMNS(
    ASCHEMA VARCHAR(128),
    ATABLE VARCHAR(128),
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS VARCHAR(8000)
    SPECIFIC TABLE_COLUMNS1
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    WITH C AS (
        SELECT VARCHAR(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
                XML2CLOB(XMLAGG(XMLELEMENT(NAME A, QUOTE_IDENTIFIER(COLNAME)) ORDER BY COLNO)),
                '<A>', ''),
                '</A>', ','),
                '&lt;', '<'),
                '&gt;', '>'),
            8000) AS COLS
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = ASCHEMA
        AND TABNAME = ATABLE
        AND (GENERATED <> 'A' OR INCLUDE_GENERATED = 'Y')
        AND (IDENTITY <> 'Y' OR INCLUDE_IDENTITY = 'Y')
    )
    SELECT LEFT(COLS, LENGTH(COLS) - 1) FROM C!

CREATE FUNCTION TABLE_COLUMNS(
    ATABLE VARCHAR(128),
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS VARCHAR(8000)
    SPECIFIC TABLE_COLUMNS2
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    TABLE_COLUMNS(CURRENT SCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)!

CREATE FUNCTION TABLE_COLUMNS(ATABLE VARCHAR(128))
    RETURNS VARCHAR(8000)
    SPECIFIC TABLE_COLUMNS3
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    TABLE_COLUMNS(CURRENT SCHEMA, ATABLE, 'Y', 'Y')!

COMMENT ON SPECIFIC FUNCTION TABLE_COLUMNS1
    IS 'Returns a string containing the comma-separated list of columns of the specified table in the order they are defined'!
COMMENT ON SPECIFIC FUNCTION TABLE_COLUMNS2
    IS 'Returns a string containing the comma-separated list of columns of the specified table in the order they are defined'!
COMMENT ON SPECIFIC FUNCTION TABLE_COLUMNS3
    IS 'Returns a string containing the comma-separated list of columns of the specified table in the order they are defined'!

-- EXPORT_TABLE(ASCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- EXPORT_TABLE(ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- EXPORT_TABLE(ATABLE)
-------------------------------------------------------------------------------
-- This function generates an EXPORT command for the specified table in the
-- specified schema or the current schema if ASCHEMA is omitted. If the
-- optional INCLUDE_GENERATED parameter is 'Y' (the default), GENERATED ALWAYS
-- columns will be included, otherwise they are excluded. GENERATED BY DEFAULT
-- columns are always included. If the optional INCLUDE_IDENTITY parameter is
-- 'Y' (the default), IDENTITY columns will be included, otherwise they are
-- excluded.
--
-- See the EXPORT_SCHEMA function for more information on the generated
-- command.
-------------------------------------------------------------------------------

CREATE FUNCTION EXPORT_TABLE(
    ASCHEMA VARCHAR(128),
    ATABLE VARCHAR(128),
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS VARCHAR(8000)
    SPECIFIC EXPORT_TABLE1
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    VALUES
        'EXPORT TO "' || RTRIM(ASCHEMA) || '.' || RTRIM(ATABLE) || '.IXF" OF IXF ' ||
        'SELECT ' || TABLE_COLUMNS(ASCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY) || ' ' ||
        'FROM ' || QUOTE_IDENTIFIER(ASCHEMA) || '.' || QUOTE_IDENTIFIER(ATABLE)!

CREATE FUNCTION EXPORT_TABLE(
    ATABLE VARCHAR(128),
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS VARCHAR(8000)
    SPECIFIC EXPORT_TABLE2
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    EXPORT_TABLE(CURRENT SCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)!

CREATE FUNCTION EXPORT_TABLE(ATABLE VARCHAR(128))
    RETURNS VARCHAR(8000)
    SPECIFIC EXPORT_TABLE3
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    EXPORT_TABLE(CURRENT SCHEMA, ATABLE, 'Y', 'Y')!

COMMENT ON SPECIFIC FUNCTION EXPORT_TABLE1
    IS 'Generates an EXPORT command for the specified table including or excluding generated and/or identity columns as requested'!
COMMENT ON SPECIFIC FUNCTION EXPORT_TABLE2
    IS 'Generates an EXPORT command for the specified table including or excluding generated and/or identity columns as requested'!
COMMENT ON SPECIFIC FUNCTION EXPORT_TABLE3
    IS 'Generates an EXPORT command for the specified table including or excluding generated and/or identity columns as requested'!

-- EXPORT_SCHEMA(ASCHEMA, INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- EXPORT_SCHEMA(INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- EXPORT_SCHEMA()
-------------------------------------------------------------------------------
-- This table function can be used to generate a script containing EXPORT
-- commands for all tables (not views) in the specified schema or the current
-- schema if the ASCHEMA parameter is omitted. This is intended to be used in
-- scripts for migrating databases or generating ETL scripts. The table
-- returned includes three columns:
--
-- TABSCHEMA - the schema of the table
-- TABNAME   - the name of the table
-- SQL       - the EXPORT command for the table
--
-- The generated EXPORT commands will target an IXF file named after the table,
-- e.g. if ASCHEMA is DATAMART, and the table is COUNTRIES the file would be
-- named "DATAMART.COUNTRIES.IXF". The export command will explicitly name all
-- columns in the table. Likewise, the LOAD_SCHEMA function generates a LOAD
-- commands with explicitly named columns.  This is to ensure that if the
-- target database's tables are not declared in exactly the same order as the
-- source database, the transfer will still work if, for example, columns have
-- been added to tables in the source but in the table declaration, they were
-- not placed at the end of the table.
--
-- If the optional INCLUDE_GENERATED parameter is 'Y' (the default), GENERATED
-- ALWAYS columns will be included, otherwise they are excluded. GENERATED BY
-- DEFAULT columns are always included. If the optional INCLUDE_IDENTITY
-- parameter is 'Y' (the default), IDENTITY columns will be included, otherwise
-- they are excluded.
-------------------------------------------------------------------------------

CREATE FUNCTION EXPORT_SCHEMA(
    ASCHEMA VARCHAR(128),
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS TABLE(
        TABSCHEMA VARCHAR(128),
        TABNAME VARCHAR(128),
        SQL VARCHAR(8000)
    )
    SPECIFIC EXPORT_SCHEMA1
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT
        TABSCHEMA,
        TABNAME,
        EXPORT_TABLE(TABSCHEMA, TABNAME, INCLUDE_GENERATED, INCLUDE_IDENTITY) AS SQL
    FROM SYSCAT.TABLES
    WHERE TABSCHEMA = ASCHEMA
    AND TYPE = 'T'!

CREATE FUNCTION EXPORT_SCHEMA(
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS TABLE(
        TABSCHEMA VARCHAR(128),
        TABNAME VARCHAR(128),
        SQL VARCHAR(8000)
    )
    SPECIFIC EXPORT_SCHEMA2
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT *
    FROM TABLE(EXPORT_SCHEMA(CURRENT SCHEMA, INCLUDE_GENERATED, INCLUDE_IDENTITY)) AS T!

CREATE FUNCTION EXPORT_SCHEMA()
    RETURNS TABLE(
        TABSCHEMA VARCHAR(128),
        TABNAME VARCHAR(128),
        SQL VARCHAR(8000)
    )
    SPECIFIC EXPORT_SCHEMA3
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT *
    FROM TABLE(EXPORT_SCHEMA(CURRENT SCHEMA, 'Y', 'Y')) AS T!

COMMENT ON SPECIFIC FUNCTION EXPORT_SCHEMA1
    IS 'Generates EXPORT commands for all tables in the specified schema, including or excluding generated and/or identity columns as requested'!
COMMENT ON SPECIFIC FUNCTION EXPORT_SCHEMA2
    IS 'Generates EXPORT commands for all tables in the specified schema, including or excluding generated and/or identity columns as requested'!
COMMENT ON SPECIFIC FUNCTION EXPORT_SCHEMA3
    IS 'Generates EXPORT commands for all tables in the specified schema, including or excluding generated and/or identity columns as requested'!

-- LOAD_TABLE(ASCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- LOAD_TABLE(ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- LOAD_TABLE(ATABLE)
-------------------------------------------------------------------------------
-- This function generates a LOAD command for the specified table in the
-- specified schema or the current schema if ASCHEMA is omitted. If the
-- optional INCLUDE_GENERATED parameter is 'Y' (the default), GENERATED ALWAYS
-- columns are assumed to be included in the source file, and the LOAD command
-- will utilize GENERATEDOVERRIDE, otherwise the LOAD command will utilize
-- GENERATEDMISSING. GENERATED BY DEFAULT columns are treated as ordinary
-- columns. If the optional INCLUDE_IDENTITY parameter is 'Y' (the default),
-- IDENTITY columns are assumed to be included in the source file, and the LOAD
-- command will utilize IDENTITYOVERRIDE, otherwise the LOAD command will
-- utilize IDENTITYMISSING.
--
-- See the EXPORT_SCHEMA function for more information on the generated
-- command.
-------------------------------------------------------------------------------

CREATE FUNCTION LOAD_TABLE(
    ASCHEMA VARCHAR(128),
    ATABLE VARCHAR(128),
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS VARCHAR(8000)
    SPECIFIC LOAD_TABLE1
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
BEGIN ATOMIC
    DECLARE HAS_GENERATED INTEGER;
    DECLARE HAS_IDENTITY INTEGER;
    DECLARE MODIFIED_BY VARCHAR(100) DEFAULT '';

    SET HAS_GENERATED = (
        SELECT COUNT(*)
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = ASCHEMA
        AND TABNAME = ATABLE
        AND GENERATED = 'A'
    );
    SET HAS_IDENTITY = (
        SELECT COUNT(*)
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = ASCHEMA
        AND TABNAME = ATABLE
        AND IDENTITY = 'Y'
    );
    SET MODIFIED_BY = 
        CASE WHEN HAS_GENERATED > 0 OR HAS_IDENTITY > 0
            THEN 'MODIFIED BY ' ||
                CASE WHEN HAS_GENERATED > 0 THEN
                    CASE INCLUDE_GENERATED
                        WHEN 'Y' THEN 'GENERATEDOVERRIDE'
                        ELSE 'GENERATEDMISSING'
                    END
                    ELSE ''
                END ||
                CASE WHEN HAS_GENERATED > 0 AND HAS_IDENTITY > 0
                    THEN ','
                    ELSE ''
                END ||
                CASE WHEN HAS_IDENTITY > 0 THEN
                    CASE INCLUDE_IDENTITY
                        WHEN 'Y' THEN 'IDENTITYOVERRIDE'
                        ELSE 'IDENTITYMISSING'
                    END
                    ELSE ''
                END || ' '
            ELSE ''
        END;
    RETURN VALUES
        'LOAD FROM ' ||
            '"' || RTRIM(ASCHEMA) || '.' || RTRIM(ATABLE) || '.IXF" OF IXF ' || MODIFIED_BY ||
        'METHOD N (' ||
            TABLE_COLUMNS(ASCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY) || ') ' ||
        'REPLACE INTO ' || QUOTE_IDENTIFIER(ASCHEMA) || '.' || QUOTE_IDENTIFIER(ATABLE) || ' (' ||
            TABLE_COLUMNS(ASCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY) || ')';
END!

CREATE FUNCTION LOAD_TABLE(
    ATABLE VARCHAR(128),
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS VARCHAR(8000)
    SPECIFIC LOAD_TABLE2
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    LOAD_TABLE(CURRENT SCHEMA, ATABLE, INCLUDE_GENERATED, INCLUDE_IDENTITY)!

CREATE FUNCTION LOAD_TABLE(ATABLE VARCHAR(128))
    RETURNS VARCHAR(8000)
    SPECIFIC LOAD_TABLE3
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    LOAD_TABLE(CURRENT SCHEMA, ATABLE, 'Y', 'Y')!

COMMENT ON SPECIFIC FUNCTION LOAD_TABLE1
    IS 'Generates a LOAD command for the specified table including or excluding generated and/or identity columns as requested'!
COMMENT ON SPECIFIC FUNCTION LOAD_TABLE2
    IS 'Generates a LOAD command for the specified table including or excluding generated and/or identity columns as requested'!
COMMENT ON SPECIFIC FUNCTION LOAD_TABLE3
    IS 'Generates a LOAD command for the specified table including or excluding generated and/or identity columns as requested'!

-- LOAD_SCHEMA(ASCHEMA, INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- LOAD_SCHEMA(INCLUDE_GENERATED, INCLUDE_IDENTITY)
-- LOAD_SCHEMA()
-------------------------------------------------------------------------------
-- This table function can be used to generate a script containing LOAD
-- commands for all tables (not views) in the specified schema or the current
-- schema if the ASCHEMA parameter is omitted. This is intended to be used in
-- scripts for migrating the database. The table returned includes three
-- columns:
--
-- TABSCHEMA - the schema of the table
-- TABNAME   - the name of the table
-- SQL       - the LOAD command for the table
--
-- This function is the counterpart of the EXPORT_SCHEMA function. See the
-- EXPORT_SCHEMA function and the LOAD_TABLE function for more information on
-- the commands generated.
-------------------------------------------------------------------------------

CREATE FUNCTION LOAD_SCHEMA(
    ASCHEMA VARCHAR(128),
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS TABLE(
        TABSCHEMA VARCHAR(128),
        TABNAME VARCHAR(128),
        SQL VARCHAR(8000)
    )
    SPECIFIC LOAD_SCHEMA1
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT
        TABSCHEMA,
        TABNAME,
        LOAD_TABLE(TABSCHEMA, TABNAME, INCLUDE_GENERATED, INCLUDE_IDENTITY) AS SQL
    FROM SYSCAT.TABLES
    WHERE TABSCHEMA = ASCHEMA
    AND TYPE = 'T'!

CREATE FUNCTION LOAD_SCHEMA(
    INCLUDE_GENERATED VARCHAR(1),
    INCLUDE_IDENTITY VARCHAR(1)
)
    RETURNS TABLE(
        TABSCHEMA VARCHAR(128),
        TABNAME VARCHAR(128),
        SQL VARCHAR(8000)
    )
    SPECIFIC LOAD_SCHEMA2
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT *
    FROM TABLE(LOAD_SCHEMA(CURRENT SCHEMA, INCLUDE_GENERATED, INCLUDE_IDENTITY)) AS T!

CREATE FUNCTION LOAD_SCHEMA()
    RETURNS TABLE(
        TABSCHEMA VARCHAR(128),
        TABNAME VARCHAR(128),
        SQL VARCHAR(8000)
    )
    SPECIFIC LOAD_SCHEMA3
    LANGUAGE SQL
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT *
    FROM TABLE(LOAD_SCHEMA(CURRENT SCHEMA, 'Y', 'Y')) AS T!

COMMENT ON SPECIFIC FUNCTION LOAD_SCHEMA1
    IS 'Generates LOAD commands for all tables in the specified schema, including or excluding generated and/or identity columns as requested'!
COMMENT ON SPECIFIC FUNCTION LOAD_SCHEMA2
    IS 'Generates LOAD commands for all tables in the specified schema, including or excluding generated and/or identity columns as requested'!
COMMENT ON SPECIFIC FUNCTION LOAD_SCHEMA3
    IS 'Generates LOAD commands for all tables in the specified schema, including or excluding generated and/or identity columns as requested'!

-- vim: set et sw=4 sts=4:
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
    SPECIFIC HISTORY$EFFNAME1
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

CREATE FUNCTION HISTORY$EFFNAME(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EFFNAME2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT VARCHAR(COLNAME, 20)
    FROM SYSCAT.COLUMNS
    WHERE TABSCHEMA = SOURCE_SCHEMA
    AND TABNAME = SOURCE_TABLE
    AND COLNO = 0!

CREATE FUNCTION HISTORY$EXPNAME(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EXPNAME1
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

CREATE FUNCTION HISTORY$EXPNAME(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EXPNAME2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT VARCHAR(COLNAME, 20)
    FROM SYSCAT.COLUMNS
    WHERE TABSCHEMA = SOURCE_SCHEMA
    AND TABNAME = SOURCE_TABLE
    AND COLNO = 1!

CREATE FUNCTION HISTORY$EFFDEFAULT(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EFFDEFAULT1
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

CREATE FUNCTION HISTORY$EFFDEFAULT(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EFFDEFAULT2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT DEFAULT
    FROM SYSCAT.COLUMNS
    WHERE TABSCHEMA = SOURCE_SCHEMA
    AND TABNAME = SOURCE_TABLE
    AND COLNO = 0!

CREATE FUNCTION HISTORY$EXPDEFAULT(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(28)
    SPECIFIC HISTORY$EXPDEFAULT1
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

CREATE FUNCTION HISTORY$EXPDEFAULT(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128))
    RETURNS VARCHAR(20)
    SPECIFIC HISTORY$EXPDEFAULT2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    SELECT DEFAULT
    FROM SYSCAT.COLUMNS
    WHERE TABSCHEMA = SOURCE_SCHEMA
    AND TABNAME = SOURCE_TABLE
    AND COLNO = 1!

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
    RETURNS VARCHAR(13)
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

CREATE FUNCTION HISTORY$PERIODSTEP(RESOLUTION VARCHAR(11))
    RETURNS VARCHAR(13)
    SPECIFIC HISTORY$PERIODSTEP1
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    CASE
        WHEN RESOLUTION IN ('MICROSECOND', 'SECOND', 'MINUTE', 'HOUR') THEN '1 MICROSECOND'
        WHEN RESOLUTION IN ('DAY', 'WEEK', 'WEEK_ISO', 'MONTH', 'YEAR') THEN '1 DAY'
        ELSE RAISE_ERROR('70001', 'Invalid RESOLUTION value ' || RESOLUTION)
    END!

CREATE FUNCTION HISTORY$PERIODSTEP(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128))
    RETURNS VARCHAR(13)
    SPECIFIC HISTORY$PERIODSTEP2
    LANGUAGE SQL
    DETERMINISTIC
    NO EXTERNAL ACTION
    READS SQL DATA
RETURN
    CASE (
            SELECT TYPENAME
            FROM SYSCAT.COLUMNS
            WHERE TABSCHEMA = SOURCE_SCHEMA
            AND TABNAME = SOURCE_TABLE
            AND COLNO = 0
        )
        WHEN 'TIMESTAMP' THEN '1 MICROSECOND'
        WHEN 'DATE' THEN '1 DAY'
        ELSE RAISE_ERROR('70001', 'Unexpected datatype found in effective column')
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
    SOURCE_TABLE VARCHAR(128)
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
        || ' ON NEW.' || HISTORY$EFFNAME(SOURCE_SCHEMA, SOURCE_TABLE) || ' - ' || HISTORY$PERIODSTEP(SOURCE_SCHEMA, SOURCE_TABLE)
        || ' BETWEEN OLD.' || HISTORY$EFFNAME(SOURCE_SCHEMA, SOURCE_TABLE)
        || ' AND OLD.' || HISTORY$EXPNAME(SOURCE_SCHEMA, SOURCE_TABLE);
    FOR C AS
        SELECT COALESCE(KEYSEQ, 0) AS KEYSEQ, COLNAME
        FROM SYSCAT.COLUMNS
        WHERE TABSCHEMA = SOURCE_SCHEMA
        AND TABNAME = SOURCE_TABLE
        AND COLNO >= 2
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
            || QUOTE_IDENTIFIER(HISTORY$EXPNAME(SOURCE_SCHEMA, SOURCE_TABLE)) || ', NEW.'
            || QUOTE_IDENTIFIER(HISTORY$EFFNAME(SOURCE_SCHEMA, SOURCE_TABLE)) || ') AS CHANGED'
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
        || '    WHERE ' || HISTORY$EXPNAME(SOURCE_SCHEMA, SOURCE_TABLE) || ' < ' || HISTORY$EXPDEFAULT(SOURCE_SCHEMA, SOURCE_TABLE)
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
        || '    SELECT MIN(' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(SOURCE_SCHEMA, SOURCE_TABLE)) || ')'
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
        AND COLNO >= 2
        ORDER BY COLNO
    DO
        SET SELECT_STMT = SELECT_STMT
            || ', H.' || QUOTE_IDENTIFIER(C.COLNAME);
    END FOR;
    RETURN SELECT_STMT
        || ' FROM RANGE R INNER JOIN ' || QUOTE_IDENTIFIER(SOURCE_SCHEMA) || '.' || QUOTE_IDENTIFIER(SOURCE_TABLE) || ' H'
        || ' ON R.D BETWEEN H.' || QUOTE_IDENTIFIER(HISTORY$EFFNAME(SOURCE_SCHEMA, SOURCE_TABLE))
        || ' AND H.' || QUOTE_IDENTIFIER(HISTORY$EXPNAME(SOURCE_SCHEMA, SOURCE_TABLE));
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

-- CREATE_HISTORY_CHANGES(SOURCE_SCHEMA, SOURCE_TABLE, DEST_SCHEMA, DEST_VIEW)
-- CREATE_HISTORY_CHANGES(SOURCE_TABLE, DEST_VIEW)
-- CREATE_HISTORY_CHANGES(SOURCE_TABLE)
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
    DEST_VIEW VARCHAR(128)
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
        || HISTORY$CHANGES(SOURCE_SCHEMA, SOURCE_TABLE);
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
    SET DDL = 'COMMENT ON COLUMN '
        || QUOTE_IDENTIFIER(DEST_SCHEMA) || '.' || QUOTE_IDENTIFIER(DEST_VIEW) || '.' || QUOTE_IDENTIFIER('CHANGE')
        || ' IS ' || QUOTE_STRING('The type of change that occured (INSERT/UPDATE/DELETE)');
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
    DEST_VIEW VARCHAR(128)
)
    SPECIFIC CREATE_HISTORY_CHANGES2
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_CHANGES(CURRENT SCHEMA, SOURCE_TABLE, CURRENT SCHEMA, DEST_VIEW);
END!

CREATE PROCEDURE CREATE_HISTORY_CHANGES(
    SOURCE_TABLE VARCHAR(128)
)
    SPECIFIC CREATE_HISTORY_CHANGES3
    MODIFIES SQL DATA
    NOT DETERMINISTIC
    NO EXTERNAL ACTION
    LANGUAGE SQL
BEGIN ATOMIC
    CALL CREATE_HISTORY_CHANGES(SOURCE_TABLE, REPLACE(SOURCE_TABLE, '_HISTORY', '_CHANGES'));
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
-- the earliest record in the history table up to the current date. See the
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
-------------------------------------------------------------------------------
-- PERL COMPATIBLE REGULAR EXPRESSION FUNCTIONS
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
-- These functions are inspired by Knut Stolze's excellent developerWorks
-- article, "Bringing the Power of Regular Expression Matching to SQL",
-- available from:
--
-- http://www.ibm.com/developerworks/data/library/techarticle/0301stolze/0301stolze.html
--
-- The functions provide PCRE (Perl Compatible Regular Expression) facilities
-- to DB2. They depend on the pcre library, and the pcre_udfs library. The pcre
-- library is usually either provided or easily installed on most Linux
-- distros, e.g.:
--
--   Ubuntu: apt-get install libpcre3 libpcre3-dev
--   Gentoo: emerge libpcre
--   Fedora: ???
--
-- To install these functions, do not run this script. Rather, use the Makefile
-- with the GNU make utility. The "build", "install", and "register" targets do
-- what they say on the tin...
-------------------------------------------------------------------------------


-- PCRE_SEARCH(PATTERN, TEXT, START)
-- PCRE_SEARCH(PATTERN, TEXT)
-------------------------------------------------------------------------------
-- PCRE searching function. Given a regular expression in PATTERN, and some
-- text to search in TEXT, returns the 1-based position of the first match.
-- START is an optional 1-based position from which to start the search
-- (defaults to 1 if not specified). If no match is found, the function returns
-- zero. If PATTERN, TEXT, or START is NULL, the result is NULL.
--
-- EXAMPLES
-------------------------------------------------------------------------------
-- Simple searches showing the return value is a 1-based position or 0 in the
-- case of failure
--
--   PCRE_SEARCH('FOO', 'FOOBAR') = 1
--   PCRE_SEARCH('BAR', 'FOOBAR') = 4
--   PCRE_SEARCH('BAZ', 'FOOBAR') = 0
--
-- A search to check whether a value looks vaguely like an IP address; note
-- that the octets are not checked for 0-255 range
--
--   PCRE_SEARCH('^\d{1,3}(\.\d{1,3}){3}$', '192.168.0.1') = 1
--
-- A search demonstrating use of back-references to check that a closing tag
-- matches the opening tag
--
--   PCRE_SEARCH('<([A-Z][A-Z0-9]*)[^>]*>.*?</\1>', '<B>BOLD!</B>') = 1
--
-- Searches demonstrating negative look-aheads
--
--   PCRE_SEARCH('Q(?!U)', 'QUACK') = 0
--   PCRE_SEARCH('Q(?!U)', 'QI') = 1
-------------------------------------------------------------------------------

CREATE FUNCTION PCRE_SEARCH(PATTERN VARCHAR(1000), TEXT VARCHAR(4000), START INTEGER)
    RETURNS INTEGER
    SPECIFIC PCRE_SEARCH1
    EXTERNAL NAME 'pcre_udfs!pcre_udf_search'
    LANGUAGE C
    PARAMETER STYLE SQL
    PARAMETER CCSID UNICODE
    DETERMINISTIC
    NOT FENCED
    RETURNS NULL ON NULL INPUT
    NO SQL
    NO EXTERNAL ACTION
    SCRATCHPAD 100
    FINAL CALL
    ALLOW PARALLEL!

CREATE FUNCTION PCRE_SEARCH(PATTERN VARCHAR(1000), TEXT VARCHAR(4000))
    RETURNS INTEGER
    SPECIFIC PCRE_SEARCH2
    LANGUAGE SQL
    PARAMETER CCSID UNICODE
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    PCRE_SEARCH(PATTERN, TEXT, 1)!

COMMENT ON SPECIFIC FUNCTION PCRE_SEARCH1
    IS 'Searches for regular expression PATTERN within TEXT starting at 1-based START'!
COMMENT ON SPECIFIC FUNCTION PCRE_SEARCH2
    IS 'Searches for regular expression PATTERN within TEXT'!

-- PCRE_SUB(PATTERN, REPL, TEXT, START)
-- PCRE_SUB(PATTERN, REPL, TEXT)
-------------------------------------------------------------------------------
-- PCRE substitution function. Given a regular expression in PATTERN, a
-- substitution pattern in REPL, some text to match in TEXT, and an optional
-- 1-based START position for the search, returns REPL with backslash prefixed
-- group specifications replaced by the corresponding matched group, e.g. \0
-- refers to the group that matches the entire PATTERN, \1 refers to the first
-- capturing group in PATTERN. To include a literal backslash in REPL double
-- it, i.e. \\. Returns NULL if the PATTERN does not match TEXT.
--
-- Note that ordinary C-style backslash escapes are NOT interpreted by this
-- function within REPL, i.e. \n will NOT be replaced by a newline character.
-- Use ordinary SQL hex-strings for this.
--
-- EXAMPLES
-------------------------------------------------------------------------------
-- Simple searches demonstrating extraction of the matched portion of TEXT (if
-- any)
--
--   PCRE_SUB('FOO', '\0', 'FOOBAR') = 'FOO'
--   PCRE_SUB('FOO(BAR)?', '\0', 'FOOBAR') = 'FOOBAR'
--   PCRE_SUB('BAZ', '\0', 'FOOBAR') = NULL
--
-- A substitution demonstrating the extraction of an IP address from some text
--
--   PCRE_SUB('\b(\d{1,3}(\.\d{1,3}){3})\b', '\1',
--     'IP address: 192.168.0.1') = '192.168.0.1'
--
-- A substitution demonstrating the replacement of one HTML tag with another
--
--   PCRE_SUB('<([A-Z][A-Z0-9]*)[^>]*>(.*?)</\1>',
--     '<I>\2</I>', '<B>BOLD!</B>') = '<I>BOLD!</I>'
--
-- A substitution demonstrating that look-aheads do not form part of the
-- match
--
--   PCRE_SUB('Q(?!U)', '\0', 'QI') = 'Q'
-------------------------------------------------------------------------------

CREATE FUNCTION PCRE_SUB(PATTERN VARCHAR(1000), REPL VARCHAR(4000), TEXT VARCHAR(4000), START INTEGER)
    RETURNS VARCHAR(4000)
    SPECIFIC PCRE_SUB1
    EXTERNAL NAME 'pcre_udfs!pcre_udf_sub'
    LANGUAGE C
    PARAMETER STYLE SQL
    PARAMETER CCSID UNICODE
    DETERMINISTIC
    NOT FENCED
    RETURNS NULL ON NULL INPUT
    NO SQL
    NO EXTERNAL ACTION
    SCRATCHPAD 100
    FINAL CALL
    ALLOW PARALLEL!

CREATE FUNCTION PCRE_SUB(PATTERN VARCHAR(1000), REPL VARCHAR(4000), TEXT VARCHAR(4000))
    RETURNS VARCHAR(4000)
    SPECIFIC PCRE_SUB2
    LANGUAGE SQL
    PARAMETER CCSID UNICODE
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    PCRE_SUB(PATTERN, REPL, TEXT, 1)!

COMMENT ON SPECIFIC FUNCTION PCRE_SUB1
    IS 'Returns replacement pattern REPL with substitutions from matched groups of regular expression PATTERN in TEXT starting from 1-based START'!
COMMENT ON SPECIFIC FUNCTION PCRE_SUB2
    IS 'Returns replacement pattern REPL with substitutions from matched groups of regular expression PATTERN in TEXT'!

-- PCRE_GROUPS(PATTERN, TEXT)
-------------------------------------------------------------------------------
-- PCRE groups table function. Given a regular expression in PATTERN, and some
-- text to search in TEXT, the function performs a search for PATTERN in the
-- text and returns the result as a table containing the following columns:
--
-- GROUP
--   The index of the capturing group; group 0 represents the portion of TEXT
--   which matched the entire PATTERN.
--
-- POSITION
--   The 1-based position of the group within TEXT.
--
-- CONTENT
--   The content of the matched group.
--
-- Any groups which did not match are excluded from the result. Note however
-- that groups which match the empty string are included. If PATTERN or TEXT is
-- NULL, or if no match for PATTERN can be found in TEXT, the result is an
-- empty table.
--
-- EXAMPLES
-------------------------------------------------------------------------------
-- This example demonstrates how multiple groups are matched and returned by
-- the function.
--
--   SELECT
--       T.GROUP,
--       T.POSITION,
--       T.CONTENT
--   FROM
--       TABLE(
--           PCRE_GROUPS('(<([A-Z][A-Z0-9]*)[^>]*>)(.*?)(</\2>)', '<B>BOLD!</B>')
--       ) AS T
--
--   GROUP  POSITION  CONTENT
--   -----  --------  -------------------------
--   0      1         <B>BOLD!</B>
--   1      1         <B>
--   2      2         B
--   3      4         BOLD!
--   4      9         </B>
--
-- Example demonstrating how unmatched groups are not returned, while groups
-- matching the empty string are.
--
--   SELECT
--       T.GROUP,
--       T.POSITION,
--       T.CONTENT
--   FROM
--       TABLE(
--           PCRE_GROUPS('(FOO)?(\s?)(BAR)?(\s?)(BAZ)?', 'FOOBAR')
--       ) AS T
--
--   GROUP  POSITION  CONTENT
--   -----  --------  -------------------------
--   0      1         FOOBAR
--   1      1         FOO
--   2      4
--   3      4         BAR
--   4      7
-------------------------------------------------------------------------------

CREATE FUNCTION PCRE_GROUPS(PATTERN VARCHAR(1000), TEXT VARCHAR(4000))
    RETURNS TABLE (GROUP INTEGER, POSITION INTEGER, CONTENT VARCHAR(4000))
    SPECIFIC PCRE_GROUPS1
    EXTERNAL NAME 'pcre_udfs!pcre_udf_groups'
    LANGUAGE C
    PARAMETER STYLE SQL
    PARAMETER CCSID UNICODE
    DETERMINISTIC
    NOT FENCED
    RETURNS NULL ON NULL INPUT
    NO SQL
    NO EXTERNAL ACTION
    SCRATCHPAD 100
    NO FINAL CALL
    DISALLOW PARALLEL!

COMMENT ON SPECIFIC FUNCTION PCRE_GROUPS1
    IS 'Searches for regular expression PATTERN in TEXT, returning a table detailing all matched groups'!

-- PCRE_SPLIT(PATTERN, TEXT)
-------------------------------------------------------------------------------
-- PCRE string splitting function. Given a regular expression in PATTERN, and
-- some text in TEXT, the function searches for every occurence of PATTERN in
-- TEXT and breaks TEXT into chunks based on those matches. Each chunk is
-- returned as a row in the result table which has the following columns:
--
-- ELEMENT
--   The 1-based index of the chunk. Note that there are usually two rows for
--   each index, one where SEPARATOR is zero, and another where SEPARATOR is
--   one.
--
-- SEPARATOR
--   Contains 1 if the row was a match for PATTERN, and 0 if the row was text
--   from between matches.
--
-- POSITION
--   The 1-based position of CONTENT within the original TEXT.
--
-- CONTENT
--   The extract from TEXT.
--
-- Note that PATTERN must not match an empty string - if it did so the routine
-- could not advance along TEXT. If such a match occurs the routine will
-- terminate with an error. If PATTERN or TEXT is NULL, the result is an empty
-- table.
--
-- EXAMPLES
-------------------------------------------------------------------------------
-- An example demonstrating a simple split. Note that a row is still returned
-- for the "missing" value, albeit with an empty CONTENT value.
--
--   SELECT
--       T.ELEMENT,
--       T.SEPARATOR,
--       T.POSITION,
--       T.CONTENT
--   FROM
--       TABLE(
--           PCRE_SPLIT(':', 'A:B:C::E')
--       ) AS T
--
--   ELEMENT  SEPARATOR  POSITION  CONTENT
--   -------  ---------  --------  -------------------
--   1        0          1         A
--   1        1          2         :
--   2        0          3         B
--   2        1          4         :
--   3        0          5         C
--   3        1          6         :
--   4        0          7
--   4        1          7         :
--   5        0          8         E
--
-- An example demonstrating a very rudimentary CSV parser. Note that to keep
-- things simple, we actually treat the separator pattern as the data here,
-- filter out the interleaved commas and remove the quotes surrounding
-- delimited values.
--
--   SELECT
--       T.ELEMENT,
--       CASE WHEN LEFT(T.CONTENT, 1) = '"'
--           THEN SUBSTR(T.CONTENT, 2, LENGTH(T.CONTENT) - 2)
--           ELSE T.CONTENT
--       END AS CONTENT
--   FROM
--       TABLE(
--           PCRE_SPLIT('([^",][^,]*|"[^"]*")', '"Some",CSV,",data"')
--       ) AS T
--   WHERE
--       T.SEPARATOR = 1
--
--   ELEMENT  CONTENT
--   -------  -------------------
--   1        Some
--   2        CSV
--   3        ,data
-------------------------------------------------------------------------------

CREATE FUNCTION PCRE_SPLIT(PATTERN VARCHAR(1000), TEXT VARCHAR(4000))
    RETURNS TABLE (ELEMENT INTEGER, SEPARATOR INTEGER, POSITION INTEGER, CONTENT VARCHAR(4000))
    SPECIFIC PCRE_SPLIT1
    EXTERNAL NAME 'pcre_udfs!pcre_udf_split'
    LANGUAGE C
    PARAMETER STYLE SQL
    PARAMETER CCSID UNICODE
    DETERMINISTIC
    NOT FENCED
    RETURNS NULL ON NULL INPUT
    NO SQL
    NO EXTERNAL ACTION
    SCRATCHPAD 100
    NO FINAL CALL
    DISALLOW PARALLEL!

COMMENT ON SPECIFIC FUNCTION PCRE_SPLIT1
    IS 'Searches for all occurrences of regular expression PATTERN in TEXT, returning a table of all matches and the text between each match'!

-- vim: set et sw=4 sts=4:
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
COMMIT!
