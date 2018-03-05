.. _ROUTINE_NAME:

========================================
ROUTINE_NAME function/procedure/variable
========================================

Brief description of the routine's purpose. Perhaps copy this from the
254-character limited comment in the code.

Prototypes
==========

.. code-block:: sql

    PROTOTYPE1(PARAM1 TYPE1, PARAM2 TYPE2, PARAM3 TYPE3)
    PROTOTYPE2(PARAM1 TYPE1, PARAM2 TYPE2)
    PROTOTYPE3(PARAM1 TYPE1)

    RETURNS TYPE1 -- For scalar functions
    RETURNS TABLE( -- For table functions
      COL1 TYPE1,
      COL2 TYPE2,
      COL3 TYPE3
    )

Description
===========

A more verbose description of the routine. Include as much detail as possible.
Perhaps copy this from the comments in front of a routine in the code. Within
the prose use the following styles for **PARAMETERS**, ``literal values``, and
*OTHER IDENTIFIERS*.

Parameters
==========

PARAM1
  Description of parameter one. Include whether or not the parameter is
  optional.

PARAM2
  Description of parameter two.

PARAM2
  Description of parameter three.

Returns
=======

If the routine is a table function, describe the columns of the table returned.
Delete this section if the routine is a procedure which returns no table, and
has no output parameters or if the routine is a scalar function (in which case
the description should cover what the function returns).

COLUMN1
  Description of column one.

COLUMN2
  Description of column two.

COLUMN3
  Description of column three.

Examples
========

At least two examples of the routine being used in practice. Perhaps copy these
from the test suite, if available.

.. code-block:: sql

    SELECT FOO(BAR) FROM BAZ;

::

    OUTPUT
    OUTPUT
    OUTPUT

See Also
========

* `Source code`_
* :ref:`RELATED`
* routines

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/foo.sql#Lnnn
