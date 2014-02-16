.. _WEEKS_IN_MONTH_ISO:

================================
WEEKSINMONTH_ISO scalar function
================================

Returns the number of weeks within the month that ADATE exists within, or the
number of weeks in AMONTH in AYEAR.

Prototypes
==========

.. code-block:: sql

    WEEKSINMONTH_ISO(AYEAR INTEGER, AMONTH INTEGER)
    WEEKSINMONTH_ISO(ADATE DATE)
    WEEKSINMONTH_ISO(ADATE TIMESTAMP)
    WEEKSINMONTH_ISO(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the number of weeks in AMONTH in AYEAR (weeks start on a Monday, and
partial weeks are permitted at the start and end of the month), or the number
of weeks in the month that ADATE exists within depending on the variant of the
function that is called.

.. note::

    As far as I'm aware, ISO8601 doesn't say anything about weeks within a
    month, hence why this function differs from :ref:`WEEKS_IN_YEAR_ISO` which
    does *not* permit partial weeks at the start and end of a year. This
    function simply mirrors the functionality of :ref:`WEEKS_IN_MONTH` but with
    a definition of weeks that start on a Monday instead of Sunday.

Parameters
==========

AYEAR
    If provided, the year containing AMONTH for which to calculate the number
    of weeks.
AMONTH
    If provided, the month within AYEAR for which to calculate the number of
    weeks.
ADATE
    If provided, the date within the month for which to calculate the number of
    weeks. Either AYEAR and AMONTH, or ADATE must be provided.

Examples
========

Calculate the number of weeks in January 2010:

.. code-block:: sql

    VALUES WEEKSINMONTH_ISO(2010, 1);

::

    1
    ------
         5


Calculate the number of weeks in the months of 2010:

.. code-block:: sql

    SELECT MONTH(D) AS MONTH, WEEKSINMONTH_ISO(D) AS WEEKS
    FROM TABLE(DATE_RANGE('2010-01-01', '2010-12-01', 100));

::

    MONTH       WEEKS
    ----------- ------
              1      5
              2      4
              3      5
              4      5
              5      6
              6      5
              7      5
              8      6
              9      5
             10      5
             11      5
             12      5


See Also
========

* `Source code`_
* :ref:`WEEKS_IN_MONTH`
* `MONTH`_ (built-in function)
* `WEEK_ISO`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L1285
.. _WEEK_ISO: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0005481.html
.. _MONTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000830.html
