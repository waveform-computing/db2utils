.. _WEEK_CLAIM:

==========================
WEEK_CLAIM scalar function
==========================

Returns the week of the year that **ADATE** exists within, according to the
CLAIM calendar.

Prototypes
==========

.. code-block:: sql

    WEEK_CLAIM(ADATE DATE)
    WEEK_CLAIM(ADATE TIMESTAMP)
    WEEK_CLAIM(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the week of the year of **ADATE**, according to the CLAIM calendar.
**ADATE** can be expressed as a DATE value, a TIMESTAMP, or a VARCHAR
containing a valid string representation of a date or timestamp. If ADATE is
NULL, the result is NULL. Otherwise, the result is a SMALLINT between 1 and 53.

Parameters
==========

ADATE
    The date to calculate the week of year for, according to the CLAIM
    calendar.

Examples
========

Calculate the CLAIM week for the 2nd of January, 2010:

.. code-block:: sql

    VALUES WEEK_CLAIM(DATE(2010, 1, 2));

::

    1
    ------
         2


Calculate the CLAIM week for the 31st of December, 2010:

.. code-block:: sql

    VALUES WEEK_CLAIM('2010-12-31');

::

    1
    ------
         1


See Also
========

* `Source code`_
* `WEEK <http://pic.dhe.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000871.html>`_ (built-in function)
* :ref:`DAY_CLAIM`
* :ref:`MONTH_CLAIM`
* :ref:`QUARTER_CLAIM`
* :ref:`YEAR_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L3007
