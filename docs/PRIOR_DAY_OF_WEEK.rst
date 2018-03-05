.. _PRIOR_DAY_OF_WEEK:

===============================
PRIOR_DAYOFWEEK scalar function
===============================

Returns the latest date earlier than **ADATE**, which is also a particular day
of the week, **ADOW** (1=Sunday, 2=Monday, 6=Saturday, etc.)

Prototypes
==========

.. code-block:: sql

    PRIOR_DAYOFWEEK(ADATE DATE, ADOW INTEGER)
    PRIOR_DAYOFWEEK(ADATE TIMESTAMP, ADOW INTEGER)
    PRIOR_DAYOFWEEK(ADATE VARCHAR(26), ADOW INTEGER)
    PRIOR_DAYOFWEEK(ADOW INTEGER)

    RETURNS DATE


Description
===========

Returns the specified day of the week prior to the given date. Days of the week
are specified in the same fashion as the built-in *DAYOFWEEK* function (i.e.
1=Sunday, 2=Monday, ... 7=Saturday). If **ADATE** is omitted the current date
is used.

Parameters
==========

ADATE
    The date before which to return a specific day of the week. If this
    parameter is omitted the *CURRENT DATE* special register is used.

ADOW
    The day of the week to find specified as an integer where 1 represents
    Sunday, 2 is Monday, and so on.

Examples
========

Find the Monday before the start of 2010:

.. code-block:: sql

    VALUES VARCHAR(PRIOR_DAYOFWEEK('2010-01-01', 2), ISO);

::

    1
    ----------
    2009-12-28


Find the last Friday in January, 2010:

.. code-block:: sql

    VALUES VARCHAR(PRIOR_DAYOFWEEK(MONTHEND(2010, 1), 6), ISO);

::

    1
    ----------
    2010-01-29


See Also
========

* `Source code`_
* :ref:`NEXT_DAY_OF_WEEK`

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L53
