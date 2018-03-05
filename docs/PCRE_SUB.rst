.. _PCRE_SUB:

========================
PCRE_SUB scalar function
========================

Returns replacement pattern **REPL** with substitutions from matched groups of
regular expression **PATTERN** in **TEXT** starting from 1-based **START**.

Prototypes
==========

.. code-block:: sql

    PCRE_SUB(PATTERN VARCHAR(1000), REPL VARCHAR(4000), TEXT VARCHAR(4000), START INTEGER)
    PCRE_SUB(PATTERN VARCHAR(1000), REPL VARCHAR(4000), TEXT VARCHAR(4000))

    RETURNS VARCHAR(4000)

Description
===========

PCRE substitution function. Given a regular expression in **PATTERN**, a
substitution pattern in **REPL**, some text to match in **TEXT**, and an
optional 1-based **START** position for the search, returns **REPL** with
backslash prefixed group specifications replaced by the corresponding matched
group, e.g. ``\0`` refers to the group that matches the entire **PATTERN**,
``\1`` refers to the first capturing group in **PATTERN**. To include a literal
backslash in **REPL** double it, i.e. ``\\``. Returns NULL if the **PATTERN**
does not match **TEXT**.

Note that ordinary C-style backslash escapes are *not* interpreted by this
function within **REPL**, i.e. ``\n`` will *not* be replaced by a newline
character. Use ordinary SQL hex-strings for this.

Parameters
==========

PATTERN
    The Perl-Compatible Regular Expression (PCRE) to search for.

REPL
    The replacement pattern to return, after substitution of matched groups
    (indicated by back-slash prefixed numbers within this string).

TEXT
    The text to search within.

START
    The 1-based position from which to start the search. Defaults to ``1`` if
    omitted.

Examples
========

Simple searches demonstrating extraction of the matched portion of **TEXT** (if
any):

.. code-block:: sql

    VALUES
      (PCRE_SUB('FOO', '\0', 'FOOBAR')),
      (PCRE_SUB('FOO(BAR)?', '\0', 'FOOBAR')),
      (PCRE_SUB('BAZ', '\0', 'FOOBAR'))

::

    1
    -------------------...
    FOO
    FOOBAR
    -


A substitution demonstrating the extraction of an IP address from some text:

.. code-block:: sql

    VALUES PCRE_SUB('\b(\d{1,3}(\.\d{1,3}){3})\b', '\1', 'IP address: 192.168.0.1')

::

    1
    -----------------...
    192.168.0.1


A substitution demonstrating the replacement of one HTML tag with another:

.. code-block:: sql

    VALUES PCRE_SUB('<([A-Z][A-Z0-9]*)[^>]*>(.*?)</\1>', '<I>\2</I>', '<B>BOLD!</B>')

::

    1
    ------------------...
    <I>BOLD!</I>


A substitution demonstrating that look-aheads do not form part of the match:

.. code-block:: sql

    VALUES PCRE_SUB('Q(?!U)', '\0', 'QI')

::

    1
    ---------------...
    Q


See Also
========

* `SQL source code`_
* `C source code`_
* :ref:`PCRE_SEARCH`
* :ref:`PCRE_SPLIT`
* :ref:`PCRE_GROUPS`
* `PCRE library homepage`_
* `Wikipedia PCRE article`_

.. _C source code: https://github.com/waveform-computing/db2utils/blob/master/pcre/pcre_udfs.c#L280
.. _SQL source code: https://github.com/waveform-computing/db2utils/blob/master/pcre.sql#L129
.. _PCRE library homepage: http://www.pcre.org/
.. _Wikipedia PCRE article: http://en.wikipedia.org/wiki/PCRE
