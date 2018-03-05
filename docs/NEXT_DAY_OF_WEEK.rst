.. _NEXT_DAY_OF_WEEK:

==============================
NEXT_DAYOFWEEK scalar function
==============================

Returns the earliest date later than **ADATE**, which is also a particular day
of the week, **ADOW** (1=Sunday, 2=Monday, 6=Saturday, etc.)

Prototypes
==========

.. code-block:: sql

    NEXT_DAYOFWEEK(ADATE DATE, ADOW INTEGER)
    NEXT_DAYOFWEEK(ADATE TIMESTAMP, ADOW INTEGER)
    NEXY_DAYOFWEEK(ADATE VARCHAR(26), ADOW INTEGER)
    NEXT_DAYOFWEEK(ADOW INTEGER)

    RETURNS DATE


Description
===========

Returns the specified day of the week following the given date. Days of the
week are specified in the same fashion as the built-in *DAYOFWEEK* function
(i.e.  1=Sunday, 2=Monday, ... 7=Saturday). If **ADATE** is omitted the current
date is used.

Parameters
==========

ADATE
    The date after which to return a specific day of the week. If this
    parameter is omitted the *CURRENT DATE* special register is used.

ADOW
    The day of the week to find specified as an integer where 1 represents
    Sunday, 2 is Monday, and so on.

Examples
========

Find the next Monday after the start of 2010:

.. code-block:: sql

    VALUES VARCHAR(NEXT_DAYOFWEEK(YEARSTART(2010), 2), ISO);

::

    1
    ----------
    2010-01-04


Find the third Thursday in February 2010 (note, the CASE expression is
necessary in case February starts on a Thursday, in which case *NEXT_DAYOFWEEK*
will be returning the date of the second Thursday in the month, not the first):

.. code-block:: sql

    VALUES VARCHAR(NEXT_DAYOFWEEK(MONTHSTART(2010, 2), 5) +
      CASE DAYOFWEEK(MONTHSTART(2010, 2))
        WHEN 5 THEN 7
        ELSE 14
      END DAYS, ISO);

::

    1
    ----------
    2010-02-18


See Also
========

* `Source code`_
* :ref:`PRIOR_DAY_OF_WEEK`

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L119
