.. _DROP_SCHEMA:

=====================
DROP_SCHEMA procedure
=====================

Drops ASCHEMA and all objects within it.

Prototypes
==========

.. code-block:: sql

    DROP_SCHEMA(ASCHEMA VARCHAR(128))


Description
===========

DROP_SCHEMA is a utility procedure which drops all objects (tables, views,
triggers, sequences, aliases, etc.) in a schema and then drops the schema. It
was originally intended to make destruction of user-owned schemas easier (in
the event that a user no longer required access) but can also be used to make
writing upgrade scripts easier.

.. note::

    This procedure is effectively redundant since DB2 9.5 which includes
    the built-in procedure `ADMIN_DROP_SCHEMA`_, albeit with a somewhat more
    complicated calling convention.

Parameters
==========

ASCHEMA
    The name of the schema to drop.

Examples
========

Drop the FRED schema and all objects within it:

.. code-block:: sql

    CALL DROP_SCHEMA('FRED');


Drop all schemas which start with the characters TEST:

.. code-block:: sql

    BEGIN ATOMIC
      FOR T AS
        SELECT SCHEMANAME
        FROM SYSCAT.SCHEMATA
        WHERE SCHEMANAME LIKE 'TEST%'
      DO
        CALL DROP_SCHEMA(T.SCHEMANAME);
      END FOR;
    END@


See Also
========

* `Source code`_
* `ADMIN_DROP_SCHEMA`_ (built-in procedure)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/drop_schema.sql#L23
.. _ADMIN_DROP_SCHEMA: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.rtn.doc/doc/r0022036.html
