.. _YEAR_START_CLAIM:

===============================
YEARSTART_CLAIM scalar function
===============================

Returns the first day of the year **AYEAR**, or the first day of the year of
**ADATE**, according to the CLAIM calendar.

Prototypes
==========

.. code-block:: sql

    YEARSTART_CLAIM(AYEAR INTEGER)
    YEARSTART_CLAIM(ADATE DATE)
    YEARSTART_CLAIM(ADATE TIMESTAMP)
    YEARSTART_CLAIM(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the first day of **AYEAR**, or the first day of the
year of **ADATE** depending on the variant of the function that is called,
according to the CLAIM calendar.

Parameters
==========

AYEAR
    If provided, the year for which to return the starting date.

ADATE
    If provided the date in the year for which to return the starting date.
    Either **AYEAR** or **ADATE** must be specified.

Examples
========

Calculate the starting date of 2010, according to the CLAIM calendar:

.. code-block:: sql

    VALUES YEARSTART_CLAIM(2010);

::

    1
    ----------
    2009-12-26


Calculate the starting date of the CLAIM year containing the 28th February,
2009:

.. code-block:: sql

    VALUES YEARSTART_CLAIM('2009-02-28');

::

    1
    ----------
    2008-12-27


See Also
========

* `Source code`_
* :ref:`YEAR_END_CLAIM`

.. _Source code: https://github.com/waveform80/db2utils/blob/ibm/date_time.sql#L2679

