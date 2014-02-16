.. _QUARTER_START:

============================
QUARTERSTART scalar function
============================

Returns the first day of the quarter that ADATE exists within, or the first day
of the quarter AQUARTER in the year AYEAR.

Prototypes
==========

.. code-block:: sql

    QUARTERSTART(AYEAR INTEGER, AQUARTER INTEGER)
    QUARTERSTART(ADATE DATE)
    QUARTERSTART(ADATE TIMESTAMP)
    QUARTERSTART(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the first day of AQUARTER in AYEAR, or the first
day of the quarter of ADATE depending on the variant of the function that is
called.

Parameters
==========

AYEAR
    If provided, the year of AQUARTER for which to return the starting date.
AQUARTER
    If provided, the quarter for which to return to the starting date.
ADATE
    If provided the date in the quarter for which to return the starting date.
    Either AYEAR and AQUARTER, or ADATE must be specified.

Examples
========

Calculate the starting date of the second quarter in 2010:

.. code-block:: sql

    VALUES QUARTERSTART(2010, 2);

::

    1
    ----------
    2010-04-01


Calculate the start date of the quarter containing the first of February, 2010:

.. code-block:: sql

    VALUES QUARTERSTART('2010-02-01');

::

    1
    ----------
    2010-01-01


See Also
========

* `Source code`_
* :ref:`QUARTER_END`
* `QUARTER`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L583
.. _QUARTER: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000837.html
