.. _AUTO_DELETE:

=====================
AUTO_DELETE procedure
=====================

Automatically removes data from **DEST_TABLE** that doesn't exist in
**SOURCE_TABLE**, based on **DEST_KEY**.

Prototypes
==========

.. code-block:: sql

    AUTO_DELETE(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128), DEST_KEY VARCHAR(128))
    AUTO_DELETE(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128))
    AUTO_DELETE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128), DEST_KEY VARCHAR(128))
    AUTO_DELETE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128))

Description
===========

The AUTO_DELETE procedure deletes rows from **DEST_TABLE** that do not exist in
**SOURCE_TABLE**. This procedure is intended to be used after the
:ref:`AUTO_MERGE` procedure has been used to upsert from the source to the
destination.

The **DEST_KEY** parameter specifies the name of the unique key to use for
identifying rows in the destination table. If specified, it must be the name of
a unique key or primary key which covers columns which exist in both the source
and destination tables. If omitted, it defaults to the name of the primary key
of the destination table.

If **SOURCE_SCHEMA** and **DEST_SCHEMA** are not specified they default to the
current schema.

Parameters
==========

SOURCE_SCHEMA
  If provided, specifies the schema containing **SOURCE_TABLE**. If omitted,
  defaults to the value of the ``CURRENT SCHEMA`` special register.

SOURCE_TABLE
  Specifies the name of the table within **SOURCE_SCHEMA** to read for the list
  of rows to be preserved.

DEST_SCHEMA
  If provided, specifies the schema containing **DEST_TABLE**. If omitted,
  defaults to the value of the ``CURRENT SCHEMA`` special register.

DEST_TABLE
  Specifies the name of the table within **DEST_SCHEMA** from which data will
  be deleted. This table *must* have at least one unique key (or a primary
  key).

DEST_KEY
  If provided, specifies the name of the unique key in the destination table
  which will be joined to the equivalently named fields in the source table to
  determine which rows to delete. If omitted, defaults to the name of the
  primary key of the destination table.

Examples
========

Merge new content from EMP_SOURCE into the EMPLOYEES table, matching rows via
the primary key of EMPLOYEES, then delete rows in EMPLOYEES that no longer
exist in EMP_SOURCE:

.. code-block:: sql

    CALL AUTO_MERGE('EMP_SOURCE', 'EMPLOYEES');
    CALL AUTO_DELETE('EMP_SOURCE', 'EMPLOYEES');

Delete content from IW.CONTRACTS that no longer exists in STAGING.CONTRACTS,
using a specific unique key for matching rows:

.. code-block:: sql

    CALL AUTO_DELETE('STAGING', 'CONTRACTS', 'IW', 'CONTRACTS', 'CONTRACTS_KEY');

See Also
========

* `Source code`_
* :ref:`AUTO_MERGE`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/merge.sql#L378
