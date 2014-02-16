.. _DISABLE_TRIGGER:

=========================
DISABLE_TRIGGER procedure
=========================

Disables the specified trigger by saving its definition to a table and dropping
it.

Prototypes
==========

.. code-block:: sql

    DISABLE_TRIGGER(ASCHEMA VARCHAR(128), ATRIGGER VARCHAR(128))
    DISABLE_TRIGGER(ATRIGGER VARCHAR(128))


Description
===========

Drops a trigger after storing its definition in the DISABLED_TRIGGERS table for
later "revival" with :ref:`ENABLE_TRIGGER`. The trigger must be operative (if
it is not, recreate it with the :ref:`RECREATE_TRIGGER` procedure above before
calling DISABLE_TRIGGER.

Parameters
==========

ASCHEMA
    If provided, the schema containing the trigger to disable. If omitted,
    defaults to the value of the ``CURRENT SCHEMA`` special register.
ATRIGGER
    The name of the trigger to disable.

Examples
========

Disable the FINANCE.LEDGER_INSERT trigger:

.. code-block:: sql

    CALL DISABLE_TRIGGER('FINANCE', 'LEDGER_INSERT');


Recreate then disable the EMPLOYEE_UPDATE trigger in the current schema:

.. code-block:: sql

    CALL RECREATE_TRIGGER('EMPLOYEE_UPDATE');
    CALL DISABLE_TRIGGER('EMPLOYEE_UPDATE');


See Also
========

* `Source code`_
* :ref:`ENABLE_TRIGGER`
* :ref:`RECREATE_TRIGGER`
* :ref:`DISABLE_TRIGGERS`
* `SYSCAT.TRIGGERS`_ (built-in catalogue table)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/toggle_triggers.sql#L61
.. _SYSCAT.TRIGGERS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001066.html
