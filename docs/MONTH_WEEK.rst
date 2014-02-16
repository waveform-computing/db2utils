.. _MONTH_WEEK:

=========================
MONTHWEEK scalar function
=========================

Returns the week of the month that ADATE exists within (weeks start on a
Sunday, result will be in the range 1-6).

Prototypes
==========

.. code-block:: sql

    MONTHWEEK(ADATE DATE)
    MONTHWEEK(ADATE TIMESTAMP)
    MONTHWEEK(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the week of the month of ADATE, where weeks start on a Sunday. The
result will be in the range 1-6 as partial weeks are permitted. For example, if
the first day of a month is a Saturday, it will be counted as week 1, which
lasts one day. The next day, Sunday, will start week 2.

Parameters
==========

ADATE
    The date to calculate the week of the month for.

Examples
========

Calculate the week of the month for the 31st of January, 2010:

.. code-block:: sql

    VALUES MONTHWEEK(DATE(2010, 1, 31));

::

    1
    ------
         6


Calculate the length of all weeks in January 2010:

.. code-block:: sql

    SELECT MONTHWEEK(D) AS WEEK_NUM, COUNT(*) AS WEEK_LENGTH
    FROM TABLE(DATE_RANGE(MONTHSTART(2010, 1), MONTHEND(2010, 1)))
    GROUP BY MONTHWEEK(D);

::

    WEEK_NUM WEEK_LENGTH
    -------- -----------
           1           2
           2           7
           3           7
           4           7
           5           7
           6           1


See Also
========

* `Source code`_
* :ref:`MONTH_WEEK_ISO`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L495
