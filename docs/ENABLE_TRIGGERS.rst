.. _ENABLE_TRIGGERS:

=========================
ENABLE_TRIGGERS procedure
=========================

Enables all triggers associated with a specified table.

Prototypes
==========

.. code-block:: sql

    ENABLE_TRIGGERS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    ENABLE_TRIGGERS(ATABLE VARCHAR(128))


Description
===========

Enables all the disabled triggers associated with a particular table. Note that
this does not affect inactive triggers which are still attached to the table,
just those triggers that have been disabled with :ref:`DISABLE_TRIGGER` or
:ref:`DISABLE_TRIGGERS`. To reactivate inactive triggers, see
:ref:`RECREATE_TRIGGER` and :ref:`RECREATE_TRIGGERS`.

Parameters
==========

ASCHEMA
    If provided, the schema containing the table for which to enable triggers.
    If omitted, defaults to the value of the ``CURRENT SCHEMA`` special
    register.
ATABLE
    The name of the table to enable all disabled triggers for.

Examples
========

Enable all disabled triggers on the FINANCE.LEDGER table:

.. code-block:: sql

    CALL ENABLE_TRIGGERS('FINANCE', 'LEDGER');


Enable the disabled triggers for the EMPLOYEE table in the current schema:

.. code-block:: sql

    CALL ENABLE_TRIGGERS('EMPLOYEE');


See Also
========

* `Source code`_
* :ref:`DISABLE_TRIGGERS`
* :ref:`RECREATE_TRIGGER`
* :ref:`ENABLE_TRIGGER`
* `SYSCAT.TRIGGERS`_ (built-in catalogue table)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/toggle_triggers.sql#L258
.. _SYSCAT.TRIGGERS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001066.html
