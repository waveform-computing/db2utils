.. _introduction:

============
Introduction
============

db2utils is a collection of utility routines for `IBM DB2 for
Linux/UNIX/Windows`_ (DB2 for LUW) which I have developed over several years as
a DBA to make my duties a little easier. The package has been tested on DB2
9.7, 10.1, and 10.5 under Linux (and previously with DB2 9.5 under Linux,
although I cannot currently test with this version).

The utilities cover a range of topics including:

* Manipulation of user authorizations including copy all authorizations from
  one user to another

* Numerous date/time manipulation functions including a table-function for
  generating arbitrary date ranges

* Management of temporal data including automatic construction of
  effective-expiry-style history tables, the triggers to maintain them, and
  various views of historical data

* Perl-compatible regular expression functions including searching,
  substitution and splitting

* Automatic construction of exception tables (and analysis views) as used by
  the built-in LOAD utility and the SET INTEGRITY command

* Utilities for easy reconstruction of invalidated views and triggers (rather
  redundant as of 9.7, but probably still useful on 9.5)

* Utility functions which ease the construction of procedures which generate
  SQL (e.g. string and identifier quoting, construction of comma-separated
  column lists)

All functions and procedures are reasonably well documented in these pages, in
comments in the source files, and with COMMENT ON statements within the
database. Per-module and suite-wide roles are also defined to permit easy
management of which users have access to which routines.

A simple installation procedure is provided for Linux/UNIX users, but
Windows support is on an "if you can get it working" basis: I don't have any
DB2 for Windows installations to play with and I've no idea how one compiles
external C-based UDFs on Windows.

.. _IBM DB2 for Linux/UNIX/Windows: http://www-01.ibm.com/software/data/db2/linux-unix-windows/

