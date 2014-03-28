.. _YEAR_CLAIM:

==========================
YEAR_CLAIM scalar function
==========================

Returns the year that **ADATE** exists within, according to the CLAIM
calendar.

Prototypes
==========

.. code-block:: sql

    YEAR_CLAIM(ADATE DATE)
    YEAR_CLAIM(ADATE TIMESTAMP)
    YEAR_CLAIM(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the year of **ADATE**, according to the CLAIM calendar. **ADATE** can
be expressed as a DATE value, a TIMESTAMP, or a VARCHAR containing a valid
string representation of a date or timestamp. If ADATE is NULL, the result is
NULL.

Parameters
==========

ADATE
    The date to calculate the year of, according to the CLAIM calendar.

Examples
========

Calculate the CLAIM year for the 31st of December, 2010:

.. code-block:: sql

    VALUES YEAR_CLAIM(DATE(2010, 12, 31));

::

    1
    ------
      2011


Calculate the length of all CLAIM years in the decade starting 2000:

.. code-block:: sql

    SELECT YEAR_CLAIM(D) AS YEAR, COUNT(*) AS DAYS
    FROM TABLE(DATE_RANGE(YEARSTART_CLAIM(2000), YEAREND_CLAIM(2010)))
    GROUP BY YEAR_CLAIM(D);

::

    YEAR   DAYS
    ------ -----------
      2000         364
      2001         364
      2002         364
      2003         371
      2004         364
      2005         364
      2006         364
      2007         364
      2008         371
      2009         364
      2010         364


See Also
========

* `Source code`_
* `YEAR <http://pic.dhe.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000872.html>`_ (built-in function)
* :ref:`DAY_CLAIM`
* :ref:`WEEK_CLAIM`
* :ref:`MONTH_CLAIM`
* :ref:`QUARTER_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L2753
