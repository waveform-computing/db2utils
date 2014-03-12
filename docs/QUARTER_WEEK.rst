.. _QUARTER_WEEK:

===========================
QUARTERWEEK scalar function
===========================

Returns the week of the quarter that **ADATE** exists within (weeks start on a
Sunday, result will be in the range 1-14).

Prototypes
==========

.. code-block:: sql

    QUARTERWEEK(ADATE DATE)
    QUARTERWEEK(ADATE TIMESTAMP)
    QUARTERWEEK(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the week of the quarter of **ADATE**, where weeks start on a Sunday.
The result will be in the range 1-14 as partial weeks are permitted. For
example, if the first day of a quarter is a Saturday, it will be counted as
week 1, which lasts one day. The next day, Sunday, will start week 2.

Parameters
==========

ADATE
    The date to calculate the week of the quarter for.

Examples
========

Calculate the week of the quarter for 31st of January, 2010:

.. code-block:: sql

    VALUES QUARTERWEEK(DATE(2010, 1, 31));

::

    1
    ------
         6


Show the number of weeks in all quarters in the years 2007-2010:

.. code-block:: sql

    SELECT YEAR(D) AS YEAR, QUARTER(D) AS QUARTER, QUARTERWEEK(QUARTEREND(D)) AS WEEKS
    FROM TABLE(DATE_RANGE('2007-01-01', '2010-12-31', '300'));

::

    YEAR        QUARTER     WEEKS
    ----------- ----------- ------
           2007           1     13
           2007           2     13
           2007           3     14
           2007           4     14
           2008           1     14
           2008           2     14
           2008           3     14
           2008           4     14
           2009           1     14
           2009           2     14
           2009           3     14
           2009           4     14
           2010           1     14
           2010           2     14
           2010           3     14
           2010           4     14


See Also
========

* `Source code`_
* :ref:`QUARTER_WEEK_ISO`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L822
