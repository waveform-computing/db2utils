.. _SAVE_AUTH:

===================
SAVE_AUTH procedure
===================

Saves the authorizations of the specified relation for later restoration with
the :ref:`RESTORE_AUTH` procedure.

Prototypes
==========

.. code-block:: sql

    SAVE_AUTH(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    SAVE_AUTH(ATABLE VARCHAR(128))


Description
===========

SAVE_AUTH is a utility procedure which copies the authorization settings for
the specified table or view from `SYSCAT.TABAUTH`_ to the SAVED_AUTH table (a
utility table which exists in the same schema as the procedure). These saved
settings can then be restored with the :ref:`RESTORE_AUTH` procedure. These
procedures are primarily intended for use in conjunction with the other schema
evolution functions (like :ref:`RECREATE_VIEWS`).

.. warning::

    Column specific authorizations (stored in `SYSCAT.COLAUTH`_) are NOT
    saved and restored by these procedures.

.. note::

    :ref:`SAVE_AUTH` and :ref:`RESTORE_AUTH` are not used directly by
    :ref:`RECREATE_VIEW` because when a view is marked inoperative, all
    authorization information is immediately wiped from SYSCAT.TABAUTH. Hence,
    there is nothing to restore by the time :ref:`RECREATE_VIEW` is run. You
    must call :ref:`SAVE_AUTH` *before* performing the operation that will
    invalidate the view, and :ref:`RESTORE_AUTH` *after* running
    :ref:`RECREATE_VIEW`.  Alternatively, you may wish to use the
    :ref:`SAVE_VIEW` and :ref:`RESTORE_VIEW` procedures instead, which rely on
    :ref:`SAVE_AUTH` and :ref:`RESTORE_AUTH` implicitly.

Parameters
==========

ASCHEMA
    The name of the schema containing the table for which authorizations are to
    be saved. If this parameter is omitted, it defaults to the value of the
    CURRENT SCHEMA special register.
ATABLE
    The name of the table within ASCHEMA for which authorizations are to be
    saved.

Examples
========

Save the authorizations associated with the FINANCE.LEDGER table, drop the
table, recreate it with a definition derived from another table, then restore
the authorizations:

.. code-block:: sql

    SET SCHEMA FINANCE;
    CALL SAVE_AUTH('LEDGER');
    DROP TABLE LEDGER;
    CREATE TABLE LEDGER LIKE LEDGER_TEMPLATE;
    CALL RESTORE_AUTH('LEDGER');


**Advanced usage:** Copy the authorizations associated with FINANCE.SALES to
FINANCE.SALES_HISTORY by changing the content of the SAVED_AUTH table (which is
structured identically to the SYSCAT.TABAUTH table) between calls to
:ref:`SAVE_AUTH` and :ref:`RESTORE_AUTH`:

.. code-block:: sql

    SET SCHEMA FINANCE;
    CALL SAVE_AUTH('SALES');
    UPDATE UTILS.SAVED_AUTH
        SET TABNAME = 'SALES_HISTORY'
        WHERE TABNAME = 'SALES'
        AND TABSCHEMA = CURRENT SCHEMA;
    CALL RESTORE_AUTH('SALES_HISTORY');


See Also
========

* `Source code`_
* :ref:`SAVE_AUTHS`
* :ref:`SAVE_VIEW`
* :ref:`RESTORE_AUTH`
* :ref:`RESTORE_AUTHS`
* :ref:`RESTORE_VIEW`
* `SYSCAT.TABAUTH`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/auth.sql#L959
.. _SYSCAT.TABAUTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001061.html
.. _SYSCAT.COLAUTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001035.html
