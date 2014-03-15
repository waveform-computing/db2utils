.. _CREATE_EXCEPTION_TABLE:

================================
CREATE_EXCEPTION_TABLE procedure
================================

Creates an exception table based on the structure of the specified table.

Prototypes
==========

.. code-block:: sql

    CREATE_EXCEPTION_TABLE(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128), DEST_TBSPACE VARCHAR(18))
    CREATE_EXCEPTION_TABLE(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_TABLE VARCHAR(128))
    CREATE_EXCEPTION_TABLE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128), DEST_TBSPACE VARCHAR(18))
    CREATE_EXCEPTION_TABLE(SOURCE_TABLE VARCHAR(128), DEST_TABLE VARCHAR(128))
    CREATE_EXCEPTION_TABLE(SOURCE_TABLE VARCHAR(128))


Description
===========

The CREATE_EXCEPTION_TABLE procedure creates, from a template table (specified
by **SOURCE_SCHEMA** and **SOURCE_TABLE**), another table (named by **DEST_SCHEMA** and
**DEST_TABLE**) designed to hold `LOAD`_ and `SET INTEGRITY`_ exceptions from the
template table. The new table is identical to the template table, but contains
two extra fields: *EXCEPT_MSG* (which stores information about the exception that
occurred when loading or setting the integrity of the table), and *EXCEPT_TS*, a
TIMESTAMP field indicating when the exception the occurred.

The **DEST_TBSPACE** parameter identifies the tablespace used to store the new
table's data. If **DEST_TBSPACE** is omitted it defaults to the tablespace of
the template table.

Of the other parameters, only **SOURCE_TABLE** is mandatory. If **DEST_TABLE**
is not specified it defaults to the value of **SOURCE_TABLE** with a suffix of
``'_EXCEPTIONS'``. If **SOURCE_SCHEMA** and **DEST_SCHEMA** are not specified
they default to the value of the *CURRENT SCHEMA* special register.

.. warning::

    If the specified table already exists, this procedure will replace
    it, potentially losing all its content. If the existing exceptions data is
    important to you, make sure you back it up before executing this procedure.

.. note::

    All authorizations present on the source table will be copied to the
    destination table.

Parameters
==========

SOURCE_SCHEMA
    If provided, specifies the schema containing the template table on which to
    base the design of the new exceptions table. If omitted, defaults to the
    value of the *CURRENT SCHEMA* special register.

SOURCE_TABLE
    Specifies the name of the template table within **SOURCE_SCHEMA**.

DEST_SCHEMA
    If provided, specifies the schema in which the new exceptions table will be
    created. If omitted, defaults to the value of the *CURRENT SCHEMA*
    special register.

DEST_TABLE
    If provided, specifies the name of the new exceptions table. If omitted,
    defaults to the value of **SOURCE_TABLE** with ``'_EXCEPTIONS'`` appended
    to it.

DEST_TBSPACE
    If provided, specifies the tablespace in which to store the physical data
    of the new exceptions table. Defaults to the tablespace containing the
    table specified by **SOURCE_SCHEMA** and **SOURCE_TABLE**.

Examples
========

Create a new exceptions table based on the design of the *FINANCE.LEDGER*
table, called *EXCEPTIONS.LEDGER* in the *EXCEPTSPACE* tablespace, then load
data into the source table, diverting exceptions to the new exceptions table:

.. code-block:: sql

    CALL CREATE_EXCEPTION_TABLE('FINANCE', 'LEDGER', 'EXCEPTIONS', 'LEDGER', 'EXCEPTSPACE');
    LOAD FROM LEDGER.IXF OF IXF REPLACE INTO FINANCE.LEDGER
      FOR EXCEPTION EXCEPTIONS.LEDGER;


Create a new exceptions table based on the *EMPLOYEE* table in the current
schema called *EMPLOYEE_EXCEPTIONS*, in the same tablespace as the source, then
LOAD the source table, and finally run a SET INTEGRITY from the source to the
new exceptions table:

.. code-block:: sql

    CALL CREATE_EXCEPTION_TABLE('EMPLOYEE');
    LOAD FROM EMPLOYEE.IXF OF IXF REPLACE INTO EMPLOYEE;
    SET INTEGRITY FOR EMPLOYEE IMMEDIATE CHECKED
      FOR EXCEPTION IN EMPLOYEE USE EMPLOYEE_EXCEPTIONS;


See Also
========

* `Source code`_
* :ref:`CREATE_EXCEPTION_VIEW`
* `LOAD`_ (built-in command)
* `SET INTEGRITY`_ (built-in statement)
* `Exception tables`_

.. _LOAD: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.admin.cmd.doc/doc/r0008305.html
.. _SET INTEGRITY: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0000998.html
.. _Exception tables: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001111.html
.. _Source code: https://github.com/waveform80/db2utils/blob/master/exceptions.sql#L43
