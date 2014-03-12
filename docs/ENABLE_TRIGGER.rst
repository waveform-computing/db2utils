.. _ENABLE_TRIGGER:

========================
ENABLE_TRIGGER procedure
========================

Enables the specified trigger by restoring its definition from a table.

Prototypes
==========

.. code-block:: sql

    ENABLE_TRIGGER(ASCHEMA VARCHAR(128), ATRIGGER VARCHAR(128))
    ENABLE_TRIGGER(ATRIGGER VARCHAR(128))


Description
===========

Restores a previously disabled trigger by reading its definition from
:ref:`DISABLED_TRIGGERS` and recreating it. The trigger must have been disabled
with :ref:`DISABLE_TRIGGER` or :ref:`DISABLE_TRIGGERS`.

Parameters
==========

ASCHEMA
    If provided, the schema containing the trigger to enable. If omitted,
    defaults to the value of the *CURRENT SCHEMA* special register.

ATRIGGER
    The name of the trigger to enable.

Examples
========

Enable the *FINANCE.LEDGER_INSERT* trigger:

.. code-block:: sql

    CALL ENABLE_TRIGGER('FINANCE', 'LEDGER_INSERT');


Enable the *EMPLOYEE_UPDATE* trigger in the current schema:

.. code-block:: sql

    CALL ENABLE_TRIGGER('EMPLOYEE_UPDATE');


See Also
========

* `Source code`_
* :ref:`DISABLE_TRIGGER`
* :ref:`ENABLE_TRIGGERS`
* `SYSCAT.TRIGGERS`_ (built-in catalogue table)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/toggle_triggers.sql#L239
.. _SYSCAT.TRIGGERS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001066.html
