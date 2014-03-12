.. _MOVE_AUTH:

===================
MOVE_AUTH procedure
===================

Moves all authorities held by the source to the target, provided they are not
already held.

Prototypes
==========

.. code-block:: sql

    MOVE_AUTH(SOURCE VARCHAR(128), SOURCE_TYPE VARCHAR(1), DEST VARCHAR(128), DEST_TYPE VARCHAR(1), INCLUDE_PERSONAL VARCHAR(1))
    MOVE_AUTH(SOURCE VARCHAR(128), DEST VARCHAR(128), INCLUDE_PERSONAL VARCHAR(1))
    MOVE_AUTH(SOURCE VARCHAR(128), DEST VARCHAR(128))


Description
===========

MOVE_AUTH is a procedure which moves all authorizations from the source grantee
(**SOURCE**) to the destination grantee (**DEST**). Like :ref:`COPY_AUTH`, this
procedure does not preserve the grantor, and method authorizations are not
moved. Essentially this procedure combines :ref:`COPY_AUTH` and
:ref:`REMOVE_AUTH` to copy authorizations from **SOURCE** to **DEST** and then
remove them from **SOURCE**.

.. note::

    Column-level authorizations will be copied to **DEST**, but will not be
    removed from **SOURCE**. Their removal must be handled manually.

Parameters
==========

SOURCE
    The name of the user, group, or role to copy permissions from.

SOURCE_TYPE
    One of ``'U'``, ``'G'``, or ``'R'`` indicating whether **SOURCE** refers to
    a user, group, or role respectively. If this parameter is omitted
    :ref:`AUTH_TYPE` will be used to determine the type of **SOURCE**.

DEST
    The name of the user, group, or role to copy permissions to.

DEST_TYPE
    One of ``'U'``, ``'G'``, or ``'R'`` indicating whether **DEST** refers to a
    user, group, or role respectively. If this parameter is omitted
    :ref:`AUTH_TYPE` will be used to determine the type of **DEST**.

INCLUDE_PERSONAL
    If this parameter is ``'Y'`` and **SOURCE** refers to a user, then
    permissions associated with the user's personal schema will be included in
    the transfer. Defaults to ``'N'`` if omitted.

Examples
========

Copy authorizations from the user *TOM* to the user *DICK*, excluding any
permissions associated with the *TOM* schema (so *TOM* retains access to his
personal schema after this command).

.. code-block:: sql

    CALL MOVE_AUTH('TOM', 'DICK', 'N');


Move permissions granted to a group called *FINANCE* to a role called *FINANCE*
(the **INCLUDE_PERSONAL** parameter is set to ``'N'`` here, but is effectively
redundant as **SOURCE_TYPE** is not ``'U'``).

.. code-block:: sql

    CALL MOVE_AUTH('FINANCE', 'G', 'FINANCE', 'R', 'N');


See Also
========

* `Source code`_
* :ref:`AUTH_TYPE`
* :ref:`AUTH_DIFF`
* :ref:`AUTHS_HELD`
* :ref:`COPY_AUTH`
* :ref:`REMOVE_AUTH`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/auth.sql#L1079
