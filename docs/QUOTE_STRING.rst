.. _QUOTE_STRING:

============================
QUOTE_STRING scalar function
============================

Returns ASTRING surrounded by single quotes with all necessary escaping. Useful
when constructing SQL for EXECUTE IMMEDIATE within a procedure.

Prototypes
==========

.. code-block:: sql

    QUOTE_STRING(ASTRING VARCHAR(4000))

    RETURNS VARCHAR(4000)


Description
===========

Returns ASTRING surrounded by single quotes and performs any necessary escaping
within the string to make it valid SQL. For example, single quotes within
ASTRING are doubled, and control characters like CR or LF are returned as
concatenated hex-strings.

Parameters
==========

ASTRING
    The string to enclose in single-quotation marks.

Examples
========

Quote a simple string:

.. code-block:: sql

    VALUES QUOTE_STRING('A string')

::

    1
    ---------------...
    'A string'


Quote a string containing an apostrophe (the delimiter for SQL strings):

.. code-block:: sql

    VALUES QUOTE_STRING('Frank''s string')

::

    1
    --------------------...
    'Frank''s string'


Quote a string containing a control character (in this case a line-feed):

.. code-block:: sql

    VALUES QUOTE_STRING('A multi' || X'0A' || 'line string')


::

    1
    ------------------------------------...
    'A multi' || X'0A' || 'line string'


See Also
========

* `Source code`_
* :ref:`QUOTE_IDENTIFIER`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/sql.sql#L28
