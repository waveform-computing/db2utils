.. _AUTH_TYPE:

=========================
AUTH_TYPE scalar function
=========================

Utility routine used by other routines to determine the type of an authorization name when it isn't explicitly given.

Prototypes
==========

{{{#!sql
AUTH_TYPE(AUTH_NAME VARCHAR(128))
RETURNS VARCHAR(1)
}}}

Description
===========

This is a utility function used by the :ref:`COPY_AUTH` procedure, and other associated procedures. Given an authorization name, this scalar function returns ``'U'``, ``'G'``, or ``'R'`` to indicate that the name is a user, group, or role respectively (based on the content of the system catalog tables). If the name is undefined, ``'U'`` is returned, unless the name is ``'PUBLIC'`` in which case ``'G'`` is returned (for consistency with the catalog tables). If the name represents multiple authorization types, SQLSTATE 21000 is raised.

Parameters
==========

AUTH_NAME
    The authorization name to test for type.

Examples
========

Show the type of the PUBLIC authorization name.

.. code-block:: sql

    VALUES AUTH_TYPE('PUBLIC');


::

    1
    -
    G


Show the type of the authorization name of the currently logged on user.

.. code-block:: sql

    VALUES AUTH_TYPE(CURRENT USER);


::

    1
    -
    U


See Also
========

* `Source code`_
* :ref:`AUTHS_HELD`
* :ref:`AUTH_DIFF`
* :ref:`COPY_AUTH`
* :ref:`MOVE_AUTH`
* :ref:`REMOVE_AUTH`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/auth.sql#L36
