.. _WEEK_END_ISO:

===========================
WEEKEND_ISO scalar function
===========================

Returns the last day (always a Sunday) of the week that **ADATE** exists
within, or the last day of the week **AWEEK** in the year **AYEAR** according
to the ISO8601 standard.

Prototypes
==========

.. code-block:: sql

    WEEKEND_ISO(AYEAR INTEGER, AWEEK INTEGER)
    WEEKEND_ISO(ADATE DATE)
    WEEKEND_ISO(ADATE TIMESTAMP)
    WEEKEND_ISO(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the last day of **AWEEK** in **AYEAR** according to
the ISO8601 standard, or the last day of the week of **ADATE** (always a
Sunday) depending on the variant of the function that is called.

Parameters
==========

AYEAR
    If provided, the year of **AWEEK** for which to return the ending date.

AWEEK
    If provided, the week for which to return to the ending date.

ADATE
    If provided the date in the week for which to return the ending date.
    Either **AYEAR** and **AWEEK**, or **ADATE** must be specified.

Examples
========

Calculate the ending date of the last week in 2010:

.. code-block:: sql

    VALUES WEEKEND_ISO(2010, WEEKSINYEAR_ISO(2010));

::

    1
    ----------
    2011-01-02


Calculate the end of the week for the 28th of January, 2009:

.. code-block:: sql

    VALUES WEEKEND_ISO('2009-01-28');

::

    1
    ----------
    2009-02-01


See Also
========

* `Source code`_
* :ref:`WEEK_START_ISO`
* :ref:`WEEK_END`
* `WEEK_ISO`_ (built-in function)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L1247
.. _WEEK_ISO: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0005481.html
