.. _RECREATE_VIEW:

=======================
RECREATE_VIEW procedure
=======================

Recreates the specified inoperative view from its definition in the system
catalogue.

Prototypes
==========

.. code-block:: sql

    RECREATE_VIEW(ASCHEMA VARCHAR(128), AVIEW VARCHAR(128))
    RECREATE_VIEW(AVIEW VARCHAR(128))


Description
===========

RECREATE_VIEW is a utility procedure which recreates the specified view using
the SQL found in the system catalog tables. It is useful for quickly recreating
views which have been marked inoperative after a change to one or more of the
view's dependencies. If **ASCHEMA** is omitted it defaults to the current
schema.

.. note::

    This procedure is effectively redundant as of DB2 9.7 due to the new
    deferred revalidation functionality introduced in that version.

.. warning::

    This procedure does *not* drop the view before recreating it. This guards
    against attempting to recreate an operative view (an inoperative view can
    be recreated without dropping it first). That said, it will not return an
    error in the case of attempting to recreate an operative view; the
    procedure will simply do nothing.

.. warning::

    See :ref:`SAVE_AUTH` for warnings regarding the loss of authorization
    information with inoperative views.

Parameters
==========

ASCHEMA
    If provided, specifies the schema containing the view to recreate. If
    omitted, defaults to the value of the *CURRENT SCHEMA* special register.

AVIEW
    The name of the view to recreate.

Examples
========

Recreate the inoperative *FOO.BAR* view:

.. code-block:: sql

    CALL RECREATE_VIEW('FOO', 'BAR');

Recreate the *BAZ* view in the current schema:

.. code-block:: sql

    CALL RECREATE_VIEW('BAZ');


See Also
========

* `Source code`_
* :ref:`RECREATE_VIEWS`
* :ref:`SAVE_AUTH`
* :ref:`SAVE_VIEW`
* :ref:`RESTORE_VIEW`
* `SYSCAT.VIEWS`_ (built-in catalog view)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/evolve.sql#L46
.. _SYSCAT.VIEWS: http://publib.boulder.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.sql.ref.doc/doc/r0001068.html
