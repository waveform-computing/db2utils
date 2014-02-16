.. _PCRE_SEARCH:

===========================
PCRE_SEARCH scalar function
===========================

Searches for regular expression PATTERN within TEXT starting at 1-based START.

Prototypes
==========

.. code-block:: sql

    PCRE_SEARCH(PATTERN VARCHAR(1000), TEXT VARCHAR(4000), START INTEGER)
    PCRE_SEARCH(PATTERN VARCHAR(1000), TEXT VARCHAR(4000))

    RETURNS INTEGER


Description
===========

PCRE searching function. Given a regular expression in PATTERN, and some text to search in TEXT, returns the 1-based position of the first match. START is an optional 1-based position from which to start the search (defaults to 1 if not specified). If no match is found, the function returns zero. If PATTERN, TEXT, or START is NULL, the result is NULL.

Parameters
==========

PATTERN
    The Perl-compatible Regular Expression (PCRE) to search for
TEXT
    The text to search within
START
    The 1-based position from which to start the search. Defaults to 1 if omitted.

Examples
========

Simple searches showing the return value is a 1-based position or 0 in the case of failure:

.. code-block:: sql

    VALUES
      (PCRE_SEARCH('FOO', 'FOOBAR')),
      (PCRE_SEARCH('BAR', 'FOOBAR')),
      (PCRE_SEARCH('BAZ', 'FOOBAR'))


::

    1
    ----------
             1
             4
             0


A search to check whether a value looks vaguely like an IP address; note that the octets are not checked for 0-255 range:

.. code-block:: sql

    VALUES PCRE_SEARCH('^\d{1,3}(\.\d{1,3}){3}$', '192.168.0.1')


::

    1
    ----------
             1



A search demonstrating use of back-references to check that a closing tag matches the opening tag:

.. code-block:: sql

    VALUES PCRE_SEARCH('<([A-Z][A-Z0-9]*)[^>]*>.*?</\1>', '<B>BOLD!</B>')


::

    1
    ----------
             1


Searches demonstrating negative look-aheads:

.. code-block:: sql

    VALUES
      (PCRE_SEARCH('Q(?!U)', 'QUACK')),
      (PCRE_SEARCH('Q(?!U)', 'QI'))


::

    1
    ----------
             0
             1


See Also
========

* `SQL source code`_
* `C source code`_
* :ref:`PCRE_SUB`
* :ref:`PCRE_SPLIT`
* :ref:`PCRE_GROUPS`
* `PCRE library homepage`_
* `Wikipedia PCRE article`_

.. _C source code: https://github.com/waveform80/db2utils/blob/master/pcre/pcre_udfs.c#L225
.. _SQL source code: https://github.com/waveform80/db2utils/blob/master/pcre.sql#L45
.. _PCRE library homepage: http://www.pcre.org/
.. _Wikipedia PCRE article: http://en.wikipedia.org/wiki/PCRE
