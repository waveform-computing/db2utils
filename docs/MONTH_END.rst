.. _MONTH_END:

========================
MONTHEND scalar function
========================

Returns the last day of month AMONTH in the year AYEAR, or the last day of the month of ADATE.

Prototypes
==========

.. code-block:: sql

    MONTHEND(AYEAR INTEGER, AMONTH INTEGER)
    MONTHEND(ADATE DATE)
    MONTHEND(ADATE TIMESTAMP)
    MONTHEND(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the last day of AMONTH in AYEAR, or the last day of the month of ADATE depending on the variant of the function that is called.

Parameters
==========

AYEAR
    If provided, the year of AMONTH for which to return the ending date.
AMONTH
    If provided, the month for which to return to the ending date.
ADATE
    If provided the date in the month for which to return the ending date. Either AYEAR and AMONTH, or ADATE must be specified.

Examples
========

Calculate the ending date of the second month of 2010:

.. code-block:: sql

    VALUES MONTHEND(2010, 2);


::

    1
    ----------
    2010-02-28


Calculate the ending date for the 28th of January, 2009:

.. code-block:: sql

    VALUES MONTHEND('2009-01-28');


::

    1
    ----------
    2009-01-31


See Also
========

* `Source code`_
* :ref:`MONTH_START`
* `MONTH`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L435
.. _MONTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000830.html
