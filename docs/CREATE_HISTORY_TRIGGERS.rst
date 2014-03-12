.. _CREATE_HISTORY_TRIGGERS:

=================================
CREATE_HISTORY_TRIGGERS procedure
=================================

Creates the triggers to link the specified table to its corresponding history
table.

Prototypes
==========

.. code-block:: sql

    CREATE_HISTORY_TRIGGERS(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128), RESOLUTION VARCHAR(11), OFFSET VARCHAR(100))
    CREATE_HISTORY_TRIGGERS(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128), RESOLUTION VARCHAR(11), OFFSET VARCHAR(100))
    CREATE_HISTORY_TRIGGERS(SOURCE_TABLE VARCHAR(128), RESOLUTION VARCHAR(11), OFFSET VARCHAR(100))
    CREATE_HISTORY_TRIGGERS(SOURCE_TABLE VARCHAR(128), RESOLUTION VARCHAR(11))


Description
===========

The CREATE_HISTORY_TRIGGERS procedure creates several trigger linking the
specified source table to the destination table which is assumed to have a
structure compatible with the result of running :ref:`CREATE_HISTORY_TABLE`,
i.e. two extra columns called *EFFECTIVE_time_period* and *EXPIRY_time_period*.

If **DEST_TABLE** is not specified it defaults to the value of **SOURCE_TABLE**
with ``'_HISTORY'`` as a suffix. If **DEST_SCHEMA** and **SOURCE_SCHEMA** are
not specified they default to the current schema.

The **RESOLUTION** parameter specifies the smallest unit of time that a history
entry can cover. This is effectively used to quantize the history. The value
given for the **RESOLUTION** parameter should match the value given as the
**RESOLUTION** parameter to :ref:`CREATE_HISTORY_TABLE`. The values which can
be specified are as follows:

+-------------------+--------------------------------------------------------------+
| Value             | Meaning                                                      |
+===================+==============================================================+
| ``'MICROSECOND'`` | With this value, the triggers perform no explicit            |
|                   | quantization. Instead, history records are constrained       |
|                   | simply by the resolution of the TIMESTAMP datatype,          |
|                   | currently microseconds.                                      |
+-------------------+--------------------------------------------------------------+
| ``'SECOND'``      | Quantizes history into individual seconds. If multiple       |
|                   | changes occur to the master record within a single second,   |
|                   | only the final state is kept in the history table.           |
+-------------------+--------------------------------------------------------------+
| ``'MINUTE'``      | Quantizes history into individual minutes.                   |
+-------------------+--------------------------------------------------------------+
| ``HOUR'``         | Quantizes history into individual hours.                     |
+-------------------+--------------------------------------------------------------+
| ``'DAY'``         | Quantizes history into individual days. If multiple changes  |
|                   | occur to the master record within a single day, as defined   |
|                   | by the CURRENT DATE special register, only the final state   |
|                   | is kept in the history table.                                |
+-------------------+--------------------------------------------------------------+
| ``'WEEK'``        | Quantizes history into blocks starting on a Sunday and       |
|                   | ending on a Saturday.                                        |
+-------------------+--------------------------------------------------------------+
| ``'WEEK_ISO'``    | Quantizes history into blocks starting on a Monday and       |
|                   | ending on a Sunday.                                          |
+-------------------+--------------------------------------------------------------+
| ``'MONTH'``       | Quantizes history into blocks starting on the 1st of a       |
|                   | month and ending on the last day of the corresponding month. |
+-------------------+--------------------------------------------------------------+
| ``'YEAR'``        | Quantizes history into blocks starting on the 1st of a year  |
|                   | and ending on the last day of the corresponding year.        |
+-------------------+--------------------------------------------------------------+

The **OFFSET** parameter specifies an SQL phrase that will be used to offset
the effective dates of new history records. For example, if the source table is
only updated a week in arrears, then **OFFSET** could be set to ``'- 7 DAYS'``
to cause the effective dates to be accurate. If offset is not specified a blank
string ``''`` (meaning no offset) is used.

.. note::

    This procedure is mostly redundant as of DB2 v10.1 which includes the
    ability to create temporal tables automatically via the ``PERIOD`` element
    combined with ``SYSTEM TIME`` and ``BUSINESS TIME`` specifications.
    However, the DB2 v10.1 implementation does not include the ability to
    create temporal tables with particularly coarse resolutions like
    ``WEEKLY``.

Parameters
==========

SOURCE_SCHEMA
    If provided, the schema of the table on which to define the triggers. If
    omitted, defaults to the value of the *CURRENT SCHEMA* special register.

SOURCE_TABLE
    The name of the table on which to define the triggers.

DEST_SCHEMA
    If provided, the schema of the table which the triggers should write rows
    to. If omitted, defaults to the value of the *CURRENT SCHEMA* special
    register.

DEST_TABLE
    If provided, the name of the table which the triggers should write rows
    into. If omitted, defaults to the value of the **SOURCE_TABLE** parameter
    with ``'_HISTORY'`` appended.

RESOLUTION
    The time period to which the triggers should quantize the history records.
    Should be the same as the resolution specified when creating the history
    table with :ref:`CREATE_HISTORY_TABLE`.

OFFSET
    A string specifying an offset (in the form of a labelled duration) which
    will be applied to the effective dates written by the triggers. If omitted,
    defaults to the empty string ``''`` (meaning no offset is to be applied).

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

Create a history table for an existing *PROJECTS* table. Populate it with the
existing data (and appropriate effective and expiry dates), then create the
history triggers to link the *PROJECTS* table to the *PROJECTS_HISTORY* table,
with a weekly resolution and a 1 week history offset:

.. code-block:: sql

    CALL CREATE_HISTORY_TABLE('PROJECTS', 'WEEK');
    INSERT INTO PROJECTS_HISTORY SELECT WEEKSTART(CURRENT DATE), DATE('9999-12-31'), T.* FROM PROJECTS T;
    CALL CREATE_HISTORY_TRIGGERS('PROJECTS_HISTORY', 'WEEK', '- 7 DAYS');


See Also
========

* `Source code`_
* :ref:`CREATE_HISTORY_TABLE`
* :ref:`CREATE_HISTORY_CHANGES`
* :ref:`CREATE_HISTORY_SNAPSHOTS`
* `History design usenet post`_
* `CREATE TABLE`_ (built-in command)
* `CREATE TRIGGER`_ (built-in command)
* `Time Travel Queries in DB2 v10.1`_

.. _Time Travel Queries in DB2 v10.1: http://pic.dhe.ibm.com/infocenter/db2luw/v10r1/topic/com.ibm.db2.luw.admin.dbobj.doc/doc/c0058476.html
.. _Source code: https://github.com/waveform80/db2utils/blob/master/history.sql#L1278
.. _History design usenet post: http://groups.google.com/group/comp.databases.ibm-db2/msg/e84aeb1f6ac87e6c
.. _CREATE TRIGGER: http://pic.dhe.ibm.com/infocenter/db2luw/v10r1/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000931.html
.. _CREATE TABLE: http://pic.dhe.ibm.com/infocenter/db2luw/v10r1/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000927.html
