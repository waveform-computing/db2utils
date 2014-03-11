.. _AUTO_INSERT:

=====================
AUTO_INSERT procedure
=====================

Automatically inserts data into **DEST_TABLE** from **SOURCE_TABLE**.

Prototypes
==========

.. code-block:: sql

    AUTO_INSERT(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128))
    AUTO_INSERT(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128))

Description
===========

The AUTO_INSERT procedure inserts all data from **SOURCE_TABLE** into
**DEST_TABLE** by means of an automatically generated INSERT statement covering
all columns common to both tables.

If **SOURCE_SCHEMA** and **DEST_SCHEMA** are not specified they default to the
current schema.

Only columns common to both the destination table and the source table will be
included in the generated statement. Destination columns must be updateable
(they cannot be defined as ``GENERATED ALWAYS``), and the executing user must
have INSERT privileges on the destination table.

Parameters
==========

SOURCE_SCHEMA
  If provided, specifies the schema containing **SOURCE_TABLE**. If omitted,
  defaults to the value of the ``CURRENT SCHEMA`` special register.

SOURCE_TABLE
  Specifies the name of the table within **SOURCE_SCHEMA** from which to read
  data.

DEST_SCHEMA
  If provided, specifies the schema containing **DEST_TABLE**. If omitted,
  defaults to the value of the ``CURRENT SCHEMA`` special register.

DEST_TABLE
  Specifies the name of the table within **DEST_SCHEMA** into which data will
  be copied.

Examples
========

Insert all content from NEW_EMP into EMPLOYEES:

.. code-block:: sql

    CALL AUTO_INSERT('NEW_EMP', 'EMPLOYEES');

Replace all content in IW.CONTRACTS with content from STAGING.CONTRACTS:

.. code-block:: sql

    TRUNCATE IW.CONTRACTS
        REUSE STORAGE
        RESTRICT WHEN DELETE TRIGGERS
        IMMEDIATE;
    CALL AUTO_INSERT('STAGING', 'CONTRACTS', 'IW', 'CONTRACTS');

See Also
========

* `Source code`_
* :ref:`AUTO_MERGE`
* :ref:`AUTO_DELETE`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/merge.sql#L329

