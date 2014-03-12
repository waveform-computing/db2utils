.. _CREATE_HISTORY_TABLE:

==============================
CREATE_HISTORY_TABLE procedure
==============================

Creates a temporal history table based on the structure of the specified table.

Prototypes
==========

.. code-block:: sql

    CREATE_HISTORY_TABLE(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128), DEST_TBSPACE VARCHAR(18), RESOLUTION VARCHAR(11))
    CREATE_HISTORY_TABLE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128), DEST_TBSPACE VARCHAR(18), RESOLUTION VARCHAR(11))
    CREATE_HISTORY_TABLE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128), RESOLUTION VARCHAR(11))
    CREATE_HISTORY_TABLE(SOURCE_TABLE VARCHAR(128), RESOLUTION VARCHAR(11))


Description
===========

The CREATE_HISTORY_TABLE procedure creates, from a template table specified by
**SOURCE_SCHEMA** and **SOURCE_TABLE**, another table named by **DEST_SCHEMA**
and **DEST_TABLE** designed to hold a representation of the source table's
content over time.  Specifically, the destination table has the same structure
as source table, but with two additional columns named *EFFECTIVE_time_period*
and *EXPIRY_time_period* (where *time_period* is determined by the
**RESOLUTION** parameter), which occur before all other "original" columns. The
primary key of the source table, in combination with *EFFECTIVE_time_period*
will form the primary key of the destination table, and a unique index
involving the primary key and the *EXPIRY_time_period* column will also be
created as this provides better performance of the triggers used to maintain
the destination table.

The **DEST_TBSPACE** parameter identifies the tablespace used to store the new
table's data. If **DEST_TBSPACE** is not specified, it defaults to the
tablespace of the source table. If **DEST_TABLE** is not specified it defaults
to the value of **SOURCE_TABLE** with ``'_HISTORY'`` as a suffix. If
**DEST_SCHEMA** and **SOURCE_SCHEMA** are not specified they default to the
current schema.

The **RESOLUTION** parameter determines the smallest unit of time that a
history record can cover. See :ref:`CREATE_HISTORY_TRIGGERS` for a list of the
possible values.

All SELECT and CONTROL authorities present on the source table will be copied
to the destination table. However, INSERT, UPDATE and DELETE authorities are
excluded as these operations should only ever be performed by the history
maintenance triggers themselves. The compression status of the source table
will be copied to the destination table.

.. warning::

    If the specified table already exists, this procedure will replace it,
    potentially losing all its content. If the existing history data is
    important to you, make sure you back it up before executing this procedure.

.. note::

    This procedure is mostly redundant as of DB2 v10.1 which includes the
    ability to create temporal tables automatically via the ``PERIOD`` element
    combined with ``SYSTEM TIME`` and ``BUSINESS TIME`` specifications.
    However, the DB2 v10.1 implementation does not include the ability to
    create temporal tables with particularly coarse resolutions like ``WEEK``.

Parameters
==========

SOURCE_SCHEMA
    If provided, specifies the schema containing the template table on which to
    base the design of the new history table. If omitted, defaults to the value
    of the *CURRENT SCHEMA* special register.

SOURCE_TABLE
    Specifies the name of the template table within **SOURCE_SCHEMA**.

DEST_SCHEMA
    If provided, specifies the schema in which the new exceptions table will be
    created. If omitted, defaults to the value of the *CURRENT SCHEMA*
    special register.

DEST_TABLE
    If provided, specifies the name of the new exceptions table. If omitted,
    defaults to the value of **SOURCE_TABLE** with ``'_HISTORY'`` appended to
    it.

DEST_TBSPACE
    The name of the tablespace in which the history table should be created.
    If omitted, defaults to the tablespace in which **SOURCE_TABLE** exists.

RESOLUTION
    Specifies the granularity of the history to be stored. See
    :ref:`CREATE_HISTORY_TRIGGERS` for a description of the possible values.

Examples
========

Create a *CORP.CUSTOMERS* table, then create a history table called
*CORP.CUSTOMERS_HISTORY* based upon on the *CORP.CUSTOMERS* table in the
*CORPSPACE* tablespace with DATE resolution. Finally, install the triggers
which will keep the history table up to date with the base table:

.. code-block:: sql

    CREATE TABLE CORP.CUSTOMERS (
      ID         INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      NAME       VARCHAR(100) NOT NULL,
      ADDRESS    VARCHAR(2000) NOT NULL,
      SECTOR     CHAR(2) NOT NULL REFERENCES SECTORS(SECTOR)
    ) IN CORPSPACE COMPRESS YES;
    CALL CREATE_HISTORY_TABLE('CORP', 'CUSTOMERS', 'CORP', 'CUSTOMERS_HISTORY', 'CORPSPACE', 'DAY');
    CALL CREATE_HISTORY_TRIGGERS('CORP', 'CUSTOMERS', 'CORP', 'CUSTOMERS_HISTORY', 'DAY', '');


The same example as above, but eliminating as many optional parameters as
possible:

.. code-block:: sql

    SET SCHEMA CORP;
    CREATE TABLE CUSTOMERS (
      ID         INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      NAME       VARCHAR(100) NOT NULL,
      ADDRESS    VARCHAR(2000) NOT NULL,
      SECTOR     CHAR(2) NOT NULL REFERENCES SECTORS(SECTOR),
    ) IN CORPSPACE COMPRESS YES;
    CALL CREATE_HISTORY_TABLE('CUSTOMERS', 'DAY');
    CALL CREATE_HISTORY_TRIGGERS('CUSTOMERS', 'DAY');


Create a history table on top of an existing populated customers table called
*CORP.CUSTOMERS*. Note that before creating the triggers that link the base
table to the history table, we insert the existing rows from *CORP.CUSTOMERS*
into *CORP.CUSTOMERS_HISTORY* with some appropriate effective and expiry values
(in future a procedure may be provided to perform this step automatically):

.. code-block:: sql

    SET SCHEMA CORP;
    CALL CREATE_HISTORY_TABLE('CUSTOMERS', 'DAY');
    INSERT INTO CUSTOMERS_HISTORY SELECT CURRENT DATE, '9999-12-31', T.* FROM CUSTOMERS T;
    CALL CREATE_HISTORY_TRIGGERS('CUSTOMERS', 'DAY');


See Also
========

* `Source code`_
* :ref:`CREATE_HISTORY_TRIGGERS`
* :ref:`CREATE_HISTORY_CHANGES`
* :ref:`CREATE_HISTORY_SNAPSHOTS`
* `History design usenet post`_
* `CREATE TABLE`_ (built-in command)
* `Time Travel Queries in DB2 v10.1`_

.. _Time Travel Queries in DB2 v10.1: http://pic.dhe.ibm.com/infocenter/db2luw/v10r1/topic/com.ibm.db2.luw.admin.dbobj.doc/doc/c0058476.html
.. _Source code: https://github.com/waveform80/db2utils/blob/master/history.sql#L696
.. _History design usenet post: http://groups.google.com/group/comp.databases.ibm-db2/msg/e84aeb1f6ac87e6c
.. _CREATE TABLE: http://pic.dhe.ibm.com/infocenter/db2luw/v10r1/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000927.html
