.. _SAVE_VIEWS:

====================
SAVE_VIEWS procedure
====================

Saves the authorizations and definitions of all views in the specified schema
for later restoration with :ref:`RESTORE_VIEWS`.

Prototypes
==========

.. code-block:: sql

    SAVE_VIEWS(ASCHEMA VARCHAR(128))
    SAVE_VIEWS()


Description
===========

SAVE_VIEWS is a utility procedure which saves the definition of all views in
the specified schema to :ref:`SAVED_VIEWS`. These saved definitions can then
be restored with the :ref:`RESTORE_VIEWS` procedure. SAVE_VIEWS also implicitly
calls :ref:`SAVE_AUTH` to preserve the authorizations of the views. This is in
contrast to inoperative views recreated with :ref:`RECREATE_VIEW` which lose
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

Save the definition of all views in the *FINANCE* schema:

.. code-block:: sql

    CALL SAVE_VIEWS('FINANCE');


Save the definition of all views in the current schema:

.. code-block:: sql

    CALL SAVE_VIEWS;


See Also
========

* `Source code`_
* :ref:`RESTORE_VIEWS`
* :ref:`SAVE_VIEW`
* :ref:`SAVE_AUTH`
* `SYSCAT.VIEWS`_ (built-in catalogue view)

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/evolve.sql#L414
.. _SYSCAT.VIEWS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001068.html
