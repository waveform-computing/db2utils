.. _SECOND_END:

=========================
SECONDEND scalar function
=========================

Returns a TIMESTAMP at the end of **AHOUR:AMINUTE:ASECOND** on the date
**AYEAR**, **AMONTH**, **ADAY**, or at the end of the second of **ATIMESTAMP**.

Prototypes
==========

.. code-block:: sql

    SECONDEND(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER, AMINUTE INTEGER, ASECOND INTEGER)
    SECONDEND(ATIMESTAMP TIMESTAMP)
    SECONDEND(ATIMESTAMP VARCHAR(26))

    RETURNS TIMESTAMP


Description
===========

Returns a TIMESTAMP value representing the last microsecond of **ASECOND** in
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
    If provided, the timestamp from which to derive the end of the second.
    Either **AYEAR**, **AMONTH**, **ADAY**, **AHOUR**, **AMINUTE**, and
    **ASECOND**, or **ATIMESTAMP** must be provided.

Examples
========

Round the specified timestamp up to one microsecond before the next second:

.. code-block:: sql

    VALUES SECONDEND('2010-01-23 04:56:12.123456');

::

    1
    --------------------------
    2010-01-23-04.56.12.999999


Generate a timestamp at the end of a second with the specified fields:

.. code-block:: sql

    VALUES SECONDEND(2010, 2, 14, 9, 30, 44);

::

    1
    --------------------------
    2010-02-14-09.30.44.999999


See Also
========

* `Source code`_
* :ref:`SECOND_START`
* `SECOND`_ (built-in function)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L1828
.. _SECOND: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000847.html
