.. _TIME:

====================
TIME scalar function
====================

Constructs a TIME from the specified hours, minutes and seconds, or seconds
from midnight.

Prototypes
==========

.. code-block:: sql

    TIME(AHOUR INTEGER, AMINUTE INTEGER, ASECOND INTEGER)
    TIME(ASECONDS BIGINT)
    TIME(ASECONDS INTEGER)

    RETURNS TIME


Description
===========

Returns a TIME with the components specified by **AHOUR**, **AMINUTE** and
**ASECOND** in the first case. In the second case, returns a TIME **ASECONDS**
after midnight. If **ASECONDS** represents a period longer than a day, the
value used is **ASECONDS** mod ``86400`` (the "date" portion of the seconds
value is removed before calculation).  This function is essentially the reverse
of the *MIDNIGHT_SECONDS* function.

Parameters
==========

AHOUR
    If provided, specifies the hour component of the resulting TIME.

AMINUTE
    If provided, specifies the minute component of the resulting TIME.

ASECONDS
    If **AHOUR** and **AMINUTE** are provided, specifies the second component
    of the resulting TIME. Otherwise, specifies the number of seconds after
    minute from which the hour and minute components will be derived.

Examples
========

Construct a time representing midnight:

.. code-block:: sql

    VALUES TIME(0);

::

    1
    --------
    00:00:00


Construct a time representing half past noon:

.. code-block:: sql

    VALUES TIME(12, 30, 0);

::

    1
    --------
    12:30:00


See Also
========

* `Source code`_
* :ref:`DATE`
* `TIME <http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000858.html>`__ (built-in function)
* `MIDNIGHT_SECONDS <http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000827.html>`__ (built-in function)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql#L280
