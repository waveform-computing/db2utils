.. _QUARTER_END:

==========================
QUARTEREND scalar function
==========================

Returns the last day of the quarter that **ADATE** exists within, or the last
day of the quarter **AQUARTER** in the year **AYEAR**.

Prototypes
==========

.. code-block:: sql

    QUARTEREND(AYEAR INTEGER, AQUARTER INTEGER)
    QUARTEREND(ADATE DATE)
    QUARTEREND(ADATE TIMESTAMP)
    QUARTEREND(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the last day of **AQUARTER** in **AYEAR**, or the
last day of the quarter of **ADATE** depending on the variant of the function
that is called.

Parameters
==========

AYEAR
    If provided, the year of **AQUARTER** for which to return the ending date.

AQUARTER
    If provided, the quarter for which to return to the ending date.

ADATE
    If provided the date in the quarter for which to return the ending date.
    Either **AYEAR** and **AQUARTER**, or **ADATE** must be specified.

Examples
========

Calculate the ending date of the second quarter in 2010:

.. code-block:: sql

    VALUES QUARTEREND(2010, 2);

::

    1
    ----------
    2010-06-30


Calculate the end date of the quarter containing the first of February, 2010:

.. code-block:: sql

    VALUES QUARTEREND('2010-02-01');

::

    1
    ----------
    2010-03-31


See Also
========

* `Source code`_
* :ref:`QUARTER_START`
* `QUARTER`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L753
.. _QUARTER: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000837.html
