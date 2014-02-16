.. _TIMESTAMP:

=========================
TIMESTAMP scalar function
=========================

Constructs a TIMESTAMP from the specified seconds after the epoch. This is the inverse function of :ref:`SECONDS`.

Prototypes
==========

.. code-block:: sql

    TIMESTAMP(ASECONDS BIGINT)
    TIMESTAMP(AYEAR INTEGER, AMONTH INTEGER, ADAY INTEGER, AHOUR INTEGER, AMINUTE INTEGER, ASECOND INTEGER, AMICROSECOND INTEGER)

    RETURNS TIMESTAMP


Description
===========

The first version of this function returns a TIMESTAMP ASECONDS seconds after 0000-12-31 00:00:00. This function is essentially the reverse of the SECONDS function. The ASECONDS value MUST be greater than 86400 (it must include a "date" portion) otherwise the returned value has an invalid year of 0000 and an error will occur.

The second version of this function simply constructs a timestamp from the given integer fields.

Parameters
==========

ASECONDS
    The number of seconds after the epoch (0000-12-31 00:00:00) which the resulting TIMESTAMP will represent.
AYEAR
    The year for the resulting timestamp.
AMONTH
    The month for the resulting timestamp (1-12).
ADAY
    The day for the resulting timestamp (1-31).
AHOUR
    The hours for the resulting timestamp (0-23).
AMINUTE
    The minutes for the resulting timestamp (0-59).
ASECOND
    The seconds for the resulting timestamp (0-59).
AMICROSECOND
    The microseconds for the resulting timestamp (0-999999).

Examples
========

Construct a TIMESTAMP representing the epoch (note that 0 cannot be used due to the offset mentioned in the :ref:`SECONDS` documentation:

.. code-block:: sql

    VALUES TIMESTAMP(86400);


::

    1
    --------------------------
    0001-01-01-00.00.00.000000


Calculate a TIMESTAMP 10 seconds before midnight on new year's day 2000 (admittedly this would be more simply accomplished with ``TIMESTAMP(YEARSTART(2000)) - 10 SECONDS``, but for the sake of demonstration we're using a round-trip of TIMESTAMP and :ref:`SECONDS` here):

.. code-block:: sql

    VALUES TIMESTAMP(SECONDS(YEARSTART(2000)) - 10);


::

    1
    --------------------------
    1999-12-31-23.59.50.000000


Construct a timestamp from a set of literal values:

.. code-block:: sql

    VALUES TIMESTAMP(2000, 1, 1, 0, 0, 0, 0);


::

    1
    --------------------------
    2000-01-01-00.00.00.000000


See Also
========

* `Source code`_
* :ref:`SECONDS`
* `TIMESTAMP`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L285
.. _TIMESTAMP: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000859.html
