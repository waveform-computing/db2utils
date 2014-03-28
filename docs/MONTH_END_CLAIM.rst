.. _MONTH_END_CLAIM:

==============================
MONTHEND_CLAIM scalar function
==============================

Returns the last day of month **AMONTH** in the year **AYEAR**, or the last day
of the month of **ADATE**, according to the CLAIM calendar.

Prototypes
==========

.. code-block:: sql

    MONTHEND_CLAIM(AYEAR INTEGER, AMONTH INTEGER)
    MONTHEND_CLAIM(ADATE DATE)
    MONTHEND_CLAIM(ADATE TIMESTAMP)
    MONTHEND_CLAIM(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the last day of **AMONTH** in **AYEAR**, or the
last day of the month of **ADATE** depending on the variant of the function
that is called, according to the CLAIM calendar.

Parameters
==========

AYEAR
    If provided, the year of **AMONTH** for which to return the ending date.

AMONTH
    If provided, the month for which to return to the ending date.

ADATE
    If provided the date in the month for which to return the ending date.
    Either **AYEAR** and **AMONTH**, or **ADATE** must be specified.

Examples
========

Calculate the end of the second month of 2010, according to the CLAIM calendar:

.. code-block:: sql

    VALUES MONTHEND_CLAIM(2010, 2);

::

    1
    ----------
    2010-02-19


Calculate the CLAIM month ending date for the 28th of January, 2009 (which is
actually in February according to the CLAIM calendar):

.. code-block:: sql

    VALUES MONTHEND_CLAIM('2009-01-28');

::

    1
    ----------
    2009-02-20


See Also
========

* `Source code`_
* :ref:`MONTH_START_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/ibm/date_time.sql#L2610

