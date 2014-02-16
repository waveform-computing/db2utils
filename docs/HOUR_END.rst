.. _HOUR_END:

=======================
HOUREND scalar function
=======================

Returns a TIMESTAMP at the end of AHOUR on the date AYEAR, AMONTH, ADAY, or at
the end of the hour of ATIMESTAMP.

Prototypes
==========

.. code-block:: sql

    HOUREND(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER)
    HOUREND(ATIMESTAMP TIMESTAMP)
    HOUREND(ATIMESTAMP VARCHAR(26))

    RETURNS TIMESTAMP


Description
===========

Returns a TIMESTAMP value representing the last microsecond of AHOUR in the
date given by AYEAR, AMONTH, and ADAY, or of the timestamp given by ATIMESTAMP
depending on the variant of the function that is called.

Parameters
==========

AYEAR
    If provided, the year component of the resulting timestamp.
AMONTH
    If provided, the month component of the resulting timestamp.
ADAY
    If provided, the day component of the resulting timestamp.
AHOUR
    If provided, the hour component of the resulting timestamp.
ATIMESTAMP
    If provided, the timestamp from which to derive the end of the hour. Either
    AYEAR, AMONTH, ADAY, and AHOUR, or ATIMESTAMP must be provided.

Examples
========

Calculate the last microsecond of the specified hour:

.. code-block:: sql

    VALUES HOUREND('2010-01-23 04:56:00');

::

    1
    --------------------------
    2010-01-23-04.59.59.999999


Calculate the end of the first working day in 2011:

.. code-block:: sql

    VALUES HOUREND(2011, 1, DAY(
      CASE WHEN DAYOFWEEK(YEARSTART(2011)) IN (1, 7)
        THEN NEXT_DAYOFWEEK(YEARSTART(2011), 2)
        ELSE YEARSTART(2011)
      END), 4);

::

    1
    --------------------------
    2011-01-03-04.59.59.999999


See Also
========

* `Source code`_
* :ref:`HOUR_START`
* `HOUR`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L1385
.. _HOUR: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000812.html
