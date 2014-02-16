.. _WEEK_START_ISO:

=============================
WEEKSTART_ISO scalar function
=============================

Returns the first day (always a Monday) of the week that ADATE exists within, or the first day of the week AWEEK in the year AYEAR according to the ISO8601 standard.

Prototypes
==========

.. code-block:: sql

    WEEKSTART_ISO(AYEAR INTEGER, AWEEK INTEGER)
    WEEKSTART_ISO(ADATE DATE)
    WEEKSTART_ISO(ADATE TIMESTAMP)
    WEEKSTART_ISO(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the first day of AWEEK in AYEAR according to the ISO8601 standard, or the first day of the week of ADATE (always a Monday) depending on the variant of the function that is called.

Parameters
==========

AYEAR
    If provided, the year of AWEEK for which to return the starting date.
AWEEK
    If provided, the week for which to return to the starting date.
ADATE
    If provided the date in the week for which to return the starting date. Either AYEAR and AWEEK, or ADATE must be specified.

Examples
========

Calculate the starting date of the first week in 2010:

.. code-block:: sql

    VALUES WEEKSTART_ISO(2010, 1);


::

    1
    ----------
    2010-01-04


Calculate the start of the week for the 28th of January, 2009:

.. code-block:: sql

    VALUES WEEKSTART_ISO('2009-01-28');


::

    1
    ----------
    2009-01-26


See Also
========

* `Source code`_
* :ref:`WEEK_END_ISO`
* :ref:`WEEK_START`
* `WEEK_ISO`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L1006
.. _WEEK_ISO: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0005481.html
