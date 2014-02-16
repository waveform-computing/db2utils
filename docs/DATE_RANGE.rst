.. _DATE_RANGE:

=========================
DATE_RANGE table function
=========================

Returns a table of DATEs from START to FINISH (inclusive), incrementing by STEP
with each row (where STEP is an 8 digit duration formatted as YYYYMMDD, which
defaults to 1 day).

Prototypes
==========

.. code-block:: sql

    DATE_RANGE(START DATE, FINISH DATE, STEP DECIMAL(8, 0))
    DATE_RANGE(START DATE, FINISH TIMESTAMP, STEP DECIMAL(8, 0))
    DATE_RANGE(START TIMESTAMP, FINISH DATE, STEP DECIMAL(8, 0))
    DATE_RANGE(START TIMESTAMP, FINISH TIMESTAMP, STEP DECIMAL(8, 0))
    DATE_RANGE(START DATE, FINISH VARCHAR(26), STEP DECIMAL(8, 0))
    DATE_RANGE(START VARCHAR(26), FINISH DATE, STEP DECIMAL(8, 0))
    DATE_RANGE(START VARCHAR(26), FINISH VARCHAR(26), STEP DECIMAL(8, 0))
    DATE_RANGE(START TIMESTAMP, FINISH VARCHAR(26), STEP DECIMAL(8, 0))
    DATE_RANGE(START VARCHAR(26), FINISH TIMESTAMP, STEP DECIMAL(8, 0))
    DATE_RANGE(START DATE, FINISH DATE)
    DATE_RANGE(START DATE, FINISH TIMESTAMP)
    DATE_RANGE(START TIMESTAMP, FINISH DATE)
    DATE_RANGE(START TIMESTAMP, FINSIH TIMESTAMP)
    DATE_RANGE(START DATE, FINISH VARCHAR(26))
    DATE_RANGE(START VARCHAR(26), FINISH DATE)
    DATE_RANGE(START VARCHAR(26), FINISH VARCHAR(26))
    DATE_RANGE(START TIMESTAMP, FINISH VARCHAR(26))
    DATE_RANGE(START VARCHAR(26), FINISH TIMESTAMP)

    RETURNS TABLE(
      D DATE
    )


Description
===========

DATE_RANGE generates a range of dates from START to FINISH inclusive, advancing
in increments given by the date duration STEP. Date durations are DECIMAL(8, 0)
values structured as YYYYMMDD (in DB2 they are typically derived as the result
of subtracting two DATE values). Hence, the following call would generate all
dates from the 1st of January 2006 to the 31st of January 2006.

.. code-block:: sql

    DATE_RANGE('2006-01-01', '2006-01-31', 1)


Alternatively, the following call can be used to generate the 1st day of each
month in the year 2006:

.. code-block:: sql

    DATE_RANGE('2006-01-01', '2006-12-01', 100)

Note that 100 does *not* mean increment by 100 days each time, but by 1 month
each time because the digit 1 falls in the MM part of YYYYMMDD. If STEP is
omitted it defaults to 1 day.

Parameters
==========

START
    The date (specified as a DATE, TIMESTAMP, or VARCHAR(26)) from which to
    start generating dates. START will always be part of the resulting table.
FINISH
    The date (specified as a DATE, TIMESTAMP, or VARCHAR(26)) on which to stop
    generating dates. FINISH may be part of the resulting table if iteration
    stops on FINISH. However, if the specified STEP causes iteration to
    overshoot FINISH, it will not be included.
STEP
    If provided, the duration by which to increment each row of the output.
    Specified as a date duration; a DECIMAL(8,0) value formatted as YYYYMMDD
    (numebr of years, number of months, number of days).

Returns
=======

D
    The function returns a table with a single column simply named "D" which
    contains the dates generated.

Examples
========

Generate all days in the first month of 2010:

.. code-block:: sql

    SELECT D
    FROM TABLE(
      DATE_RANGE(MONTHSTART(2010, 1), MONTHEND(2010, 1))
    );

::

    D
    ----------
    2010-01-01
    2010-01-02
    2010-01-03
    2010-01-04
    2010-01-05
    2010-01-06
    2010-01-07
    2010-01-08
    2010-01-09
    2010-01-10
    2010-01-11
    2010-01-12
    2010-01-13
    2010-01-14
    2010-01-15
    2010-01-16
    2010-01-17
    2010-01-18
    2010-01-19
    2010-01-20
    2010-01-21
    2010-01-22
    2010-01-23
    2010-01-24
    2010-01-25
    2010-01-26
    2010-01-27
    2010-01-28
    2010-01-29
    2010-01-30
    2010-01-31


Generate the first day of each month in 2010:

.. code-block:: sql

    SELECT D
    FROM TABLE(
      DATE_RANGE(YEARSTART(2010), YEAREND(2010), 100)
    );

::

    D
    ----------
    2010-01-01
    2010-02-01
    2010-03-01
    2010-04-01
    2010-05-01
    2010-06-01
    2010-07-01
    2010-08-01
    2010-09-01
    2010-10-01
    2010-11-01
    2010-12-01


Generate the last day of each month in 2010:

.. code-block:: sql

    SELECT MONTHEND(D) AS D
    FROM TABLE(
      DATE_RANGE(YEARSTART(2010), YEAREND(2010), 100)
    );

::

    D
    ----------
    2010-01-31
    2010-02-28
    2010-03-31
    2010-04-30
    2010-05-31
    2010-06-30
    2010-07-31
    2010-08-31
    2010-09-30
    2010-10-31
    2010-11-30
    2010-12-31


Calculate the number of days in each quarter of 2010 (this is a crude and
inefficient method, but it serves to demonstrate the ability to aggregate
result sets over date ranges):

.. code-block:: sql

    SELECT QUARTER(D) AS Q, COUNT(*) AS DAYS
    FROM TABLE(
      DATE_RANGE(YEARSTART(2010), YEAREND(2010))
    )
    GROUP BY QUARTER(D);

::

    Q           DAYS
    ----------- -----------
              1          90
              2          91
              3          92
              4          92


See Also
========

* `Source code`_
* :ref:`DATE`
* `DATE`_ (built-in function)
* `DAYS`_ (built-in function)

.. _DATE: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000784.html
.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L1610
.. _DAYS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000789.html
