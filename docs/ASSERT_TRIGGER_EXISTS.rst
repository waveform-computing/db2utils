.. _ASSERT_TRIGGER_EXISTS:

===============================
ASSERT_TRIGGER_EXISTS procedure
===============================

Raises an assertion error if the specified trigger doesn't exist.

Prototypes
==========

.. code-block:: sql

    ASSERT_TRIGGER_EXISTS(ASCHEMA VARCHAR(128), ATRIGGER VARCHAR(128))
    ASSERT_TRIGGER_EXISTS(ATRIGGER VARCHAR(128))

Description
===========

Raises the :ref:`ASSERT_FAILED_STATE` state if the trigger specified by
**ASCHEMA** and **ATRIGGER** does not exist. If not specified, **ASCHEMA**
defaults to the value of the *CURRENT SCHEMA* special register.


Parameters
==========

ASCHEMA
    Specifies the schema containing the trigger to check. If omitted, defaults
    to the value of the *CURRENT SCHEMA* special register.

ATRIGGER
    Specifies the name of the trigger to check.

Examples
========

Test the *UTILS.VACATIONS_INSERT* trigger exists:

.. code-block:: sql

    CALL ASSERT_TRIGGER_EXISTS('UTILS', 'VACATIONS_INSERT');


Test the existence of the trigger *VACATIONS_DELETE* in the current schema:

.. code-block:: sql

    CALL ASSERT_TRIGGER_EXISTS('VACATIONS_DELETE');

::

    SQL0438N  Application raised error or warning with diagnostic text: 
    "DB2INST1.VACATIONS_DELETE                          does not exist".  
    SQLSTATE=90001



See Also
========

* `Source code`_
* :ref:`ASSERT_COLUMN_EXISTS`
* :ref:`ASSERT_TABLE_EXISTS`
* :ref:`ASSERT_ROUTINE_EXISTS`
* :ref:`ASSERT_FAILED_STATE`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/assert.sql#L218

