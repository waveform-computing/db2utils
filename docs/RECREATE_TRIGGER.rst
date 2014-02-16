.. _RECREATE_TRIGGER:

==========================
RECREATE_TRIGGER procedure
==========================

Recreates the specified inoperative trigger from its definition in the system
catalogue.

Prototypes
==========

.. code-block:: sql

    RECREATE_TRIGGER(ASCHEMA VARCHAR(128), ATRIGGER VARCHAR(128))
    RECREATE_TRIGGER(ATRIGGER VARCHAR(128))


Description
===========

RECREATE_TRIGGER is a utility procedure which recreates the specified trigger
using the SQL found in the system catalogue tables. It is useful for quickly
recreating triggers which have been marked inoperative after a change to one or
more of the trigger's dependencies. If ASCHEMA is omitted it defaults to the
current schema.

.. warning::

    The procedure does *not* drop the trigger before recreating it. This guards
    against attempting to recreate an operative trigger (an inoperative trigger
    can be recreated without dropping it first). That said, it will not return
    an error in the case of attempting to recreate an operative trigger; the
    procedure will simply do nothing.

Parameters
==========

ASCHEMA
    If provided, the schema containing the trigger to recreate. If omitted,
    this parameter defaults to the value of the ``CURRENT SCHEMA`` special
    register.
ATRIGGER
    The name of the trigger to recreate.

Examples
========

Recreate the FINANCE.LEDGER_INSERT trigger:

.. code-block:: sql

    CALL RECREATE_TRIGGER('FINANCE', 'LEDGER_INSERT');


Recreate the EMPLOYEE_UPDATE trigger in the current schema:

.. code-block:: sql

    CALL RECREATE_TRIGGER('EMPLOYEE_UPDATE');


See Also
========

* `Source code`_
* :ref:`RECREATE_TRIGGERS`
* `SYSCAT.TRIGGERS`_ (buit-in catalogue view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/evolve.sql#L159
.. _SYSCAT.TRIGGERS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001066.html
