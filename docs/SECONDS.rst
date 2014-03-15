.. _SECONDS:

=======================
SECONDS scalar function
=======================

Returns an integer representation of the specified TIMESTAMP. The inverse of
this function is :ref:`TIMESTAMP`.

Prototypes
==========

.. code-block:: sql

    SECONDS(ATIMESTAMP TIMESTAMP)
    SECONDS(ATIMESTAMP DATE)
    SECONDS(ATIMESTAMP VARCHAR(26))

    RETURNS BIGINT


Description
===========

Returns an integer representation of a TIMESTAMP. This function is a
combination of the built-in *DAYS* and *MIDNIGHT_SECONDS* functions. The result
is a BIGINT (64-bit integer value) representing the number of seconds since one
day before 0001-01-01 at 00:00:00. The one day offset is due to the operation
of the *DAYS* function.

Parameters
==========

ATIMESTAMP
    The timestamp to convert to an integer representation. If a DATE is
    provided, then it will be treated as a TIMESTAMP with the equivalent date
    portion and a time portion of midnight.

Examples
========

Return an integer representation of the first instant of the year 2010:

.. code-block:: sql

    VALUES SECONDS(YEARSTART(2010));

::

    1
    --------------------
             63397987200


Return the number of seconds in the year 2010:

.. code-block:: sql

    VALUES SECONDS(YEARSTART(2011)) - SECONDS(YEARSTART(2010));

::

    1
    --------------------
                31536000


See Also
========

* `Source code`_
* :ref:`TIMESTAMP`
* `DAYS <http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000789.html>`__ (built-in function)
* `MIDNIGHT_SECONDS <http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000827.html>`__ (built-in function)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/date_time.sql#L186
