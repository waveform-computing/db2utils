.. _RESTORE_AUTH:

======================
RESTORE_AUTH procedure
======================

Restores authorizations previously saved by :ref:`SAVE_AUTH` for the specified
table.

Prototypes
==========

.. code-block:: sql

    RESTORE_AUTH(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    RESTORE_AUTH(ATABLE VARCHAR(128))


Description
===========

RESTORE_AUTH is a utility procedure which restores the authorization privileges
for a table or view, previously saved by the :ref:`SAVE_AUTH` procedure.

.. warning::

    Privileges may not be precisely restored. Specifically, the grantor in the
    restored privileges may be different to the original grantor if you are not
    the user that originally granted the privileges, or the original privileges
    were granted by the system. Furthermore, column specific authorizations
    (stored in `SYSCAT.COLAUTH`_) are **not** saved and restored by these
    procedures.

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
* :ref:`SAVE_AUTH`
* :ref:`SAVE_AUTHS`
* :ref:`RESTORE_AUTHS`
* `SYSCAT.TABAUTH`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/auth.sql#L1116
.. _SYSCAT.TABAUTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001061.html
.. _SYSCAT.COLAUTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001035.html
