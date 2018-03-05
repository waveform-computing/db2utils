.. _ASSERT_TABLE_EXISTS:

=============================
ASSERT_TABLE_EXISTS procedure
=============================

Raises an assertion error if the specified table doesn't exist.

Prototypes
==========

.. code-block:: sql

    ASSERT_TABLE_EXISTS(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128))
    ASSERT_TABLE_EXISTS(ATABLE VARCHAR(128))

Description
===========

Raises the :ref:`ASSERT_FAILED_STATE` state if the table or view specified by
**ASCHEMA** and **ATABLE** does not exist. If not specified, **ASCHEMA**
defaults to the value of the *CURRENT SCHEMA* special register.


Parameters
==========

ASCHEMA
    Specifies the schema containing the table to check. If omitted, defaults to
    the value of the *CURRENT SCHEMA* special register.

ATABLE
    Specifies the name of the table to check.

Examples
========

Test the SYSCAT.TABLES view exists:

.. code-block:: sql

    CALL ASSERT_TABLE_EXISTS('SYSCAT', 'TABLES');


Test the existence of a made-up table in SYSCAT:

.. code-block:: sql

    CALL ASSERT_TABLE_EXISTS('SYSCAT', 'FOO');

::

    SQL0438N  Application raised error or warning with diagnostic text:
    "SYSCAT.FOO                                         does not exist".
    SQLSTATE=90001



See Also
========

* `Source code`_
* :ref:`ASSERT_COLUMN_EXISTS`
* :ref:`ASSERT_TRIGGER_EXISTS`
* :ref:`ASSERT_ROUTINE_EXISTS`
* :ref:`ASSERT_FAILED_STATE`

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/assert.sql#L115

