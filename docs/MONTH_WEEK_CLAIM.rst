.. _MONTH_WEEK_CLAIM:

===============================
MONTHWEEK_CLAIM scalar function
===============================

Returns the week of the month that **ADATE** exists within, according to the
CLAIM calendar.

Prototypes
==========

.. code-block:: sql

    MONTHWEEK_CLAIM(ADATE DATE)
    MONTHWEEK_CLAIM(ADATE TIMESTAMP)
    MONTHWEEK_CLAIM(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the week of the month of **ADATE**, according to the CLAIM calendar.
**ADATE** can be expressed as a DATE value, a TIMESTAMP, or a VARCHAR
containing a valid string representation of a date or timestamp. If ADATE is
NULL, the result is NULL. Otherwise, the result is a SMALLINT between 1 and 5.

Parameters
==========

ADATE
    The date to calculate the week of the month for, according to the CLAIM
    calendar.

Examples
========

Calculate the week of CLAIM month for the 1st of June, 2010:

.. code-block:: sql

    VALUES MONTHWEEK_CLAIM(DATE(2010, 6, 1));

::

    1
    ------
         1


Calculate the week of CLAIM month for the 31st of January, 2010:

.. code-block:: sql

    VALUES MONTHWEEK_CLAIM('2010-01-31');

::

    1
    ------
         2


See Also
========

* `Source code`_
* :ref:`DAY_CLAIM`
* :ref:`WEEK_CLAIM`
* :ref:`MONTH_CLAIM`
* :ref:`YEAR_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L3111
