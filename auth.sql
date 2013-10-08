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
        FROM
            TABLE(COPY$LIST(SOURCE, SOURCE_TYPE, DEST, DEST_TYPE, INCLUDE_PERSONAL)) AS T
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
        AUTH VARCHAR(140),
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
        AUTH,
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
    -- If we remove CONTROL from a table, and the user holds CONTROL on a view
    -- defined over that table, the user implicitly loses CONTROL from the
    -- view. If we subsequently attempt to remove CONTROL the view then
    -- SQLSTATE 42504 will be raised but should be ignored. This SQLSTATE is
    -- also raised in the event that a REVOKE fails because CONTROL implies
    -- SELECT/INSERT/UPDATE/DELETE but the ORDER BY in REMOVE$LIST handles that
    -- particular case. Annoyingly, these two cases have the same SQLSTATE but
    -- different SQLCODEs - but we can only trap SQLSTATE with these handlers.
    DECLARE CONTINUE HANDLER FOR SQLSTATE '42504'
        BEGIN
        END;
    FOR D AS
        SELECT DDL
        FROM
            TABLE(REMOVE$LIST(AUTH_NAME, AUTH_TYPE, INCLUDE_PERSONAL)) AS T
        ORDER BY
            -- CONTROL must be removed before SELECT/INSERT/UPDATE/DELETE or
            -- DB2 complains that CONTROL implies the others
            CASE AUTH WHEN 'CONTROL' THEN 0 ELSE 1 END
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
