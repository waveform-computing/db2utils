.. _MONTH_START_CLAIM:

================================
MONTHSTART_CLAIM scalar function
================================

Returns the first day of the month that **ADATE** exists within, or the first
day of the month **AMONTH** in the year **AYEAR**, according to the CLAIM
calendar.

Prototypes
==========

.. code-block:: sql

    MONTHSTART_CLAIM(AYEAR INTEGER, AMONTH INTEGER)
    MONTHSTART_CLAIM(ADATE DATE)
    MONTHSTART_CLAIM(ADATE TIMESTAMP)
    MONTHSTART_CLAIM(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the first day of **AMONTH** in **AYEAR**, or the
first day of the month of **ADATE** depending on the variant of the function
that is called, according to the CLAIM calendar.

Parameters
==========

AYEAR
    If provided, the year of **AMONTH** for which to return the starting date.

AMONTH
    If provided, the month for which to return to the starting date.

ADATE
    If provided the date in the month for which to return the starting date.
    Either **AYEAR** and **AMONTH**, or **ADATE** must be specified.

Examples
========

Calculate the starting date of the second CLAIM calendar month in 2010:

.. code-block:: sql

    VALUES MONTHSTART_CLAIM(2010, 2);

::

    1
    ----------
    2010-01-23


Calculate the start of the CLAIM calendar month for the 28th of January, 2009
(which actually exists in February, according to the CLAIM calendar):

.. code-block:: sql

    VALUES MONTHSTART_CLAIM('2009-01-28');

::

    1
    ----------
    2009-01-24


See Also
========

* `Source code`_
* :ref:`MONTH_END_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/ibm/date_time.sql#L2638

