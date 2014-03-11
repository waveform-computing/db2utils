.. _installation:

============
Installation
============

First, make sure you've installed the :ref:`REQUIREMENTS`, then following the
instructions in the section for your platform below.

Linux
=====

Log on as a user which has **SYSADM** authority for the DB2 instance you wish
to install under (commonly this is *db2inst1*), and ensure the **db2profile**
for the target DB2 instance has been sourced (this is the usually the case with
the *db2inst1* user)::

    $ su - db2inst1
    $ source ~db2inst1/sqllib/db2profile

Extract the archive you downloaded, and change to the directory it creates::

    $ tar -xzf db2utils-release-0.1.tar.gz
    $ cd db2utils-release-0.1

Edit the two variables **DBNAME** and **SCHEMANAME** at the top of the
`Makefile`_::

    $ ${EDITOR} Makefile

These indicate the database into which to install everything and the schema
under which to place all objects. Finally, use the included Makefile to make
the "install" target::

    $ make install

This will compile the external pcre UDFs library, install it in the instance
identified by the **DB2INSTANCE** environment variable (which is set by
**db2profile**), then connect to the database identified by **DBNAME** and
install everything under the schema specified by **SCHEMANAME**.

If you wish to see the SQL that would be executed without actually executing it
(if, for example, you wish to edit it before hand) you can create it with the
following target::

    $ make install.sql

If you wish to uninstall everything from the database, simply make the
"uninstall" target::

    $ make uninstall

There is also a target which attempts to test the implementation of various
functions and procedures by using the functions in the `assert.sql`_ module.
This can be run with the "test" target::

    $ make test

The test suite is currently rather crude. Any error immediately stops the test
suite to allow examination. If the test suite runs to the end, this indicates
success.

Windows
=======

Anyone want to figure this out?

.. _assert.sql: https://github.com/waveform80/db2utils/blob/master/assert.sql
.. _Makefile: https://github.com/waveform80/db2utils/blob/master/Makefile
