.. _WEEK_START:

=========================
WEEKSTART scalar function
=========================

Returns the first day (always a Sunday) of the week that **ADATE** exists
within, or the first day of the week **AWEEK** in the year **AYEAR**.

Prototypes
==========

.. code-block:: sql

    WEEKSTART(AYEAR INTEGER, AWEEK INTEGER)
    WEEKSTART(ADATE DATE)
    WEEKSTART(ADATE TIMESTAMP)
    WEEKSTART(ADATE VARCHAR(26))

    RETURNS DATE


Description
===========

Returns a DATE representing the first day of **AWEEK** in **AYEAR**, or the
first day of the week of **ADATE** (always a Sunday) depending on the variant
of the function that is called.

Parameters
==========

AYEAR
    If provided, the year of **AWEEK** for which to return the starting date.

AWEEK
    If provided, the week for which to return to the starting date.

ADATE
    If provided the date in the week for which to return the starting date.
    Either **AYEAR** and **AWEEK**, or **ADATE** must be specified.

Examples
========

Calculate the starting date of the first week in 2010:

.. code-block:: sql

    VALUES WEEKSTART(2010, 1);

::

    1
    ----------
    2009-12-27


Calculate the start of the week for the 28th of January, 2009:

.. code-block:: sql

    VALUES WEEKSTART('2009-01-28');

::

    1
    ----------
    2009-01-25


See Also
========

* `Source code`_
* :ref:`WEEK_END`
* :ref:`WEEK_START_ISO`
* `WEEK`_ (built-in function)

.. _WEEK: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000871.html
.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L1048
