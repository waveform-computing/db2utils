.. _QUOTE_IDENTIFIER:

================================
QUOTE_IDENTIFIER scalar function
================================

If **AIDENT** is an identifier which requires quoting, returns **AIDENT**
surrounded by double quotes with all contained double quotes doubled. Useful
when constructing SQL for EXECUTE IMMEDIATE within a procedure.

Prototypes
==========

.. code-block:: sql

    QUOTE_IDENTIFIER(AIDENT(VARCHAR(128))

    RETURNS VARCHAR(258)


Description
===========

Returns **AIDENT** surrounded by double quotes if **AIDENT** contains any
characters which cannot appear in an identifier, as defined by the DB2 SQL
dialect.  Specifically this function is intended for correctly quoting SQL
identifiers in generated SQL. Hence if **AIDENT** contains any lower-case,
whitespace or symbolic characters, or begins with a numeral or underscore, it
is returned quoted. If **AIDENT** contains no such characters it is returned
verbatim.

Parameters
==========

AIDENT
    The identifier to quote (if necessary).

Examples
========

Quote a simple identifier:

.. code-block:: sql

    VALUES QUOTE_IDENTIFIER('MY_TABLE')

::

    1
    ----------...
    MY_TABLE


Quote an identifier containing characters that require quoting:

.. code-block:: sql

    VALUES QUOTE_IDENTIFIER('MyTable')

::

    1
    -----------...
    "MyTable"


Quote an identifier containing quotation marks:

.. code-block:: sql

    VALUES QUOTE_IDENTIFIER('My "Table"')


::

    1
    -----------------...
    "My ""Table"""


See Also
========

* `Source code`_
* :ref:`QUOTE_STRING`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/sql.sql#L100
