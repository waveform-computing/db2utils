.. _YEAR_END:

=======================
YEAREND scalar function
=======================

Returns the last day of the year **AYEAR**, or the last day of the year of
**ADATE**.

Prototypes
==========

.. code-block:: sql

    YEAREND(AYEAR INTEGER)
    YEAREND(ADATE DATE)
    YEAREND(ADATE TIMESTAMP)
    YEAREND(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the last day of **AYEAR**, or the last day of the
year of **ADATE** depending on the variant of the function that is called.

Parameters
==========

AYEAR
    If provided, the year for which to return the ending date.

ADATE
    If provided the date in the year for which to return the ending date.
    Either **AYEAR** or **ADATE** must be specified.

Examples
========

Calculate the ending date of 2010:

.. code-block:: sql

    VALUES YEAREND(2010);

::

    1
    ----------
    2010-12-31


Calculate the ending date of the year for the 28th February, 2009:

.. code-block:: sql

    VALUES YEAREND('2009-02-28');

::

    1
    ----------
    2009-12-31


See Also
========

* `Source code`_
* :ref:`YEAR_START`
* `YEAR`_ (built-in function)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L984
.. _YEAR: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000872.html
