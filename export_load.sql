-------------------------------------------------------------------------------
-- EXPORT, IMPORT, LOAD UTILITIES
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
        SELECT VARCHAR(REPLACE(REPLACE(XML2CLOB(XMLAGG(
            XMLELEMENT(NAME A, QUOTE_IDENTIFIER(COLNAME)) ORDER BY COLNO)), '<A>', ''),
            '</A>', ','), 8000) AS COLS
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

-- vim: set et sw=4 sts=4:
