.. _WORKING_DAY:

==========================
WORKINGDAY scalar function
==========================

Calculates the working day of a specified date relative to another date which defaults to the start of the month

Prototypes
==========

.. code-block:: sql

    WORKINGDAY(ADATE DATE, RELATIVE_TO DATE, ALOCATION VARCHAR(10))
    WORKINGDAY(ADATE DATE, RELATIVE_TO DATE)
    WORKINGDAY(ADATE DATE, ALOCATION VARCHAR(10))
    WORKINGDAY(ADATE DATE)

    RETURNS INTEGER


Description
===========

The WORKINGDAY function calculates the working day of a specified date relative to another date. The working day is defined as the number of days which are not Saturday or Sunday from the starting date to the specified date, plus one. Hence, if the starting date is neither a Saturday nor a Sunday, it is working day 1, the next non-weekend-day is working day 2 and so on.

Requesting the working day of a Saturday or a Sunday will return the working day value of the prior Friday; it is not an error to query the working day of a weekend day, you should instead check for this in the calling code.

If the RELATIVE_TO parameter is omitted it will default to the start of the month of the ADATE parameter. In other words, by default this function calculates the working day of the month of a given date.

If you wish to take into account more than merely weekend days when calculating working days, insert values into the associated VACATIONS table. If a vacation date occurs between the starting date and the target date (inclusive), it will count as another weekend date resulting in a working day one less than would otherwise be calculated. Note that the VACATIONS table will only be used when you specify a value for the optional ALOCATION parameter. This parameter is used to filter the content of the VACATIONS table under the assumption that different locations, most likely countries, will have different public holidays.

Parameters
==========

ADATE
    The date to calculate the working day from.
RELATIVE_TO
    If specified, the date to calculate the working day relative to, i.e. the function counts the number of working days between RELATIVE_TO and ADATE. If omitted, defaults to the start of the month of ADATE.
ALOCATION
    If specified, causes the function to take into account additional vacation days defined in the VACATIONS table with the specified LOCATION.

Examples
========

Calculate the working day of the first date in 2010:

.. code-block:: sql

    VALUES WORKINGDAY(YEARSTART(2010));


::

    1
    -----------
              1


Calculate the working day of the 4th of January, 2010 (the 2nd and 3rd of January 2010 are Saturday and Sunday respectively):

.. code-block:: sql

    VALUES WORKINGDAY(DATE(2010, 1, 4))


::

    1
    -----------
              2


Calculate the number of working days in January 2010:

.. code-block:: sql

    VALUES WORKINGDAY(MONTHEND(2010, 1))


::

    1
    -----------
             21


Calculate the total number of working days in 2010:

.. code-block:: sql

    VALUES WORKINGDAY(YEAREND(2010), YEARSTART(2010))


::

    1
    -----------
            261


See Also
========

* `Source code`_

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L2155
