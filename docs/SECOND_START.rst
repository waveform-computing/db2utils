.. _SECOND_START:

===========================
SECONDSTART scalar function
===========================

Returns a TIMESTAMP at the start of **AHOUR:AMINUTE:ASECOND** on the date
**AYEAR**, **AMONTH**, **ADAY**, or at the start of the second of
**ATIMESTAMP**.

Prototypes
==========

.. code-block:: sql

    SECONDSTART(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER, AMINUTE INTEGER, ASECOND INTEGER)
    SECONDSTART(ATIMESTAMP TIMESTAMP)
    SECONDSTART(ATIMESTAMP VARCHAR(26))

    RETURNS TIMESTAMP


Description
===========

Returns a TIMESTAMP value representing the first microsecond of **ASECOND** in
**AMINUTE** in **AHOUR** on the date given by **AYEAR**, **AMONTH**, and
**ADAY**, or of the timestamp given by **ATIMESTAMP** depending on the variant
of the function that is called.

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

ASECOND
    If provided, the second component of the resulting timestamp.

ATIMESTAMP
    If provided, the timestamp from which to derive the start of the second.
    Either **AYEAR**, **AMONTH**, **ADAY**, **AHOUR**, **AMINUTE**, and
    **ASECOND**, or **ATIMESTAMP** must be provided.

Examples
========

Truncate the specified timestamp to the nearest second:

.. code-block:: sql

    VALUES SECONDSTART('2010-01-23 04:56:12.123456');

::

    1
    --------------------------
    2010-01-23-04.56.12.000000


Generate a timestamp at the start of a second with the specified fields:

.. code-block:: sql

    VALUES SECONDSTART(2010, 2, 14, 9, 30, 44);

::

    1
    --------------------------
    2010-02-14-09.30.44.000000


See Also
========

* `Source code`_
* :ref:`SECOND_END`
* `SECOND`_ (built-in function)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L1776
.. _SECOND: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000847.html
