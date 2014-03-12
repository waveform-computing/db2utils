.. _WEEKS_IN_YEAR_ISO:

===============================
WEEKSINYEAR_ISO scalar function
===============================

Returns the number of weeks within the year that **ADATE** exists within, or
the number of weeks in **AYEAR** according to the ISO8601 standard.

Prototypes
==========

.. code-block:: sql

    WEEKSINYEAR_ISO(AYEAR INTEGER)
    WEEKSINYEAR_ISO(ADATE DATE)
    WEEKSINYEAR_ISO(ADATE TIMESTAMP)
    WEEKSINYEAR_ISO(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the number of weeks in **AYEAR** according to the ISO8601 standard
(weeks start on a Monday, and overlap calendar year ends to ensure all weeks
are "whole"), or the number of weeks in the year that **ADATE** exists within
depending on the variant of the function that is called.

Parameters
==========

AYEAR
    If provided, the year for which to calculate the number of weeks.

ADATE
    If provided, the date in the year for which to calculate the number of
    weeks. Either **AYEAR** or **ADATE** must be specified.

Examples
========

Calculate the number of weeks in the year 2010 according to ISO8601:

.. code-block:: sql

    VALUES WEEKSINYEAR_ISO(2010);

::

    1
    ------
        52


Calculate the number of weeks in the first 10 years of the 21st century
according to ISO8601:

.. code-block:: sql

    SELECT YEAR(D) AS YEAR, WEEKSINYEAR_ISO(D) AS WEEKS
    FROM TABLE(DATE_RANGE('2000-01-01', '2010-01-01', 10000));

::

    YEAR        WEEKS
    ----------- ------
           2000     52
           2001     52
           2002     52
           2003     52
           2004     53
           2005     52
           2006     52
           2007     52
           2008     52
           2009     53
           2010     52


See Also
========

* `Source code`_
* :ref:`WEEKS_IN_YEAR`
* `WEEK_ISO`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L1376
.. _WEEK_ISO: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0005481.html
