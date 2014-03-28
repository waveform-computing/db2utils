.. _YEAR_END_CLAIM:

=============================
YEAREND_CLAIM scalar function
=============================

Returns the last day of the year **AYEAR**, or the last day of the year of
**ADATE**, according to the CLAIM calendar.

Prototypes
==========

.. code-block:: sql

    YEAREND_CLAIM(AYEAR INTEGER)
    YEAREND_CLAIM(ADATE DATE)
    YEAREND_CLAIM(ADATE TIMESTAMP)
    YEAREND_CLAIM(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the last day of **AYEAR**, or the last day of the
year of **ADATE** depending on the variant of the function that is calle,
according to the CLAIM calendar.

Parameters
==========

AYEAR
    If provided, the year for which to return the ending date.

ADATE
    If provided the date in the year for which to return the ending date.
    Either **AYEAR** or **ADATE** must be specified.

Examples
========

Calculate the ending date of 2010, according to the CLAIM calendar:

.. code-block:: sql

    VALUES YEAREND_CLAIM(2010);

::

    1
    ----------
    2010-12-24


Calculate the ending date of the CLAIM year containing the 28th February, 2009:

.. code-block:: sql

    VALUES YEAREND_CLAIM('2009-02-28');

::

    1
    ----------
    2009-12-25


See Also
========

* `Source code`_
* :ref:`YEAR_START_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/ibm/date_time.sql#L2660

