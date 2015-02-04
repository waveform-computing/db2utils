.. _UNICODE_REPLACE_BAD:

============================
UNICODE_REPLACE_BAD function
============================

Returns **SOURCE** with characters that are invalid in UTF-8 encoding replaced
with the string **REPL**.

Prototypes
==========

.. code-block:: sql

    UNICODE_REPLACE_BAD(SOURCE VARCHAR(4000), REPL VARCHAR(100))
    UNICODE_REPLACE_BAD(SOURCE VARCHAR(4000))

    RETURNS VARCHAR(4000)

Description
===========

Under certain circumstances, DB2 will permit text containing characters invalid
in the UTF-8 encoding scheme to be inserted into a column intended to contain
UTF-8 encoded data. While this doesn't cause a problem for DB2 queries, it can
cause issues for down-stream appliations. This function provides a means of
stripping or replacing such invalid characters.

Parameters
==========

SOURCE
    The string to search for characters invalid in the UTF-8 encoding scheme.

REPL
    The string to replace any invalid sequences with. Defaults to the empty
    string if omitted.

Examples
========

Replacement of truncated UTF-8 characters:

.. code-block:: sql

    VALUES
        (UNICODE_REPLACE_BAD('FOO' || X'C2', 'BAR'))

::

    1
    --------------------....
    FOOBAR


Replacement of invalid characters in the middle of a string:

.. code-block:: sql

    VALUES
        (UNICODE_REPLACE_BAD('FOO' || X'80' || BAR))

::

    1
    --------------------....
    FOOBAR


See Also
========

* `SQL source code`_
* `C source code`_
* `Wikipedia UTF-8 article`_

.. _C source code: https://github.com/waveform80/db2utils/blob/master/unicode/unicode_udfs.c#L119
.. _SQL source code: https://github.com/waveform80/db2utils/blob/master/unicode.sql#L51
.. _Wikipedia UTF-8 article: http://en.wikipedia.org/wiki/UTF-8
