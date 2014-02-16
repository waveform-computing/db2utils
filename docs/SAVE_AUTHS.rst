.. _SAVE_AUTHS:

====================
SAVE_AUTHS procedure
====================

Saves the authorizations of all relations in the specified schema for later restoration with the :ref:`RESTORE_AUTHS` procedure.

Prototypes
==========

.. code-block:: sql

    SAVE_AUTHS(ASCHEMA VARCHAR(128))
    SAVE_AUTHS()


Description
===========

SAVE_AUTHS is a utility procedure which copies the authorization settings for all tables in the specified schema. If no schema is specified the current schema is used. Essentially this is equivalent to running :ref:`SAVE_AUTH` for every table in a schema.

Parameters
==========

ASCHEMA
    The name of the schema containing the tables for which to save authorziation settings. If this parameter is omitted the value of the CURRENT SCHEMA special register will be used instead.

Examples
========

Save all the authorization information from the tables in the FINANCE_DEV schema, do something arbitrary to the schema and restore the authorizations again:

.. code-block:: sql

    SET SCHEMA FINANCE_DEV;
    CALL SAVE_AUTHS();
    -- Do something arbitrary to the schema (e.g. run a script to manipulate its structure)
    CALL RESTORE_AUTHS();


**Advanced usage:** Copy the authorizations from the FINANCE_DEV schema to the FINANCE schema by changing the content of the SAVED_AUTH table (this is the table in which :ref:`SAVE_AUTH` temporarily stores authorizations; it has exactly the same structure as SYSCAT.TABAUTH):

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
* :ref:`RESTORE_AUTH`
* :ref:`RESTORE_AUTHS`
* `SYSCAT.TABAUTH`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/auth.sql#L1045
.. _SYSCAT.TABAUTH: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001061.html
