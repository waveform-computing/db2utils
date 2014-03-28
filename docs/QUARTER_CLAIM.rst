.. _QUARTER_CLAIM:

=============================
QUARTER_CLAIM scalar function
=============================

Returns the quarter of the year that **ADATE** exists within, according to the
CLAIM calendar.

Prototypes
==========

.. code-block:: sql

    QUARTER_CLAIM(ADATE DATE)
    QUARTER_CLAIM(ADATE TIMESTAMP)
    QUARTER_CLAIM(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the quarter of the year of **ADATE**, according to the CLAIM calendar.
**ADATE** can be expressed as a DATE value, a TIMESTAMP, or a VARCHAR
containing a valid string representation of a date or timestamp. If ADATE is
NULL, the result is NULL. Otherwise, the result is a SMALLINT between 1 and 4.

Parameters
==========

ADATE
    The date to calculate the quarter of, according to the CLAIM calendar.

Examples
========

Calculate the CLAIM quarter for the 1st of June, 2010:

.. code-block:: sql

    VALUES QUARTER_CLAIM(DATE(2010, 6, 1));

::

    1
    ------
         2


Calculate the CLAIM quarter for the 31st of December, 2010:

.. code-block:: sql

    VALUES QUARTER_CLAIM('2010-12-31');

::

    1
    ------
         1


See Also
========

* `Source code`_
* `QUARTER <http://pic.dhe.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000837.html>`_ (built-in function)
* :ref:`DAY_CLAIM`
* :ref:`WEEK_CLAIM`
* :ref:`MONTH_CLAIM`
* :ref:`YEAR_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L3059
