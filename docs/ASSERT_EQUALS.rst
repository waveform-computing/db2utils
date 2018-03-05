.. _ASSERT_EQUALS:

=============================
ASSERT_EQUALS scalar function
=============================

Signals :ref:`ASSERT_FAILED_STATE` if A does not equal B.

Prototypes
==========

.. code-block:: sql

    ASSERT_EQUALS(A INTEGER, B INTEGER)
    ASSERT_EQUALS(A DOUBLE, B DOUBLE)
    ASSERT_EQUALS(A TIMESTAMP, B TIMESTAMP)
    ASSERT_EQUALS(A TIME, B TIME)
    ASSERT_EQUALS(A VARCHAR(4000), B VARCHAR(4000))

    RETURNS INTEGER

Description
===========

Raises the :ref:`ASSERT_FAILED_STATE` state if **A** does not equal **B**.  The
function is overloaded for most common types and generally should not need
CASTs for usage. The return value in the case that the values are equal is
arbitrary.

Parameters
==========

A
    The first value to compare
B
    The value to compare to A

Examples
========

Test that TIMESTAMP is constant within an expression:

.. code-block:: sql

    VALUES ASSERT_EQUALS(CURRENT TIMESTAMP, CURRENT TIMESTAMP);

::

    1
    -----------
              0


Test an obvious failure:

.. code-block:: sql

    VALUES ASSERT_EQUALS(1, 2);

::

    1
    -----------
    SQL0438N  Application raised error or warning with diagnostic text: "1 does 
    not equal 2".  SQLSTATE=90001


See Also
========

* `Source code`_
* :ref:`ASSERT_NOT_EQUALS`
* :ref:`ASSERT_IS_NULL`
* :ref:`ASSERT_IS_NOT_NULL`
* :ref:`ASSERT_FAILED_STATE`

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/assert.sql#L502
