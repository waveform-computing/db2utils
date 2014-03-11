.. _AUTO_MERGE:

====================
AUTO_MERGE procedure
====================

Automatically inserts/updates ("upserts") data from **SOURCE_TABLE** into
**DEST_TABLE**, based on **DEST_KEY**.

Prototypes
==========

.. code-block:: sql

    AUTO_MERGE(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128), DEST_KEY VARCHAR(128))
    AUTO_MERGE(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128))
    AUTO_MERGE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128), DEST_KEY VARCHAR(128))
    AUTO_MERGE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128))

Description
===========

The AUTO_MERGE procedure performs an "upsert", or combined insert and update of
all data from **SOURCE_TABLE** into **DEST_TABLE** by means of an automatically
generated MERGE statement.

The **DEST_KEY** parameter specifies the name of the unique key to use for
identifying rows in the destination table. If specified, it must be the name
of a unique key or primary key which covers columns which exist in both the
source and destination tables. If omitted, it defaults to the name of the
primary key of the destination table.

If **SOURCE_SCHEMA** and **DEST_SCHEMA** are not specified they default to the
current schema.

Only columns common to both the destination table and the source table will be
included in the generated statement. Destination columns must be updateable
(they cannot be defined as ``GENERATED ALWAYS``), and the executing user must
have INSERT and UPDATE privileges on the destination table.

Parameters
==========

SOURCE_SCHEMA
  If provided, specifies the schema containing **SOURCE_TABLE**. If omitted,
  defaults to the value of the ``CURRENT SCHEMA`` special register.

SOURCE_TABLE
  Specifies the name of the table within **SOURCE_SCHEMA** from which data will
  be read.

DEST_SCHEMA
  If provided, specifies the schema containing **DEST_TABLE**. If omitted,
  defaults to the value of the ``CURRENT SCHEMA`` special register.

DEST_TABLE
  Specifies the name of the table within **DEST_SCHEMA** into which data will
  be inserted or updated. This table *must* have at least one unique key (or
  a primary key).

DEST_KEY
  If provided, specifies the name of the unique key in the destination table
  which will be joined to the equivalently named fields in the source table to
  determine whether rows are to be inserted or updated. If omitted, defaults to
  the name of the primary key of the destination table.

Examples
========

Merge new content from EMP_SOURCE into the EMPLOYEES table, matching rows via
the primary key of EMPLOYEES, then delete rows in EMPLOYEES that no longer
exist in EMP_SOURCE:


.. code-block:: sql

    CALL AUTO_MERGE('EMP_SOURCE', 'EMPLOYEES');
    CALL AUTO_DELETE('EMP_SOURCE', 'EMPLOYEES');

Merge new content from STAGING.CONTRACTS into IW.CONTRACTS, using a specific
unique key for matching rows:

.. code-block:: sql

    CALL AUTO_MERGE('STAGING', 'CONTRACTS', 'IW', 'CONTRACTS', 'CONTRACTS_KEY');

See Also
========

* `Source code`_
* :ref:`AUTO_DELETE`
* :ref:`AUTO_INSERT`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/merge.sql#L382
