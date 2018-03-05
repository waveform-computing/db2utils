.. _MINUTE_START:

===========================
MINUTESTART scalar function
===========================

Returns a TIMESTAMP at the start of **AHOUR:AMINUTE** on the date **AYEAR**,
**AMONTH**, **ADAY**, or at the start of the minute of **ATIMESTAMP**.

Prototypes
==========

.. code-block:: sql

    MINUTESTART(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER, AMINUTE INTEGER)
    MINUTESTART(ATIMESTAMP TIMESTAMP)
    MINUTESTART(ATIMESTAMP VARCHAR(26))

    RETURNS TIMESTAMP


Description
===========

Returns a TIMESTAMP value representing the first microsecond of **AMINUTE** in
**AHOUR** on the date given by **AYEAR**, **AMONTH**, and **ADAY**, or of the
timestamp given by **ATIMESTAMP** depending on the variant of the function that
is called.

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

AMINUTE
    If provided, the minute component of the resulting timestamp.

ATIMESTAMP
    If provided, the timestamp from which to derive the start of the minute.
    Either **AYEAR**, **AMONTH**, **ADAY**, **AHOUR**, and **AMINUTE**, or
    **ATIMESTAMP** must be provided.

Examples
========

Truncate the specified timestamp to the nearest minute:

.. code-block:: sql

    VALUES MINUTESTART('2010-01-23 04:56:12');

::

    1
    --------------------------
    2010-01-23-04.56.00.000000


Generate a timestamp at the start of a minute with the specified fields:

.. code-block:: sql

    VALUES MINUTESTART(2010, 2, 14, 9, 30);

::

    1
    --------------------------
    2010-02-14-09.30.00.000000


See Also
========

* `Source code`_
* :ref:`MINUTE_END`
* `MINUTE`_ (built-in function)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L1672
.. _MINUTE: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000828.html
