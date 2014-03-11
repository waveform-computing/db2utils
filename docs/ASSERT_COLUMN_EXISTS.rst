.. _ASSERT_COLUMN_EXISTS:

==============================
ASSERT_COLUMN_EXISTS procedure
==============================

Raises an assertion error if the specified column doesn't exist.

Prototypes
==========

.. code-block:: sql

    ASSERT_COLUMN_EXISTS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128), ACOLNAME VARCHAR(128))
    ASSERT_COLUMN_EXISTS(ATABLE VARCHAR(128), ACOLNAME VARCHAR(128))

Description
===========

Raises the :ref:`ASSERT_FAILED_STATE` state if **ACOLNAME** does not exist in
the table specified by **ASCHEMA** and **ATABLE**. If not specified,
**ASCHEMA** defaults to the value of the *CURRENT SCHEMA* special register.


Parameters
==========

ASCHEMA
    Specifies the schema containing the table to check. If omitted, defaults to
    the value of the *CURRENT SCHEMA* special register.
ATABLE
    Specifies the name of the table to check.
ACOLNAME
    Specifies the name of the column to test for existence.

Examples
========

Test the TABNAME column exists in the SYSCAT.TABLES view:

.. code-block:: sql

    CALL ASSERT_COLUMN_EXISTS('SYSCAT', 'TABLES', 'TABNAME');


Test the existence of a made-up column in the SYSCAT.TABLES view:

.. code-block:: sql

    CALL ASSERT_COLUMN_EXISTS('SYSCAT', 'TABLES', 'FOO');

::

    SQL0438N  Application raised error or warning with diagnostic text: "FOO
    does not exist in SYSCAT.TABLES                 ".  SQLSTATE=90001


See Also
========

* `Source code`_
* :ref:`ASSERT_TABLE_EXISTS`
* :ref:`ASSERT_FAILED_STATE`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/assert.sql#L165
