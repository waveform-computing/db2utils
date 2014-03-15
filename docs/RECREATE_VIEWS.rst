.. _RECREATE_VIEWS:

========================
RECREATE_VIEWS procedure
========================

Recreates all inoperative views in the specified schema from their system
catalogue definitions.

Prototypes
==========

.. code-block:: sql

    RECREATE_VIEWS(ASCHEMA VARCHAR(128))
    RECREATE_VIEWS()


Description
===========

RECREATE_VIEWS is a utility procedure which recreates all inoperative views in
a specified schema, using the SQL found in the system catalogue tables. It is
useful for quickly recreating views which have been marked inoperative after a
change to one or more of the views' dependencies. If **ASCHEMA** is omitted it
defaults to the current schema.

.. note::

    This procedure is effectively redundant as of DB2 9.7 due to the new
    deferred revalidation functionality introduced in that version.

.. warning::

    This procedure does not take into account the dependencies of views when
    recreating them. It crudely attempts to correctly order recreations on the
    basis of the CREATE_TIME field in the system catalogue, but this is not
    necessarily accurate. However, multiple consecutive runs of the procedure
    can be sufficient to recreate all inoperative views.

.. warning::

    See :ref:`SAVE_AUTH` for warnings regarding the loss of authorization
    information with inoperative views.

Parameters
==========

ASCHEMA
    If provided, specifies the schema containing the views to recreate. If
    omitted, defaults to the value of the *CURRENT SCHEMA* special register.

Examples
========

Recreate all inoperative views in the *FOO* schema:

.. code-block:: sql

    CALL RECREATE_VIEWS('FOO');


Recreate all inoperative views in the current schema:

.. code-block:: sql

    CALL RECREATE_VIEWS;


See Also
========

* `Source code`_
* :ref:`RECREATE_VIEW`
* :ref:`SAVE_AUTH`
* :ref:`SAVE_VIEW`
* :ref:`RESTORE_VIEW`
* `SYSCAT.VIEWS`_ (built-in catalog view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/evolve.sql#L118
.. _SYSCAT.VIEWS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001068.html
