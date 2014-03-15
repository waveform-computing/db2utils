.. _ASSERT_ROUTINE_EXISTS:

===============================
ASSERT_ROUTINE_EXISTS procedure
===============================

Raises an assertion error if the specified function or stored procedure doesn't
exist.

Prototypes
==========

.. code-block:: sql

    ASSERT_ROUTINE_EXISTS(ASCHEMA VARCHAR(128), AROUTINE VARCHAR(128))
    ASSERT_ROUTINE_EXISTS(AROUTINE VARCHAR(128))

Description
===========

Raises the :ref:`ASSERT_FAILED_STATE` state if the function or stored procedure
specified by **ASCHEMA** and **AROUTINE** does not exist. If not specified,
**ASCHEMA** defaults to the value of the *CURRENT SCHEMA* special register.


Parameters
==========

ASCHEMA
    Specifies the schema containing the routine to check. If omitted, defaults
    to the value of the *CURRENT SCHEMA* special register.

ATRIGGER
    Specifies the name of the routine to check.

Examples
========

Test the *UTILS.DATE* function exists:

.. code-block:: sql

    CALL ASSERT_ROUTINE_EXISTS('UTILS', 'DATE');


Test the existence of the routine *FOO* in the current schema:

.. code-block:: sql

    CALL ASSERT_ROUTINE_EXISTS('FOO');

::

    SQL0438N  Application raised error or warning with diagnostic text: 
    "DB2INST1.FOO                                       does not exist".  
    SQLSTATE=90001


See Also
========

* `Source code`_
* :ref:`ASSERT_COLUMN_EXISTS`
* :ref:`ASSERT_TABLE_EXISTS`
* :ref:`ASSERT_ROUTINE_EXISTS`
* :ref:`ASSERT_FAILED_STATE`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/assert.sql#L266

