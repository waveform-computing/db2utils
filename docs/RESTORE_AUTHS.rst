.. _RESTORE_AUTHS:

=======================
RESTORE_AUTHS procedure
=======================

Restores the authorizations of all relations in the specified schema that were
previously saved with :ref:`SAVE_AUTHS`

Prototypes
==========

.. code-block:: sql

    RESTORE_AUTHS(ASCHEMA VARCHAR(128))
    RESTORE_AUTHS()


Description
===========

RESTORE_AUTHS is a utility procedure which restores the authorization settings
(previously saved with :ref:`SAVE_AUTHS`) for all tables in the specified
schema. If no schema is specified, the current schema is used.

.. warning::

    The procedure only attempts to restore settings for those tables or views
    which currently exist, and for which settings were previously saved. If you
    use :ref:`SAVE_AUTHS` on a schema, drop several objects from the schema and
    then call :ref:`RESTORE_AUTHS` on that schema, the procedure will succeed
    with no error, although several authorization settings have not been
    restored.  Furthermore, any settings associated with the specified schema
    that are not restored are removed from store used by :ref:`SAVE_AUTHS` (the
    SAVED_AUTH table in the schema containing the procedures).

Parameters
==========

ASCHEMA
    The name of the schema containing the tables for which to restore
    authorziation settings. If this parameter is omitted the value of the
    CURRENT SCHEMA special register will be used instead.

Examples
========

Save all the authorization information from the tables in the FINANCE_DEV
schema, do something arbitrary to the schema and restore the authorizations
again:

.. code-block:: sql

    SET SCHEMA FINANCE_DEV;
    CALL SAVE_AUTHS();
    -- Do something arbitrary to the schema (e.g. run a script to manipulate its structure)
    CALL RESTORE_AUTHS();


**Advanced usage:** Copy the authorizations from the FINANCE_DEV schema to the
FINANCE schema by changing the content of the SAVED_AUTH table (this is the
table in which :ref:`SAVE_AUTH` temporarily stores authorizations; it has
exactly the same structure as SYSCAT.TABAUTH):

.. code-block:: sql

    CALL SAVE_AUTHS('FINANCE_DEV');
    UPDATE UTILS.SAVED_AUTH
        SET TABSCHEMA = 'FINANCE'
        WHERE TABSCHEMA = 'FINANCE_DEV';
    CALL RESTORE_AUTHS('FINANCE');


See Also
========

* `Source code`_
* :ref:`SAVE_AUTH`
* :ref:`SAVE_AUTHS`
* :ref:`RESTORE_AUTH`
* `SYSCAT.TABAUTH`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/auth.sql#L1258
.. _SYSCAT.TABAUTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001061.html
