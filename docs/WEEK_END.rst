.. _WEEK_END:

=======================
WEEKEND scalar function
=======================

Returns the last day (always a Saturday) of the week that ADATE exists within,
or the last day of the week AWEEK in the year AYEAR.

Prototypes
==========

.. code-block:: sql

    WEEKEND(AYEAR INTEGER, AWEEK INTEGER)
    WEEKEND(ADATE DATE)
    WEEKEND(ADATE TIMESTAMP)
    WEEKEND(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the last day of AWEEK in AYEAR, or the last day of
the week of ADATE (always a Saturday) depending on the variant of the function
that is called.

Parameters
==========

AYEAR
    If provided, the year of AWEEK for which to return the ending date.
AWEEK
    If provided, the week for which to return to the ending date.
ADATE
    If provided the date in the week for which to return the ending date.
    Either AYEAR and AWEEK, or ADATE must be specified.

Examples
========

Calculate the ending date of the last week in 2010:

.. code-block:: sql

    VALUES WEEKEND(2010, WEEKSINYEAR(2010));

::

    1
    ----------
    2011-01-01


Calculate the end of the week for the 28th of January, 2009:

.. code-block:: sql

    VALUES WEEKEND('2009-01-28');

::

    1
    ----------
    2009-01-31


See Also
========

* `Source code`_
* :ref:`WEEK_START`
* :ref:`WEEK_END_ISO`
* `WEEK`_ (built-in function)

.. _WEEK: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000871.html
.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L950
