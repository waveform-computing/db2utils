.. _YEAR_ISO:

========================
YEAR_ISO scalar function
========================

Returns the year of ADATE, unless the ISO week of ADATE exists in the prior year in which case that year is returned.

Prototypes
==========

.. code-block:: sql

    YEAR_ISO(ADATE DATE)
    YEAR_ISO(ADATE TIMESTAMP)
    YEAR_ISO(ADATE VARCHAR(26))

    RETURNS SMALLINT


Description
===========

Returns the year of ADATE, unless the ISO week number (see the built-in function `WEEK_ISO`_) of ADATE belongs to the prior year, in which case the prior year is returned.

Parameters
==========

ADATE
    The date to calculate the ISO-week based year number for.

Examples
========

Calculate the ISO-week based year number of the 1st of January, 2010:

.. code-block:: sql

    VALUES YEAR_ISO(DATE(2010, 1, 1));


::

    1
    ------
      2009


Calculate the ISO-week based year number of the 4th of January, 2010 (dates beyond the 4th of January will always be in the year of the date given the definition of ISO weeks):

.. code-block:: sql

    VALUES YEAR_ISO(DATE(2010, 1, 4)));


::

    1
    ------
      2010


See Also
========

* `Source code`_
* `YEAR`_ (built-in function)
* `WEEK_ISO`_ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L334
.. _WEEK_ISO: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0005481.html
.. _YEAR: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000872.html
