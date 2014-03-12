.. _YEAR_START:

=========================
YEARSTART scalar function
=========================

Returns the first day of the year that **ADATE** exists within, or the first day of
the year **AYEAR**.

Prototypes
==========

.. code-block:: sql

    YEARSTART(AYEAR INTEGER)
    YEARSTART(ADATE DATE)
    YEARSTART(ADATE TIMESTAMP)
    YEARSTART(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the first day of **AYEAR**, or the first day of the
year of **ADATE** depending on the variant of the function that is called.

Parameters
==========

AYEAR
    If provided, the year for which to return the starting date.

ADATE
    If provided the date in the year for which to return the starting date.
    Either **AYEAR** or **ADATE** must be specified.

Examples
========

Calculate the starting date of 2010:

.. code-block:: sql

    VALUES YEARSTART(2010);

::

    1
    ----------
    2010-01-01


Calculate the starting date of the year for the 28th February, 2009:

.. code-block:: sql

    VALUES YEARSTART('2009-02-28');

::

    1
    ----------
    2009-01-01


See Also
========

* `Source code`_
* :ref:`YEAR_END`
* `YEAR`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L920
.. _YEAR: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000872.html
