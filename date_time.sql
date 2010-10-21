-------------------------------------------------------------------------------
-- DATE, TIME, AND TIMESTAMP UTILITIES
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

COMMENT ON SPECIFIC FUNCTION TIMESTAMP1
    IS 'Constructs a TIMESTAMP from the specified seconds after the epoch. This is the inverse function of SECONDS'!

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

COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH1
    IS 'Returns the number of weeks (ranging from Monday to Sunday, including partials) in AMONTH in AYEAR'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH2
    IS 'Returns the number of weeks (randing from Monday to Sunday, including partials) in the month in which ADATE exists'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH3
    IS 'Returns the number of weeks (randing from Monday to Sunday, including partials) in the month in which ADATE exists'!
COMMENT ON SPECIFIC FUNCTION WEEKSINMONTH4
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
    LOCATION     VARCHAR(10) NOT NULL,
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

CREATE FUNCTION WORKINGDAY(ADATE DATE, RELATIVE_TO DATE, ALOCATION VARCHAR(10))
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

CREATE FUNCTION WORKINGDAY(ADATE DATE, ALOCATION VARCHAR(10))
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
