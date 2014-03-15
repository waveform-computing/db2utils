.. _TS_FORMAT:

=========================
TS_FORMAT scalar function
=========================

A version of C's strftime() for DB2. Formats **ATIMESTAMP** according to the
**AFORMAT** string, containing %-prefixed templates which will be replaced with
elements of **ATIMESTAMP**.

Prototypes
==========

.. code-block:: sql

    TS_FORMAT(AFORMAT VARCHAR(100), ATIMESTAMP TIMESTAMP)
    TS_FORMAT(AFORMAT VARCHAR(100), ATIMESTAMP DATE)
    TS_FORMAT(AFORMAT VARCHAR(100), ATIMESTAMP TIME)
    TS_FORMAT(AFORMAT VARCHAR(100), ATIMESTAMP VARCHAR(26))

    RETURNS VARCHAR(100)


Description
===========

TS_FORMAT is a reimplementation of C's strftime() function which converts a
TIMESTAMP (or DATE, TIME, or VARCHAR(26) containing a string representation of
a TIMESTAMP) into a VARCHAR according to a format string containing %-prefixed
templates which will be replaced with components derived from the provided
TIMESTAMP. The templates which can be used within the format string are as
follows:

+--------------+-------------------------------------------------------------+
| **Template** | **Meaning**                                                 |
+==============+=============================================================+
| %a           | Locale's abbreviated weekday name                           |
+--------------+-------------------------------------------------------------+
| %A           | Locale's full weekday name                                  |
+--------------+-------------------------------------------------------------+
| %b           | Locale's abbreviated month name                             |
+--------------+-------------------------------------------------------------+
| %B           | Locale's full month name                                    |
+--------------+-------------------------------------------------------------+
| %c           | Locale's appropriate date and time representation           |
+--------------+-------------------------------------------------------------+
| %C           | The century number (year/100), 00-99                        |
+--------------+-------------------------------------------------------------+
| %d           | Day of the month as a decimal number, 01-31                 |
+--------------+-------------------------------------------------------------+
| %D           | Equivalent to ``'%m/%d/%y'`` (US format)                    |
+--------------+-------------------------------------------------------------+
| %e           | Like %d, but with leading space instead of zero             |
+--------------+-------------------------------------------------------------+
| %F           | Equivalent to ``'%Y-%m-%d'`` (ISO8601 format)               |
+--------------+-------------------------------------------------------------+
| %G           | ISO8601 year with century as a decimal number               |
+--------------+-------------------------------------------------------------+
| %g           | ISO8601 year without century as a decimal number            |
+--------------+-------------------------------------------------------------+
| %h           | Half of the year as a decimal number, 1-2                   |
+--------------+-------------------------------------------------------------+
| %H           | Hour (24-hr clock) as a decimal number, 00-23               |
+--------------+-------------------------------------------------------------+
| %I           | Hour (12-hr clock) as a decimal number, 01-12               |
+--------------+-------------------------------------------------------------+
| %j           | Day of the year as a decimal number, 001-366                |
+--------------+-------------------------------------------------------------+
| %k           | Like %H with leading space instead of zero                  |
+--------------+-------------------------------------------------------------+
| %l           | Like %I with leading space instead of zero                  |
+--------------+-------------------------------------------------------------+
| %m           | Month as a decimal number, 01-12                            |
+--------------+-------------------------------------------------------------+
| %M           | Minute as a decimal number, 00-59                           |
+--------------+-------------------------------------------------------------+
| %n           | Newline character (``X'0A'``)                               |
+--------------+-------------------------------------------------------------+
| %p           | Locale's equivalent of either AM or PM                      |
+--------------+-------------------------------------------------------------+
| %P           | Like ``'%p'`` but lowercase                                 |
+--------------+-------------------------------------------------------------+
| %q           | Quarter of the year as decimal number, 1-4                  |
+--------------+-------------------------------------------------------------+
| %S           | Second as a decimal number, 00-61                           |
+--------------+-------------------------------------------------------------+
| %t           | A tab character (``X'09'``)                                 |
+--------------+-------------------------------------------------------------+
| %T           | Equivalent to ``'%H:%M:%S'``                                |
+--------------+-------------------------------------------------------------+
| %u           | Weekday as a decimal number, 1 (Monday) - 7 (Sunday)        |
+--------------+-------------------------------------------------------------+
| %U           | Week number of the year (Sunday as the first day of the     |
|              | week) as a decimal number, 01-54                            |
+--------------+-------------------------------------------------------------+
| %V           | ISO8601 Week number of the year (Monday as the first day of |
|              | the week) as a decimal number, 01-53                        |
+--------------+-------------------------------------------------------------+
| %w           | Weekday as a decimal number, 1 (Sunday) - 7 (Monday)        |
+--------------+-------------------------------------------------------------+
| %W           | Equivalent to ``'%V'``                                      |
+--------------+-------------------------------------------------------------+
| %x           | Locale's appropriate date representation                    |
+--------------+-------------------------------------------------------------+
| %X           | Locale's appropriate time representation                    |
+--------------+-------------------------------------------------------------+
| %y           | Year without century as a decimal number, 00-99             |
+--------------+-------------------------------------------------------------+
| %Y           | Year with century as a decimal number                       |
+--------------+-------------------------------------------------------------+
| %Z           | Time zone offset (no characters if no time zone exists)     |
+--------------+-------------------------------------------------------------+
| %%           | A literal % character                                       |
+--------------+-------------------------------------------------------------+

.. note::

    This routine was primarily included in response to the rather useless
    `TIMESTAMP_FORMAT`_ included in early versions (pre-fixpack 4?) of DB2 9.5,
    which only permitted specification of a single ISO8601-ish format string.
    Later fixpacks and DB2 9.7 now include a fairly decent TIMESTAMP_FORMAT
    implementation which is considerably more efficient than this one, although
    still somewhat limited in the range of available templates.

Parameters
==========

AFORMAT
    A string containing the templates to substitute with the fields of
    **ATIMESTAMP**.

ATIMESTAMP
    A TIMESTAMP, DATE, TIME, or VARCHAR(26) value (containing a string
    representation of a timestamp) which will be used to calculate the
    substitutions for the templates in **AFORMAT**.

Examples
========

Format the 7th of August, 2010 in US style:

.. code-block:: sql

    VALUES TS_FORMAT('%m/%d/%Y', '2010-08-07');

::

    1
    ----------------------------------------------------------------------------------------------------
    08/07/2010


Construct a sentence describing the week of a given date:

.. code-block:: sql

    VALUES TS_FORMAT('Week %U of %B, %Y', '2010-01-01');

::

    1
    ----------------------------------------------------------------------------------------------------
    Week 01 of January, 2010


See Also
========

* `Source code`_
* `TIMESTAMP_FORMAT`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L2178
.. _TIMESTAMP_FORMAT: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0007107.html
