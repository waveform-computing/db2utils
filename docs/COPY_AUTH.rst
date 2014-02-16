.. _COPY_AUTH:

===================
COPY_AUTH procedure
===================

Grants all authorities held by the source to the target, provided they are not
already held (i.e. does not "re-grant" authorities already held).

Prototypes
==========

.. code-block:: sql

    COPY_AUTH(SOURCE VARCHAR(128), SOURCE_TYPE VARCHAR(1), DEST VARCHAR(128), DEST_TYPE VARCHAR(1), INCLUDE_PERSONAL VARCHAR(1))
    COPY_AUTH(SOURCE VARCHAR(128), DEST VARCHAR(128), INCLUDE_PERSONAL VARCHAR(1))
    COPY_AUTH(SOURCE VARCHAR(128), DEST VARCHAR(128))


Description
===========

COPY_AUTH is a procedure which copies all authorizations from the source
grantee (SOURCE) to the destination grantee (DEST). Note that the
implementation does not preserve the grantor, although technically this would
be possible by utilizing the SET SESSION USER facility introduced by DB2 9, nor
does it remove extra permissions that the destination grantee already possessed
prior to the call. Furthermore, method authorizations are not copied.

Parameters
==========

SOURCE
    The name of the user, group, or role to copy permissions from.
SOURCE_TYPE
    One of ``'U'``, ``'G'``, or ``'R'`` indicating whether SOURCE refers to a
    user, group, or role respectively. If this parameter is omitted the
    :ref:`AUTH_TYPE` function will be used to determine the type of SOURCE.
DEST
    The name of the user, group, or role to copy permissions to.
DEST_TYPE
    One of ``'U'``, ``'G'``, or ``'R'`` indicating whether DEST refers to a
    user, group, or role respectively. If this parameter is omitted the
    :ref:`AUTH_TYPE` function will be used to determine the type of DEST.
INCLUDE_PERSONAL
    If this parameter is ``'Y'`` and SOURCE refers to a user, then permissions
    associated with the user's personal schema will be included in the
    transfer. Defaults to ``'N'`` if omitted.

Examples
========

Copy authorizations from the user TOM to the user DICK, excluding any
permissions associated with the TOM schema.

.. code-block:: sql

    CALL COPY_AUTH('TOM', 'DICK', 'N');


Copy permissions granted to a group called FINANCE to a role called FINANCE
(the INCLUDE_PERSONAL parameter is set to 'N' here, but is effectively
redundant as SOURCE_TYPE is not 'U').

.. code-block:: sql

    CALL COPY_AUTH('FINANCE', 'G', 'FINANCE', 'R', 'N');


See Also
========

* `Source code`_
* :ref:`AUTH_TYPE`
* :ref:`AUTH_DIFF`
* :ref:`AUTHS_HELD`
* :ref:`MOVE_AUTH`
* :ref:`REMOVE_AUTH`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/auth.sql#L734
