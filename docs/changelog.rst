.. _changelog:

==========
Change Log
==========

Release 0.2 (XXX)
=================

The second release mostly consisted of bug fixes and tidying up the
documentation, but a couple of new features were introduced:

* The suite as a whole defines a couple of roles for management of the routines
  defined in the suite, and each module defines per-module subordinate roles
  allowing fine-grain control of who has access to which procedures
* The new assert.sql module includes a variety of routines for writing tests
  for the suite (and indeed databases in general)
* The new merge.sql module includes routines for automatically constructing
  "upsert" style MERGE statements (along with corresponding deletion and
  insertion statements) (`#2`_)

.. _#2: https://github.com/waveform80/db2utils/issues/2


Release 0.1 (2013-08-16)
========================

First packaged release (despite the source repository being public for years :)
