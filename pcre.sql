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
