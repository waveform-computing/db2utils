.. _WEEKS_IN_MONTH:

============================
WEEKSINMONTH scalar function
============================

Returns the number of weeks within the month that **ADATE** exists within, or
the number of weeks in **AMONTH** in **AYEAR**.

Prototypes
==========

.. code-block:: sql

    WEEKSINMONTH(AYEAR INTEGER, AMONTH INTEGER)
    WEEKSINMONTH(ADATE DATE)
    WEEKSINMONTH(ADATE TIMESTAMP)
    WEEKSINMONTH(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the number of weeks in **AMONTH** in **AYEAR** (weeks start on a
Sunday, and partial weeks are permitted at the start and end of the month), or
the number of weeks in the month that **ADATE** exists within depending on the
variant of the function that is called.

Parameters
==========

AYEAR
    If provided, the year containing **AMONTH** for which to calculate the
    number of weeks.

AMONTH
    If provided, the month within **AYEAR** for which to calculate the number
    of weeks.

ADATE
    If provided, the date within the month for which to calculate the number of
    weeks. Either **AYEAR** and **AMONTH**, or **ADATE** must be provided.

Examples
========

Calculate the number of weeks in January 2010:

.. code-block:: sql

    VALUES WEEKSINMONTH(2010, 1);

::

    1
    ------
         6


Calculate the number of weeks in the months of 2010:

.. code-block:: sql

    SELECT MONTH(D) AS MONTH, WEEKSINMONTH(D) AS WEEKS
    FROM TABLE(DATE_RANGE('2010-01-01', '2010-12-01', 100));

::

    MONTH       WEEKS
    ----------- ------
              1      6
              2      5
              3      5
              4      5
              5      6
              6      5
              7      5
              8      5
              9      5
             10      6
             11      5
             12      5


See Also
========

* `Source code`_
* :ref:`WEEKS_IN_MONTH_ISO`
* `MONTH`_ (built-in function)
* `WEEK`_ (built-in function)

.. _WEEK: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000871.html
.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L1440
.. _MONTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000830.html
