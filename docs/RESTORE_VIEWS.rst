.. _RESTORE_VIEWS:

=======================
RESTORE_VIEWS procedure
=======================

Restores all views in the specified schema which were previously saved with
:ref:`SAVE_VIEWS`.

Prototypes
==========

.. code-block:: sql

    RESTORE_VIEWS(ASCHEMA VARCHAR(128))
    RESTORE_VIEWS()


Description
===========

RESTORE_VIEWS is a utility procedure which restores the definition of all views
in the specified schema from :ref:`SAVED_VIEWS` which were previously stored
with :ref:`SAVE_VIEW` or :ref:`SAVE_VIEWS`. RESTORE_VIEWS also implicitly calls
:ref:`RESTORE_AUTH` to restore the authorization of the views. This is in
contrast to inoperative views recreated with :ref:`RECREATE_VIEWS` which lose
authorization information.

.. note::

    This procedure is effectively redundant as of DB2 9.7 due to the new
    deferred revalidation functionality introduced in that version.

Parameters
==========

ASCHEMA
    If provided, the schema containing the views to save. If omitted, this
    parameter defaults to the value of the *CURRENT SCHEMA* special register.

Examples
========

Restore the definition of all views in the *FINANCE* schema:

.. code-block:: sql

    CALL RESTORE_VIEWS('FINANCE');


Restore the definition of all views in the current schema:

.. code-block:: sql

    CALL RESTORE_VIEWS;


See Also
========

* `Source code`_
* :ref:`SAVE_VIEWS`
* :ref:`RESTORE_VIEW`
* :ref:`RESTORE_AUTH`
* `SYSCAT.VIEWS`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/evolve.sql#L563
.. _SYSCAT.VIEWS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001068.html
