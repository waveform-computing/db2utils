-------------------------------------------------------------------------------
--UNICODE CORRECTION FUNCTIONS
-------------------------------------------------------------------------------
-- Copyright (c) 2015 Dave Hughes <dave@waveform.org.uk>
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
-- These functions are intended for cleaning data which contains erroneous
-- UTF-8 data. Unfortunately, under certain circumstances, DB2 will store
-- invalid UTF-8 data in VARCHAR fields which are intended to be UTF-8 encoded.
-- While this doesn't affect DB2 queries it may well affect downstream
-- applications which expect only valid UTF-8.
--
-- These functions rely on Bjoern Hoehrmann's excellent little UTF-8 decoder
-- which can be found at http://bjoern.hoehrmann.de/utf-8/decoder/dfa/
--
-- To install these functions, do not run this script. Rather, use the Makefile
-- with the GNU make utility. The "build", "install", and "register" targets do
-- what they say on the tin...
-------------------------------------------------------------------------------

-- ROLES
-------------------------------------------------------------------------------
-- The following roles grant usage and administrative rights to the objects
-- created by this module.
-------------------------------------------------------------------------------

CREATE ROLE UTILS_UNICODE_USER!
CREATE ROLE UTILS_UNICODE_ADMIN!

GRANT ROLE UTILS_UNICODE_USER TO ROLE UTILS_USER!
GRANT ROLE UTILS_UNICODE_USER TO ROLE UTILS_UNICODE_ADMIN WITH ADMIN OPTION!
GRANT ROLE UTILS_UNICODE_ADMIN TO ROLE UTILS_ADMIN WITH ADMIN OPTION!

-- UNICODE_REPLACE_BAD(SOURCE, REPL)
-- UNICODE_REPLACE_BAD(SOURCE)
-------------------------------------------------------------------------------
-- Corrects invalid UTF-8 sequences in SOURCE. Each such sequence is replaced
-- with the string in REPL, or the blank string if REPL is omitted. If
-- SOURCE or REPL are NULL, the result is NULL.
--
-- EXAMPLES
-------------------------------------------------------------------------------
-- Simple replacement of truncated UTF-8 characters:
--
--   UNICODE_REPLACE_BAD('FOO' || X'C2', 'BAR') = 'FOOBAR'
--
-- Simple replacement of invalid characters in the middle of a UTF-8 encoded
-- string:
--
--   UNICODE_REPLACE_BAD('FOO' || X'80' || 'BAR') = 'FOOBAR'
-------------------------------------------------------------------------------

CREATE FUNCTION UNICODE_REPLACE_BAD(SOURCE VARCHAR(4000), REPL VARCHAR(100))
    RETURNS VARCHAR(4000)
    SPECIFIC UNICODE_REPLACE_BAD1
    EXTERNAL NAME 'unicode_udfs!unicode_udf_replace_bad'
    LANGUAGE C
    PARAMETER STYLE SQL
    PARAMETER CCSID UNICODE
    DETERMINISTIC
    NOT FENCED
    RETURNS NULL ON NULL INPUT
    NO SQL
    NO EXTERNAL ACTION
    ALLOW PARALLEL!

CREATE FUNCTION UNICODE_REPLACE_BAD(SOURCE VARCHAR(4000))
    RETURNS VARCHAR(4000)
    SPECIFIC UNICODE_REPLACE_BAD2
    LANGUAGE SQL
    PARAMETER CCSID UNICODE
    DETERMINISTIC
    NO EXTERNAL ACTION
    CONTAINS SQL
RETURN
    UNICODE_REPLACE_BAD(SOURCE, '')!

GRANT EXECUTE ON SPECIFIC FUNCTION UNICODE_REPLACE_BAD1 TO ROLE UTILS_UNICODE_USER!
GRANT EXECUTE ON SPECIFIC FUNCTION UNICODE_REPLACE_BAD2 TO ROLE UTILS_UNICODE_USER!
GRANT EXECUTE ON SPECIFIC FUNCTION UNICODE_REPLACE_BAD1 TO ROLE UTILS_UNICODE_ADMIN WITH GRANT OPTION!
GRANT EXECUTE ON SPECIFIC FUNCTION UNICODE_REPLACE_BAD2 TO ROLE UTILS_UNICODE_ADMIN WITH GRANT OPTION!

COMMENT ON SPECIFIC FUNCTION UNICODE_REPLACE_BAD1
    IS 'Returns SOURCE string with all invalid UTF-8 sequences replaced with REPL'!
COMMENT ON SPECIFIC FUNCTION UNICODE_REPLACE_BAD2
    IS 'Returns SOURCE string with all invalid UTF-8 sequences omitted'!

-- vim: set et sw=4 sts=4:
