.. _PCRE_GROUPS:

==========================
PCRE_GROUPS table function
==========================

Searches for regular expression **PATTERN** in **TEXT**, returning a table
detailing all matched groups.

Prototypes
==========

.. code-block:: sql

    PCRE_GROUPS(PATTERN VARCHAR(1000), TEXT VARCHAR(4000))

    RETURNS TABLE(
      GROUP INTEGER,
      POSITION INTEGER,
      CONTENT VARCHAR(4000)
    )


Description
===========

PCRE groups table function. Given a regular expression in **PATTERN**, and some
text to search in **TEXT**, the function performs a search for **PATTERN** in
the text and returns the result as a table containing a row for each matching
group (including group 0 which implicitly covers the entire search pattern).

Parameters
==========

PATTERN
    The Perl-compatible Regular Expression (PCRE) to search for.

TEXT
    The text to search within.

Returns
=======

GROUP
    The index of the capturing group; group 0 represents the portion of
    **TEXT** which matched the entire **PATTERN**.

POSITION
    The 1-based position of the group within **TEXT**.

CONTENT
    The content of the matched group.

Examples
========

This example demonstrates how multiple groups are matched and returned by the
function:

.. code-block:: sql

    SELECT
        T.GROUP,
        T.POSITION,
        T.CONTENT
    FROM
        TABLE(
            PCRE_GROUPS('(<([A-Z][A-Z0-9]*)[^>]*>)(.*?)(</\2>)', '<B>BOLD!</B>')
        ) AS T

::

    GROUP  POSITION  CONTENT
    -----  --------  -------------------------
        0         1  <B>BOLD!</B>
        1         1  <B>
        2         2  B
        3         4  BOLD!
        4         9  </B>


Example demonstrating how unmatched groups are not returned, while groups
matching the empty string are:

.. code-block:: sql

    SELECT
        T.GROUP,
        T.POSITION,
        T.CONTENT
    FROM
        TABLE(
            PCRE_GROUPS('(FOO)?(\s?)(BAR)?(\s?)(BAZ)?', 'FOOBAR')
        ) AS T

::

    GROUP  POSITION  CONTENT
    -----  --------  -------------------------
        0         1  FOOBAR
        1         1  FOO
        2         4
        3         4  BAR
        4         7


See Also
========

* `SQL source code`_
* `C source code`_
* :ref:`PCRE_SEARCH`
* :ref:`PCRE_SUB`
* :ref:`PCRE_SPLIT`
* `PCRE library homepage`_
* `Wikipedia PCRE article`_

.. _C source code: https://github.com/waveform80/db2utils/blob/master/pcre/pcre_udfs.c#L411
.. _SQL source code: https://github.com/waveform80/db2utils/blob/master/pcre.sql#L206
.. _PCRE library homepage: http://www.pcre.org/
.. _Wikipedia PCRE article: http://en.wikipedia.org/wiki/PCRE
