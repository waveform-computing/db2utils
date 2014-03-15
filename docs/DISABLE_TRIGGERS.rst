.. _DISABLE_TRIGGERS:

==========================
DISABLE_TRIGGERS procedure
==========================

Disables all triggers associated with the specified table by saving their
definitions to a table and dropping them.

Prototypes
==========

.. code-block:: sql

    DISABLE_TRIGGERS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    DISABLE_TRIGGERS(ATABLE VARCHAR(128))


Description
===========

Disables all the operative triggers associated with a particular table. If a
trigger exists, but is marked inoperative, it is not touched by this procedure.
You can recreate such triggers with :ref:`RECREATE_TRIGGER` before calling
DISABLE_TRIGGERS.

Parameters
==========

ASCHEMA
    If provided, the schema containing the table for which to disable triggers.
    If omitted, defaults to the value of the *CURRENT SCHEMA* special
    register.

ATABLE
    The name of the table to disable all active triggers for.

Examples
========

Disable all triggers on the *FINANCE.LEDGER* table:

.. code-block:: sql

    CALL DISABLE_TRIGGERS('FINANCE', 'LEDGER');


Disable the triggers for the *EMPLOYEE* table in the current schema:

.. code-block:: sql

    CALL DISABLE_TRIGGERS('EMPLOYEE');


See Also
========

* `Source code`_
* :ref:`ENABLE_TRIGGERS`
* :ref:`RECREATE_TRIGGER`
* :ref:`DISABLE_TRIGGER`
* `SYSCAT.TRIGGERS`_ (built-in catalogue table)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/toggle_triggers.sql#L169
.. _SYSCAT.TRIGGERS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001066.html
