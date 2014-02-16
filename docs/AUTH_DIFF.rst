.. _AUTH_DIFF:

========================
AUTH_DIFF table function
========================

Utility table function which returns the difference between the authorities
held by two names.

Prototypes
==========

.. code-block:: sql

    AUTH_DIFF(SOURCE VARCHAR(128), SOURCE_TYPE VARCHAR(1), DEST VARCHAR(128), DEST_TYPE VARCHAR(1), INCLUDE_COLUMNS VARCHAR(1), INCLUDE_PERSONAL VARCHAR(1))
    AUTH_DIFF(SOURCE VARCHAR(128), DEST VARCHAR(128), INCLUDE_COLUMNS VARCHAR(1), INCLUDE_PERSONAL VARCHAR(1))
    AUTH_DIFF(SOURCE VARCHAR(128), DEST VARCHAR(128), INCLUDE_COLUMNS VARCHAR(1))

    RETURNS TABLE(
      OBJECT_TYPE VARCHAR(18),
      OBJECT_ID VARCHAR(262),
      AUTH VARCHAR(140),
      SUFFIX VARCHAR(20),
      LEVEL SMALLINT
    )


Description
===========

This utility function determines the difference in authorizations held by two
different entities (as determined by :ref:`AUTHS_HELD`). Essentially it takes
the authorizations of the SOURCE entity and "subtracts" the authorizations of
the DEST entity, the result being the authorizations that need to be granted to
DEST to give it the same level of access as SOURCE. This is used in the
definition of the :ref:`COPY_AUTH` routine.

Parameters
==========

SOURCE
    The name to check for existing authorizations.
SOURCE_TYPE
    The type of the SOURCE parameter. Specify ``'U'``, ``'G'``, or ``'R'`` for
    User, Group or Role respectively. If this parameter is omitted, the type
    will be determined by the :ref:`AUTH_TYPE` function.
DEST
    The intended destination for the authorizations held by SOURCE.
DEST_TYPE
    The type of the DEST parameter. Takes the same values as SOURCE_TYPE. If
    omitted, the type will be determined by the :ref:`AUTH_TYPE` function.
INCLUDE_COLUMNS
    If this parameter is ``'Y'``, column level authorizations will be included.
INCLUDE_PERSONAL
    If this parameter is ``'Y'``, and SOURCE identifies a user, then
    authorizations for the source user's personal schema will be included in
    the result. This parameter defaults to ``'N'`` when omitted.

Returns
=======

See the :ref:`AUTHS_HELD` documentation for a description of the columns of the
returned table (this routine is essentially a "subtraction" of two AUTHS_HELD
calls hence the output structure is identical).

Examples
========

Show the authorizations directly granted to the DB2INST1 user which the
currently logged on user does not possess.

.. code-block:: sql

    SELECT * FROM TABLE(AUTH_DIFF('DB2INST1', USER, 'N'));

::

    OBJECT_TYPE OBJECT_ID                 AUTH        SUFFIX               LEVEL
    ----------- ------------------------- ----------- -------------------- ------
    PACKAGE     NULLID.POLYH03            CONTROL                               0
    INDEX       SYSTOOLS.ATM_UNIQ         CONTROL                               0
    INDEX       SYSTOOLS.HI_OBJ_UNIQ      CONTROL                               0
    TABLE       SYSTOOLS.HMON_ATM_INFO    CONTROL                               0
    TABLE       SYSTOOLS.HMON_COLLECTION  CONTROL                               0
    TABLE       SYSTOOLS.POLICY           CONTROL                               0
    INDEX       SYSTOOLS.POLICY_UNQ       CONTROL                               0
    TABLE       SYSTOOLS.HMON_ATM_INFO    ALTER       WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_COLLECTION  ALTER       WITH GRANT OPTION         1
    TABLE       SYSTOOLS.POLICY           ALTER       WITH GRANT OPTION         1
    PACKAGE     NULLID.POLYH03            BIND        WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_ATM_INFO    DELETE      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_COLLECTION  DELETE      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.POLICY           DELETE      WITH GRANT OPTION         1
    PACKAGE     NULLID.POLYH03            EXECUTE     WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_ATM_INFO    INDEX       WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_COLLECTION  INDEX       WITH GRANT OPTION         1
    TABLE       SYSTOOLS.POLICY           INDEX       WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_ATM_INFO    INSERT      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_COLLECTION  INSERT      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.POLICY           INSERT      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_ATM_INFO    REFERENCES  WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_COLLECTION  REFERENCES  WITH GRANT OPTION         1
    TABLE       SYSTOOLS.POLICY           REFERENCES  WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_ATM_INFO    SELECT      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_COLLECTION  SELECT      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.POLICY           SELECT      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_ATM_INFO    UPDATE      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.HMON_COLLECTION  UPDATE      WITH GRANT OPTION         1
    TABLE       SYSTOOLS.POLICY           UPDATE      WITH GRANT OPTION         1
    TABLESPACE  SYSTOOLSPACE              USE         WITH GRANT OPTION         1
    TABLESPACE  SYSTOOLSTMPSPACE          USE         WITH GRANT OPTION         1


See Also
========

* `Source code`_
* :ref:`AUTH_TYPE`
* :ref:`AUTHS_HELD`
* :ref:`COPY_AUTH`
* :ref:`MOVE_AUTH`
* :ref:`REMOVE_AUTH`

.. _Source code: https://github.com/waveform80/db2utils/blob/master/auth.sql#L502
