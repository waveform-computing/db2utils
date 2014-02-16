.. _RECREATE_TRIGGERS:

===========================
RECREATE_TRIGGERS procedure
===========================

Recreates all the inoperative triggers associated with the specified table from
their definitions in the system catalogue.

Prototypes
==========

.. code-block:: sql

    RECREATE_TRIGGERS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    RECREATE_TRIGGERS(ATABLE VARCHAR(128))


Description
===========

RECREATE_TRIGGER is a utility procedure which recreates all the inoperative
triggers defined against the table specified by ASCHEMA and ATABLE, using the
SQL found in the system catalogue tables. It is useful for quickly recreating
triggers which have been marked inoperative after a change to one or more
dependencies. If ASCHEMA is omitted it defaults to the current schema.

Parameters
==========

ASCHEMA
    If provided, the schema containing the table to recreate inoperative
    triggers for. If omitted, this parameter defaults to the value of the
    CURRENT SCHEMA special register.
ATRIGGER
    The name of the table to recreate inoperative triggers for.

Examples
========

Recreate all inoperative triggers defined against the FINANCE.LEDGER table:

.. code-block:: sql

    CALL RECREATE_TRIGGERS('FINANCE', 'LEDGER');


Recreate all inoperative triggers defined against the EMPLOYEE table in the
current schema:

.. code-block:: sql

    CALL RECREATE_TRIGGERS('EMPLOYEE');


See Also
========

* `Source code`_
* :ref:`RECREATE_TRIGGER`
* `SYSCAT.TRIGGERS`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/evolve.sql#L223
.. _SYSCAT.TRIGGERS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001066.html
