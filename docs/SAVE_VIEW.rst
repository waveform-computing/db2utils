.. _SAVE_VIEW:

===================
SAVE_VIEW procedure
===================

Saves the authorizations and definition of the specified view for later
restoration with :ref:`RESTORE_VIEW`.

Prototypes
==========

.. code-block:: sql

    SAVE_VIEW(ASCHEMA VARCHAR(128), AVIEW VARCHAR(128))
    SAVE_VIEW(AVIEW VARCHAR(128))


Description
===========

SAVE_VIEW is a utility procedure which saves the definition of the specified
view to :ref:`SAVED_VIEWS`. This saved definition can then be restored with the
:ref:`RESTORE_VIEW` procedure. SAVE_VIEW and RESTORE_VIEW also implicitly call
:ref:`SAVE_AUTH` and :ref:`RESTORE_AUTH`  to preserve the authorizations of the
view. This is in contrast to inoperative views recreated with
:ref:`RECREATE_VIEW` which lose authorization information.

.. note::

    This procedure is effectively redundant as of DB2 9.7 due to the new
    deferred revalidation functionality introduced in that version.

Parameters
==========

ASCHEMA
    If provided, the schema containing the view to save. If omitted, this
    parameter defaults to the value of the *CURRENT SCHEMA* special register.

AVIEW
    The name of the view to save.

Examples
========

Save the definition of the *FINANCE.LEDGER_CHANGES* view:

.. code-block:: sql

    CALL SAVE_VIEW('FINANCE', 'LEDGER_CHANGES');


Save the definition of the *EMPLOYEE_CHANGES* view in the current schema:

.. code-block:: sql

    CALL SAVE_VIEW('EMPLOYEE_CHANGES');


See Also
========

* `Source code`_
* :ref:`RESTORE_VIEW`
* :ref:`SAVE_VIEWS`
* :ref:`SAVE_AUTH`
* `SYSCAT.VIEWS`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/evolve.sql#L339
.. _SYSCAT.VIEWS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001068.html
