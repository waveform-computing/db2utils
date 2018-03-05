.. _WEEKS_IN_YEAR:

===========================
WEEKSINYEAR scalar function
===========================

Returns the number of weeks within the year that **ADATE** exists within, or
the number of weeks in **AYEAR**.

Prototypes
==========

.. code-block:: sql

    WEEKSINYEAR(AYEAR INTEGER)
    WEEKSINYEAR(ADATE DATE)
    WEEKSINYEAR(ADATE TIMESTAMP)
    WEEKSINYEAR(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the number of weeks in **AYEAR** (weeks start on a Sunday, and partial
weeks are permitted at the start and end of the year), or the number of weeks
in the year that **ADATE** exists within depending on the variant of the
function that is called.

Parameters
==========

AYEAR
    If provided, the year for which to calculate the number of weeks.

ADATE
    If provided, the date in the year for which to calculate the number of
    weeks. Either **AYEAR** or **ADATE** must be specified.

Examples
========

Calculate the number of weeks in the year 2010:

.. code-block:: sql

    VALUES WEEKSINYEAR(2010);

::

    1
    ------
        53


Calculate the number of weeks in the first 10 years of the 21st century:

.. code-block:: sql

    SELECT YEAR(D) AS YEAR, WEEKSINYEAR(D) AS WEEKS
    FROM TABLE(DATE_RANGE('2000-01-01', '2010-01-01', 10000));

::

    YEAR        WEEKS
    ----------- ------
           2000     54
           2001     53
           2002     53
           2003     53
           2004     53
           2005     53
           2006     53
           2007     53
           2008     53
           2009     53
           2010     53


See Also
========

* `Source code`_
* :ref:`WEEKS_IN_YEAR_ISO`
* `WEEK`_ (built-in function)

.. _WEEK: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000871.html
.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L1312
