.. _MONTH_CLAIM:

===========================
MONTH_CLAIM scalar function
===========================

Returns the month that **ADATE** exists within, according to the CLAIM
calendar.

Prototypes
==========

.. code-block:: sql

    MONTH_CLAIM(ADATE DATE)
    MONTH_CLAIM(ADATE TIMESTAMP)
    MONTH_CLAIM(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the month of **ADATE**, according to the CLAIM calendar. **ADATE** can
be expressed as a DATE value, a TIMESTAMP, or a VARCHAR containing a valid
string representation of a date or timestamp. If ADATE is NULL, the result is
NULL. Otherwise, the result will be in the range 1-12.

Parameters
==========

ADATE
    The date to calculate the month of, according to the CLAIM calendar.

Examples
========

Calculate the CLAIM month for the 31st of January, 2010:

.. code-block:: sql

    VALUES MONTH_CLAIM(DATE(2010, 1, 31));

::

    1
    ------
         2


Calculate the length of all CLAIM months in 2010:

.. code-block:: sql

    SELECT MONTH_CLAIM(D) AS MONTH, COUNT(*) AS DAYS
    FROM TABLE(DATE_RANGE(YEARSTART_CLAIM(2010), YEAREND_CLAIM(2010)))
    GROUP BY MONTH_CLAIM(D);

::

    MONTH  DAYS
    ------ -----------
         1          28
         2          28
         3          35
         4          28
         5          35
         6          28
         7          28
         8          35
         9          28
        10          28
        11          35
        12          28


See Also
========

* `Source code`_
* `MONTH <http://pic.dhe.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000830.html>`_ (built-in function)
* :ref:`DAY_CLAIM`
* :ref:`WEEK_CLAIM`
* :ref:`QUARTER_CLAIM`
* :ref:`YEAR_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L2698
