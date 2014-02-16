.. _RESTORE_VIEW:

======================
RESTORE_VIEW procedure
======================

Restores the specified view which was previously saved with :ref:`SAVE_VIEW`.

Prototypes
==========

.. code-block:: sql

    RESTORE_VIEW(ASCHEMA VARCHAR(128), AVIEW VARCHAR(128))
    RESTORE_VIEW(AVIEW VARCHAR(128))


Description
===========

RESTORE_VIEW is a utility procedure which restores the specified view using the SQL found in the SAVED_VIEWS table, which is populated initially by a call to :ref:`SAVE_VIEW` or :ref:`SAVE_VIEWS`. It also implicitly calls :ref:`RESTORE_AUTH` to ensure that authorizations are not lost. This is the primary difference between using :ref:`SAVE_VIEW` and RESTORE_VIEW, and using DB2's inoperative view mechanism with the :ref:`RECREATE_VIEW` procedure. Another use of these procedures is in recreating views which need to be dropped surrounding the update of a UDF.

**Note:** This procedure is effectively redundant as of DB2 9.7 due to the new deferred revalidation functionality introduced in that version.

Parameters
==========

ASCHEMA
    If provided, the schema containing the view to restore. If omitted, this parameter defaults to the value of the ``CURRENT SCHEMA`` special register.
AVIEW
    The name of the view to restore.

Examples
========

Restore the definition of the FINANCE.LEDGER_CHANGES view:

.. code-block:: sql

    CALL RESTORE_VIEW('FINANCE', 'LEDGER_CHANGES');


Restore the definition of the EMPLOYEE_CHANGES view in the current schema:

.. code-block:: sql

    CALL RESTORE_VIEW('EMPLOYEE_CHANGES');


See Also
========

* `Source code`_
* :ref:`SAVE_VIEW`
* :ref:`RESTORE_VIEWS`
* :ref:`RESTORE_AUTH`
* `SYSCAT.VIEWS`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/evolve.sql#L448
.. _SYSCAT.VIEWS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001068.html
