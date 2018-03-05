.. _ASSERT_SIGNALS:

========================
ASSERT_SIGNALS procedure
========================

Signals :ref:`ASSERT_FAILED_STATE` if the execution of **SQL** doesn't signal
SQLSTATE **STATE**, or signals a different SQLSTATE.

Prototypes
==========

.. code-block:: sql

    ASSERT_SIGNALS(STATE CHAR(5), SQL CLOB(2M))

Description
===========

Raises the :ref:`ASSERT_FAILED_STATE` if executing **SQL** does NOT raise
SQLSTATE **STATE**. **SQL** must be capable of being executed by EXECUTE
IMMEDIATE, i.e. no queries or SIGNAL calls.

Parameters
==========

STATE
  The SQLSTATE that is expected to be raised by executing the content of the
  **SQL** parameter.

SQL
  The SQL statement to execute.

Examples
========

Attempt to drop the non-existent table FOO, and confirm that the operation
raises SQLSTATE 42704:

.. code-block:: sql

    CALL ASSERT_SIGNALS('42704', 'DROP TABLE FOO');

Raise the :ref:`ASSERT_FAILED_STATE` by attempting to assert that the same
SQLSTATE is raised by simply querying the current date:

.. code-block:: sql

    CALL ASSERT_SIGNALS('42704', 'VALUES CURRENT DATE');

::

    SQL0438N  Application raised error or warning with diagnostic text: "VALUES 
    CURRENT DATE  signalled SQLSTATE 00000 instead of 42704".  SQLSTATE=90001

See Also
========

* `Source code`_

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/assert.sql#L77

