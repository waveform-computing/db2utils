.. _modules:

================
Modules Overview
================

The routines are divided into modules roughly by topic:

`assert.sql`_
   Includes a set of procedures and functions for performing assertion tests
   against the framework.

`auth.sql`_
   Includes a set of procedures for managing authorizations, including the
   ability to copy, remove, and move all authorizations for a given ID, and
   save and restore authorizations on relations.

`corrections.sql`_
   In the databases I work with there is frequently a need to correct data
   sourced from other databases, typically names of entities which weren't
   "neat enough" for reporting purposes. We accomplished this by having an
   "original name" column, a "corrected name" column, and finally the name
   column itself would be a generated column coalescing the two together. Only
   those names that required correction would have a value in the "corrected
   name" column, and a trigger on the table would ensure that corrections would
   be wiped in the event that the "original name" changed (on the assumption
   that the correction would need changing). This module contains procedures
   for creating the trigger.

`date_time.sql`_
   Contains numerous functions for handling ``DATE``, ``TIME`` and
   ``TIMESTAMP`` values including calculating the start and end dates of years,
   quarters, and months, calculating the next or previous of a particular day
   of the week (Monday, Tuesday, etc.), formatting timestamps with strftime()
   style templates, and a table function for generating a range of dates.

`drop_schema.sql`_
   Contains a procedure for dropping all objects in a schema, and the schema
   itself. This is redundant as of DB2 9.5 which incldues `ADMIN_DROP_SCHEMA`_,
   but the syntax is a bit easier for this one as it doesn't rely on a table to
   report errors (if something goes wrong it just fails and throws an SQL
   error).

`evolve.sql`_
   Contains procedures which make schema evolution (changing views and such
   like) a bit easier. This is redundant as of DB2 9.7 which includes much
   better schema evolution capabilities (deferred revalidation), but may still
   be useful for people on earlier versions. The routines include the ability
   to save and restore view definitions, including authorizations, and routines
   for easily recreating invalid views and triggers from their definitions in
   the system catalog.

`exceptions.sql`_
   Contains procedures for creating exception tables and views. Exception
   tables have the same structure as a base table but with two extra columns
   for reporting errors that occur during a ``LOAD`` or ``SET INTEGRITY``
   command. Exception views translate the (rather cryptic) extra columns in
   exception tables into human readable information.

`export_load.sql`_
   Contains functions for generating ``EXPORT`` and ``LOAD`` commands for
   tables or schemas of tables. These can be used to easily generate CLP
   scripts which mimic the function of ``db2move``, but with all the filtering
   capabilities of SQL (i.e. you could limit the scope with more fidelity than
   just specifying a schema), and with functionality to cope with ``IDENTITY``
   and ``GENERATED`` columns properly (which ``db2move`` has problems with).

`history.sql`_
   Contains procedures for creating "history" tables, triggers, and views.
   History tables track the changes to a base table over time. Triggers on the
   base table are used to populate the history table. Views on the history
   table can be created to provide different perspectives on the history data
   (snapshots over time, explicit lists of what changes occured, etc).

`log.sql`_
   Contains a table and a procedure for logging administrative alerts and
   information. This module isn't complete yet; plenty of functionality I'd
   like to implement when I get the time...

`merge.sql`_
   Defines a set of procedures for automatically generating ``INSERT``,
   ``DELETE``, and ``MERGE`` statements with the intention of bulk-transferring
   data between similarly structured tables.

`pcre.sql`_
   Defines a set of functions providing `PCRE`_ (Perl Compatible Regular
   Expression) search, split and substitution functionality. The functions are
   implemented in a C library the source for which is in the `pcre/`_
   sub-directory.

`sql.sql`_
   Contains a couple of simple functions for escaping strings and identifiers
   in SQL. Used by numerous of the modules for generating SQL dynamically.

`toggle_triggers.sql`_
   Contains procedures for easily disabling and enabling triggers, including
   specific triggers or all triggers on a given table.

`unicode.sql`_
   Defines functions for cleaning up Unicode strings, in particular those using
   the common UTF-8 encoding scheme. The functions are implemented in a C
   library the source for which is in the `unicode/`_ sub-directory.


.. _PCRE: http://www.pcre.org
.. _drop_schema.sql: https://github.com/waveform-computing/db2utils/blob/master/drop_schema.sql
.. _evolve.sql: https://github.com/waveform-computing/db2utils/blob/master/evolve.sql
.. _pcre/: https://github.com/waveform-computing/db2utils/blob/master/pcre/
.. _unicode/: https://github.com/waveform-computing/db2utils/blob/master/unicode/
.. _date_time.sql: https://github.com/waveform-computing/db2utils/blob/master/date_time.sql
.. _exceptions.sql: https://github.com/waveform-computing/db2utils/blob/master/exceptions.sql
.. _export_load.sql: https://github.com/waveform-computing/db2utils/blob/master/export_load.sql
.. _auth.sql: https://github.com/waveform-computing/db2utils/blob/master/auth.sql
.. _ADMIN_DROP_SCHEMA: http://publib.boulder.ibm.com/infocenter/db2luw/v9r5/topic/com.ibm.db2.luw.sql.rtn.doc/doc/r0022036.html
.. _pcre.sql: https://github.com/waveform-computing/db2utils/blob/master/pcre.sql
.. _unicode.sql: https://github.com/waveform-computing/db2utils/blob/master/unicode.sql
.. _toggle_triggers.sql: https://github.com/waveform-computing/db2utils/blob/master/toggle_triggers.sql
.. _history.sql: https://github.com/waveform-computing/db2utils/blob/master/history.sql
.. _log.sql: https://github.com/waveform-computing/db2utils/blob/master/log.sql
.. _merge.sql: https://github.com/waveform-computing/db2utils/blob/master/merge.sql
.. _sql.sql: https://github.com/waveform-computing/db2utils/blob/master/sql.sql
.. _assert.sql: https://github.com/waveform-computing/db2utils/blob/master/assert.sql
.. _corrections.sql: https://github.com/waveform-computing/db2utils/blob/master/corrections.sql

