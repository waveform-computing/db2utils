.. _MONTH_START:

==========================
MONTHSTART scalar function
==========================

Returns the first day of the month that **ADATE** exists within, or the first
day of the month **AMONTH** in the year **AYEAR**.

Prototypes
==========

.. code-block:: sql

    MONTHSTART(AYEAR INTEGER, AMONTH INTEGER)
    MONTHSTART(ADATE DATE)
    MONTHSTART(ADATE TIMESTAMP)
    MONTHSTART(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the first day of **AMONTH** in **AYEAR**, or the
first day of the month of **ADATE** depending on the variant of the function
that is called.

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

Calculate the starting date of the second month in 2010:

.. code-block:: sql

    VALUES MONTHSTART(2010, 2);

::

    1
    ----------
    2010-02-01


Calculate the start of the month for the 28th of January, 2009:

.. code-block:: sql

    VALUES MONTHSTART('2009-01-28');

::

    1
    ----------
    2009-01-01


See Also
========

* `Source code`_
* :ref:`MONTH_END`
* `MONTH`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L454
.. _MONTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000830.html
