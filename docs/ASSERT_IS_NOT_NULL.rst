.. _ASSERT_IS_NOT_NULL:

==================================
ASSERT_IS_NOT_NULL scalar function
==================================

Signals :ref:`ASSERT_FAILED_STATE` if A is NULL.

Prototypes
==========

.. code-block:: sql

    ASSERT_IS_NOT_NULL(A INTEGER)
    ASSERT_IS_NOT_NULL(A DOUBLE)
    ASSERT_IS_NOT_NULL(A TIMESTAMP)
    ASSERT_IS_NOT_NULL(A TIME)
    ASSERT_IS_NOT_NULL(A VARCHAR(4000))

    RETURNS INTEGER

Description
===========

Raises the :ref:`ASSERT_FAILED_STATE` state if **A** is NULL.  The function is
overloaded for most common types and generally should not need CASTs for usage.
The return value in the case that the value is not NULL is arbitrary.

Parameters
==========

A
    The value to check for NULL.

Examples
========

Test an obvious tautology:

.. code-block:: sql

    VALUES ASSERT_IS_NOT_NULL(1);

::

    1
    -----------
              0

Test that the :ref:`DATE` function returns NULL on NULL input:

.. code-block:: sql

    VALUES ASSERT_IS_NOT_NULL(DATE(2000, 1, NULL));

::

    1
    -----------
    SQL0438N  Application raised error or warning with diagnostic text: "Value 
    is NULL".  SQLSTATE=90001


See Also
========

* `Source code`_
* :ref:`ASSERT_IS_NULL`
* :ref:`ASSERT_NOT_EQUALS`
* :ref:`ASSERT_EQUALS`
* :ref:`ASSERT_FAILED_STATE`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/assert.sql#L409

