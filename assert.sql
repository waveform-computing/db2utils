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


-- ASSERT_SIGNALS(state, sql)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if executing sql does NOT raise SQLSTATE state.
-------------------------------------------------------------------------------

CREATE PROCEDURE ASSERT_SIGNALS(STATE CHAR(5), SQL CLOB(64K))
	SPECIFIC ASSERT_SIGNALS1
	LANGUAGE SQL
	CONTAINS SQL
	NOT DETERMINISTIC
	NO EXTERNAL ACTION
BEGIN ATOMIC
	DECLARE SQLSTATE CHAR(5);
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		IF SQLSTATE <> STATE THEN
			SIGNAL SQLSTATE ASSERT_SQLSTATE
				SET MESSAGE_TEXT = SUBSTR(SQL, 1, 40) || ' signalled SQLSTATE ' || SQLSTATE || ' instead of ' || STATE;
		END IF;
	EXECUTE IMMEDIATE SQL;
	SIGNAL SQLSTATE ASSERT_SQLSTATE
		SET MESSAGE_TEXT = SQL || ' did not signal SQLSTATE ' || STATE;
END!

-- ASSERT_EQUALS(a, b)
-------------------------------------------------------------------------------
-- Raises the ASSERT_SQLSTATE if a does not equal b. The functions are
-- overloaded for most common types and generally should not need CASTs for
-- usage.
-------------------------------------------------------------------------------

CREATE PROCEDURE ASSERT_EQUALS(A INTEGER, B INTEGER)
	SPECIFIC ASSERT_EQUALS1
	LANGUAGE SQL
	CONTAINS SQL
	DETERMINISTIC
	NO EXTERNAL ACTION
BEGIN ATOMIC
	IF A <> B THEN
		SIGNAL SQLSTATE ASSERT_SQLSTATE
			SET MESSAGE_TEXT = VARCHAR(A) || ' does not equal ' || VARCHAR(B);
	END IF;
END!

CREATE PROCEDURE ASSERT_EQUALS(A DOUBLE, B DOUBLE)
	SPECIFIC ASSERT_EQUALS2
	LANGUAGE SQL
	CONTAINS SQL
	DETERMINISTIC
	NO EXTERNAL ACTION
BEGIN ATOMIC
	IF A <> B THEN
		SIGNAL SQLSTATE ASSERT_SQLSTATE
			SET MESSAGE_TEXT = VARCHAR(A) || ' does not equal ' || VARCHAR(B);
	END IF;
END!

CREATE PROCEDURE ASSERT_EQUALS(A VARCHAR(4000), B VARCHAR(4000))
	SPECIFIC ASSERT_EQUALS3
	LANGUAGE SQL
	CONTAINS SQL
	DETERMINISTIC
	NO EXTERNAL ACTION
BEGIN ATOMIC
	IF A <> B THEN
		SIGNAL SQLSTATE ASSERT_SQLSTATE
			SET MESSAGE_TEXT = QUOTE_STRING(A) || ' does not equal ' || QUOTE_STRING(B);
	END IF;
END!

CREATE PROCEDURE ASSERT_EQUALS(A TIMESTAMP, B TIMESTAMP)
	SPECIFIC ASSERT_EQUALS4
	LANGUAGE SQL
	CONTAINS SQL
	DETERMINISTIC
	NO EXTERNAL ACTION
BEGIN ATOMIC
	IF A <> B THEN
		SIGNAL SQLSTATE ASSERT_SQLSTATE
			SET MESSAGE_TEXT = VARCHAR(A) || ' does not equal ' || VARCHAR(B);
	END IF;
END!

