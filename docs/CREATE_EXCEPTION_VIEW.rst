.. _CREATE_EXCEPTION_VIEW:

===============================
CREATE_EXCEPTION_VIEW procedure
===============================

Creates a view based on the specified exception table which interprets the
content of the *EXCEPT_MSG* column.

Prototypes
==========

.. code-block:: sql

    CREATE_EXCEPTION_VIEW(SOURCE_SCHEMA VARCHAR(128), SOURCE_TABLE VARCHAR(128), DEST_SCHEMA VARCHAR(128), DEST_VIEW VARCHAR(128))
    CREATE_EXCEPTION_VIEW(SOURCE_TABLE VARCHAR(128), DEST_VIEW VARCHAR(128))
    CREATE_EXCEPTION_VIEW(SOURCE_TABLE VARCHAR(128))


Description
===========

The CREATE_EXCEPTION_VIEW procedure creates a view on top of an exceptions
table (presumably created with :ref:`CREATE_EXCEPTION_TABLE`). The view uses a
recursive common-table-expression to split the large *EXCEPT_MSG* field into
several rows and several columns to allow for easier analysis. Instead of
*EXCEPT_MSG*, the view contains the following exceptions-related fields:

EXCEPT_TYPE
    A CHAR(1) column containing one of the following values:

    * ``'K'`` - check constraint violation
    * ``'F'`` - foreign key violation
    * ``'G'`` - generated column violation
    * ``'I'`` - unique index violation
    * ``'L'`` - datalink load violation
    * ``'D'`` - cascaded deletion violation

EXCEPT_OBJECT
    A VARCHAR(n) column containing the fully qualified name of the object that
    caused the exception (e.g. the name of the check constraint, foreign key,
    column or unique index)

Like :ref:`CREATE_EXCEPTION_TABLE`, this procedure has only one mandatory
parameter: **SOURCE_TABLE**. If **SOURCE_SCHEMA** and **DEST_SCHEMA** are not
specified, they default to the value of the *CURRENT SCHEMA* special register.
If **DEST_VIEW** is not specified, it defaults to the value of **SOURCE_TABLE**
with a ``'_V'`` suffix.

.. note::

    SELECT and CONTROL authorizations are copied from the source table to the
    destination view (INSERT, UPDATE, and DELETE authorizations are ignored).

Parameters
==========

SOURCE_SCHEMA
    If provided, the schema containing the exception table on which to base the
    new view. Defaults to the value of the *CURRENT SCHEMA* special register
    if omitted.

SOURCE_TABLE
    Specifies the exception table on which to base the new view. This table is
    expected to have two columns named *EXCEPT_TS* and *EXCEPT_MSG*.

DEST_SCHEMA
    If provided, the schema in which to create the new view. Defaults to the
    value of the *CURRENT SCHEMA* special register if omitted.

DEST_VIEW
    If provided, the name of the new view. Defaults to **SOURCE_TABLE** with a
    ``'_V'`` suffix if omitted.

Examples
========

Create a view to interpret the content of *EXCEPTIONS.LEDGER* called
*FINANCE.LEDGER_EXCEPTIONS*:

.. code-block:: sql

    CALL CREATE_EXCEPTION_VIEW('EXCEPTIONS', 'LEDGER', 'FINANCE', 'LEDGER_EXCEPTIONS');


Create a view called *EMPLOYEE_EXCEPTIONS_V* based on the *EMPLOYEE_EXCEPTIONS*
table in the current schema:

.. code-block:: sql

    CALL CREATE_EXCEPTION_VIEW('EMPLOYEE_EXCEPTIONS');


See Also
========

* `Source code`_
* :ref:`CREATE_EXCEPTION_TABLE`
* `Exception tables`_

.. _Source code: https://github.com/waveform80/db2utils/blob/master/exceptions.sql#L213
.. _Exception tables: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001111.html
