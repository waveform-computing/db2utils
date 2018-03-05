.. _PCRE_SPLIT:

=========================
PCRE_SPLIT table function
=========================

Searches for all occurrences of regular expression **PATTERN** in **TEXT**,
returning a table of all matches and the text between each match.

Prototypes
==========

.. code-block:: sql

    PCRE_SPLIT(PATTERN VARCHAR(1000), TEXT VARCHAR(4000))

    RETURNS TABLE(
      ELEMENT INTEGER,
      SEPARATOR INTEGER,
      POSITION INTEGER,
      CONTENT VARCHAR(4000)
    )


Description
===========

PCRE string splitting function. Given a regular expression in **PATTERN**, and
some text in **TEXT**, the function searches for every occurence of **PATTERN**
in **TEXT** and breaks **TEXT** into chunks based on those matches. Each chunk
is returned as a row in the result table which details whether or not the chunk
was a result of a match, or text between the match.

Parameters
==========

PATTERN
    The Perl-compatible Regular Expression (PCRE) to search for.

TEXT
    The text to search within.

Returns
=======

ELEMENT
    The 1-based index of the chunk. Note that there are usually two rows for
    each index, one where *SEPARATOR* is zero and another where *SEPARATOR* is
    one.  Therefore, one could consider the key of the result table to be
    (*ELEMENT*, *SEPARATOR*)

SEPARATOR
    Contains 1 if the row represents a match for **PATTERN**, and 0 if the row
    represents text between matches.

POSITION
    The 1-based position of *CONTENT* within the original **TEXT** parameter.

CONTENT
    The extract from **TEXT**.

Examples
========

An example demonstrating a simple split. Note that a row is still returned for
the "missing" value, albeit with an empty *CONTENT* value:

.. code-block:: sql

    SELECT
        T.ELEMENT,
        T.SEPARATOR,
        T.POSITION,
        T.CONTENT
    FROM
        TABLE(
           PCRE_SPLIT(':', 'A:B:C::E')
        ) AS T

::

    ELEMENT  SEPARATOR  POSITION  CONTENT
    -------  ---------  --------  -------------------
          1          0         1  A
          1          1         2  :
          2          0         3  B
          2          1         4  :
          3          0         5  C
          3          1         6  :
          4          0         7
          4          1         7  :
          5          0         8  E

An example demonstrating a very rudimentary CSV parser. Note that to keep
things simple, we actually treat the separator pattern as the data here, filter
out the interleaved commas and remove the quotes surrounding delimited values:

.. code-block:: sql

    SELECT
        T.ELEMENT,
        CASE WHEN LEFT(T.CONTENT, 1) = '"'
            THEN SUBSTR(T.CONTENT, 2, LENGTH(T.CONTENT) - 2)
            ELSE T.CONTENT
        END AS CONTENT
    FROM
        TABLE(
            PCRE_SPLIT('([^",][^,]*|"[^"]*")', '"Some",CSV,",data"')
        ) AS T
    WHERE
        T.SEPARATOR = 1

::

    ELEMENT  CONTENT
    -------  -------------------
          1  Some
          2  CSV
          3  ,data


See Also
========

* `SQL source code`_
* `C source code`_
* :ref:`PCRE_SEARCH`
* :ref:`PCRE_SUB`
* :ref:`PCRE_GROUPS`
* `PCRE library homepage`_
* `Wikipedia PCRE article`_

.. _C source code: https://github.com/waveform-computing/db2utils/blob/master/pcre/pcre_udfs.c#L510
.. _SQL source code: https://github.com/waveform-computing/db2utils/blob/master/pcre.sql#L292
.. _PCRE library homepage: http://www.pcre.org/
.. _Wikipedia PCRE article: http://en.wikipedia.org/wiki/PCRE
