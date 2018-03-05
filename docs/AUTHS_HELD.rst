.. _AUTHS_HELD:

=========================
AUTHS_HELD table function
=========================

Utility table function which returns all the authorizations held by a specific
name.

Prototypes
==========

.. code-block:: sql

    AUTHS_HELD(AUTH_NAME VARCHAR(128), AUTH_TYPE VARCHAR(1), INCLUDE_COLUMNS VARCHAR(1), INCLUDE_PERSONAL VARCHAR(1))
    AUTHS_HELD(AUTH_NAME VARCHAR(128), INCLUDE_COLUMNS VARCHAR(1), INCLUDE_PERSONAL VARCHAR(1))
    AUTHS_HELD(AUTH_NAME VARCHAR(128), INCLUDE_COLUMNS VARCHAR(1))

    RETURNS TABLE(
        OBJECT_TYPE VARCHAR(18),
        OBJECT_ID VARCHAR(262),
        AUTH VARCHAR(140),
        SUFFIX VARCHAR(20),
        LEVEL SMALLINT
    )


Description
===========

This is a utility function used by :ref:`COPY_AUTH`, and other associated
procedures, below. Given an authorization name and type, and a couple of flags,
this table function returns the details of all the authorizations held by that
name. The information returned is sufficient for comparison of authorizations
and generation of GRANT/REVOKE statements.

Parameters
==========

AUTH_NAME
    The authorization name to query authorizations for.

AUTH_TYPE
    The type of the authorization name. Use ``'U'`` for users, ``'G'`` for
    groups, or ``'R'`` for roles. If this parameter is omitted the type will be
    determined by calling the :ref:`AUTH_TYPE` function.

INCLUDE_COLUMNS
    If this is ``'Y'`` then include column-level authorizations for relations
    (tables, views, etc). This is useful when generating REVOKE statements from
    the result (as column level authorizations cannot be revoked directly in
    DB2).

INCLUDE_PERSONAL
    This parameter controls whether, in the case where **AUTH_NAME** refers to
    a user (as opposed to a group or role), authorizations associated with the
    user's personal schema are included in the result. If set to ``'Y'``,
    personal schema authorizations are included. Defaults to ``'N'`` if
    omitted.

Returns
=======

The function returns one row per authorization found in the system catalogs for
the specified authorization name. Each row contains the following columns:

OBJECT_TYPE
    This column typically contains a string indicating the type of object
    identified by the *OBJECT_ID* column. However, given that this routine's
    primary purpose is to aid in the generation of GRANT and REVOKE statements,
    and given the inconsistencies in the numerous GRANT and REVOKE syntaxes
    employed by DB2, this column is blank for certain object types (roles and
    security labels), and misleading for others (e.g. ``'TABLE'`` is returned
    for all relation types including views).

OBJECT_ID
    The identifier of the object the authorization was granted upon. This will
    be the schema-qualified name for those objects that reside in a schema, and
    will be properly quoted (if required) for inclusion in generated SQL.

AUTH
    The name of the authority granted upon the *OBJECT_ID*. For example, if
    *OBJECT_TYPE* is ``'DATABASE'`` this might be ``'BINDADD'`` or
    ``'IMPLICIT_SCHEMA'``. Alternatively, if *OBJECT_TYPE* is ``'TABLE'`` this
    could be ``'SELECT'`` or ``'ALTER'``. As the function's purpose is to aid
    in generating GRANT and REVOKE statements, the name of the authority is
    always modelled after what would be used in the syntax of these statements.

SUFFIX
    Several authorizations can be granted with additional permissions. For
    example in the case of tables, SELECT authority can be granted with or
    without the GRANT OPTION (the ability for the grantee to pass on the
    authority to others), while roles can be granted with or without the ADMIN
    OPTION (the ability for the grantee to grant the role to others). If such a
    suffix is associated with the authority, this column will contain the
    syntax required to grant that option.

LEVEL
    This is a numeric indicator of the "level" of a grant. As discussed in the
    description of the SUFFIX column above, authorities can sometimes be
    granted with additional permissions. In such cases this column is a numeric
    indication of the presence of additional permissions (for example, a simple
    SELECT grant would be represented by 0, with SELECT WITH GRANT OPTION would
    be 1). This is used by :ref:`COPY_AUTH` when comparing two sets of
    authorities to determine whether a grant needs "upgrading" (say from SELECT
    to SELECT WITH GRANT OPTION).

Examples
========

Show the authorizations held by the *PUBLIC* group, limiting the results to 10
authorizations per object type (otherwise the results are huge!).

