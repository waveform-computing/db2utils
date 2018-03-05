.. _HOUR_START:

=========================
HOURSTART scalar function
=========================

Returns a TIMESTAMP at the start of **AHOUR** on the date **AYEAR**, **AMONTH**, **ADAY**, or
at the start of the hour of **ATIMESTAMP**.

Prototypes
==========

.. code-block:: sql

    HOURSTART(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER)
    HOURSTART(ATIMESTAMP TIMESTAMP)
    HOURSTART(ATIMESTAMP VARCHAR(26))

    RETURNS TIMESTAMP


Description
===========

Returns a TIMESTAMP value representing the first microsecond of **AHOUR** in
the date given by **AYEAR**, **AMONTH**, and **ADAY**, or of the timestamp
given by **ATIMESTAMP** depending on the variant of the function that is
called.

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
    If provided, the timestamp from which to derive the start of the hour.
    Either **AYEAR**, **AMONTH**, **ADAY**, and **AHOUR**, or **ATIMESTAMP**
    must be provided.

Examples
========

Truncate the specified timestamp to the nearest hour:

.. code-block:: sql

    VALUES HOURSTART('2010-01-23 04:56:00');

::

    1
    --------------------------
    2010-01-23-04.00.00.000000


Calculate the start of the first working day in 2011:

.. code-block:: sql

    VALUES HOURSTART(2011, 1, DAY(
      CASE WHEN DAYOFWEEK(YEARSTART(2011)) IN (1, 7)
        THEN NEXT_DAYOFWEEK(YEARSTART(2011), 2)
        ELSE YEARSTART(2011)
      END), 9);

::

    1
    --------------------------
    2011-01-03-09.00.00.000000


See Also
========

* `Source code`_
* :ref:`HOUR_END`
* `HOUR`_ (built-in function)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L1568
.. _HOUR: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000812.html
