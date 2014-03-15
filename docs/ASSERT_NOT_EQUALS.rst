.. _ASSERT_NOT_EQUALS:

=================================
ASSERT_NOT_EQUALS scalar function
=================================

Signals :ref:`ASSERT_FAILED_STATE` if A equals B.

Prototypes
==========

.. code-block:: sql

    ASSERT_NOT_EQUALS(A INTEGER, B INTEGER)
    ASSERT_NOT_EQUALS(A DOUBLE, B DOUBLE)
    ASSERT_NOT_EQUALS(A TIMESTAMP, B TIMESTAMP)
    ASSERT_NOT_EQUALS(A TIME, B TIME)
    ASSERT_NOT_EQUALS(A VARCHAR(4000), B VARCHAR(4000))

    RETURNS INTEGER

Description
===========

Raises the :ref:`ASSERT_FAILED_STATE` state if **A** equals **B**.  The
function is overloaded for most common types and generally should not need
CASTs for usage. The return value in the case that the values aren't equal is
arbitrary.

Parameters
==========

A
    The first value to compare
B
    The value to compare to A

Examples
========

Test that the LEFT function works:

.. code-block:: sql

    VALUES ASSERT_NOT_EQUALS('AAA', LEFT('AAA', 1));

::

    1
    -----------
              0


Test an obvious failure:

.. code-block:: sql

    VALUES ASSERT_NOT_EQUALS(1, 1);

::

    1
    -----------
    SQL0438N  Application raised error or warning with diagnostic text: "
    Values are both 1".  SQLSTATE=90001


See Also
========

* `Source code`_
* :ref:`ASSERT_EQUALS`
* :ref:`ASSERT_IS_NULL`
* :ref:`ASSERT_IS_NOT_NULL`
* :ref:`ASSERT_FAILED_STATE`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/assert.sql#L601