.. code-block:: sql

    WITH T AS (
      SELECT
        ROW_NUMBER() OVER (
          PARTITION BY OBJECT_TYPE
          ORDER BY OBJECT_ID
        ) AS ROWNUM,
        T.*
      FROM
        TABLE (AUTHS_HELD('PUBLIC', 'N')) AS T
    )
    SELECT
      T.OBJECT_TYPE,
      T.OBJECT_ID,
      T.AUTH,
      T.SUFFIX,
      T.LEVEL
    FROM
      T
    WHERE
      T.ROWNUM <= 10

::

    OBJECT_TYPE        OBJECT_ID                                  AUTH                 SUFFIX               LEVEL
    ------------------ ------------------------------------------ -------------------- -------------------- ------
    DATABASE                                                      BINDADD                                        0
    DATABASE                                                      CONNECT                                        0
    DATABASE                                                      CREATETAB                                      0
    DATABASE                                                      IMPLICIT_SCHEMA                                0
    PACKAGE            NULLID.AOTMH00                             BIND                                           0
    PACKAGE            NULLID.AOTMH00                             EXECUTE                                        0
    PACKAGE            NULLID.ATSH04                              BIND                                           0
    PACKAGE            NULLID.ATSH04                              EXECUTE                                        0
    PACKAGE            NULLID.DB2XDBMI                            BIND                                           0
    PACKAGE            NULLID.DB2XDBMI                            EXECUTE                                        0
    PACKAGE            NULLID.PRINTSG                             BIND                                           0
    PACKAGE            NULLID.PRINTSG                             EXECUTE                                        0
    PACKAGE            NULLID.REVALH03                            BIND                                           0
    PACKAGE            NULLID.REVALH03                            EXECUTE                                        0
    PROCEDURE          SYSIBM.*                                   EXECUTE                                        0
    SCHEMA             DAVE                                       CREATEIN                                       0
    SCHEMA             NULLID                                     CREATEIN                                       0
    SCHEMA             SQLJ                                       CREATEIN                                       0
    SCHEMA             SYSPUBLIC                                  CREATEIN                                       0
    SCHEMA             SYSPUBLIC                                  DROPIN                                         0
    SCHEMA             SYSTOOLS                                   CREATEIN                                       0
    SCHEMA             UTILS                                      CREATEIN                                       0
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_CONTACTGROUPS            EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_CONTACTS                 EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_DBP_MEM_USAGE            EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_DBP_MEM_USAGE_AP         EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_INDEX_COMPRESS_INFO      EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_INDEX_INFO               EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_MSGS                     EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_TAB_COMPRESS_INFO        EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_TAB_COMPRESS_INFO_V97    EXECUTE              WITH GRANT OPTION         1
    SPECIFIC FUNCTION  SYSPROC.ADMIN_GET_TAB_INFO                 EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SQLJ.DB2_INSTALL_JAR                       EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SQLJ.DB2_INSTALL_JAR2                      EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SQLJ.DB2_REPLACE_JAR                       EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SQLJ.DB2_UPDATEJARINFO                     EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SQLJ.RECOVERJAR                            EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SQLJ.REFRESH_CLASSES                       EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SQLJ.REMOVE_JAR                            EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SQLJ.REMOVE_JAR2                           EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SYSFUN.GET_SAR                             EXECUTE              WITH GRANT OPTION         1
    SPECIFIC PROCEDURE SYSFUN.GET_SAR4PARM                        EXECUTE              WITH GRANT OPTION         1
    TABLE              SYSCAT.ATTRIBUTES                          SELECT                                         0
    TABLE              SYSCAT.AUDITPOLICIES                       SELECT                                         0
    TABLE              SYSCAT.AUDITUSE                            SELECT                                         0
    TABLE              SYSCAT.BUFFERPOOLDBPARTITIONS              SELECT                                         0
    TABLE              SYSCAT.BUFFERPOOLNODES                     SELECT                                         0
    TABLE              SYSCAT.BUFFERPOOLS                         SELECT                                         0
    TABLE              SYSCAT.CASTFUNCTIONS                       SELECT                                         0
    TABLE              SYSCAT.CHECKS                              SELECT                                         0
    TABLE              SYSCAT.COLAUTH                             SELECT                                         0
    TABLE              SYSCAT.COLCHECKS                           SELECT                                         0
    TABLESPACE         SYSTOOLSTMPSPACE                           USE                                            0
    TABLESPACE         USERSPACE1                                 USE                                            0
    WORKLOAD           SYSDEFAULTUSERWORKLOAD                     USAGE                                          0


See Also
========

* `Source code`_
* :ref:`AUTH_TYPE`
* :ref:`AUTH_DIFF`
* :ref:`COPY_AUTH`
* :ref:`MOVE_AUTH`
* :ref:`REMOVE_AUTH`

.. _Source code: https://github.com/waveform-computing/db2utils/blob/master/auth.sql#L108
