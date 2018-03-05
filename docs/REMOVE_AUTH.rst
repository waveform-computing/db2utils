.. _REMOVE_AUTH:

=====================
REMOVE_AUTH procedure
=====================

Removes all authorities held by the specified name.

Prototypes
==========

.. code-block:: sql

    REMOVE_AUTH(AUTH_NAME VARCHAR(128), AUTH_TYPE VARCHAR(1), INCLUDE_PERSONAL VARCHAR(1))
    REMOVE_AUTH(AUTH_NAME VARCHAR(128), INCLUDE_PERSONAL VARCHAR(1))
    REMOVE_AUTH(AUTH_NAME VARCHAR(128))


Description
===========

REMOVE_AUTH is a procedure which removes all authorizations from the entity
specified by **AUTH_NAME**, and optionally **AUTH_TYPE**. If **AUTH_TYPE** is
omitted :ref:`AUTH_TYPE` will be used to determine it. Otherwise, it must
be ``'U'``, ``'G'``, or ``'R'``, standing for user, group or role respectively.

.. warning::

    This routine will not handle revoking column level authorizations, i.e.
    REFERENCES and UPDATES, which cannot be revoked directly but rather have to
    be revoked overall at the table level. Any such authorziations must be
    handled manually.

Parameters
==========

AUTH_NAME
    The name of the user, group, or role to remove all authorizations from.

AUTH_TYPE
    The letter ``'U'``, ``'G'``, or ``'R'`` indicating whether **AUTH_NAME**
    refers to a user, group, or role respectively. If omitted, :ref:`AUTH_TYPE`
    will be used to determine the type of **AUTH_NAME**.

INCLUDE_PERSONAL
    If this parameter is ``'Y'`` and **AUTH_NAME** refers to a user, then all
    authorizations associated with the user's personal schema will be included.
    Defaults to ``'N'`` if omitted, meaning the user will still have access to
    all objects within their personal schema by default.

Examples
========

Remove all authorizations from the user *FRED*, but leave personal schema
authorizations intact.

.. code-block:: sql

    CALL REMOVE_AUTH('FRED');


Remove all authorizations from the *FINANCE* group (the **INCLUDE_PERSONAL**
parameter is redundant here as **AUTH_NAME** is not a user).

.. code-block:: sql

    CALL REMOVE_AUTH('FINANCE', 'G', 'N');


See Also
========

* `Source code`_
* :ref:`AUTH_TYPE`
* :ref:`AUTHS_HELD`
* :ref:`AUTH_DIFF`
* :ref:`COPY_AUTH`
* :ref:`MOVE_AUTH`

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/auth.sql#L924
