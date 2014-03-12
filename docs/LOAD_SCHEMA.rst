.. _LOAD_SCHEMA:

==========================
LOAD_SCHEMA table function
==========================

Generates LOAD commands for all tables in the specified schema, ignoring or
overriding generated and/or identity columns as requested.

Prototypes
==========

.. code-block:: sql

    LOAD_SCHEMA(ASCHEMA VARCHAR(128), ATABLE VARCHAR(128), INCLUDE_GENERATED VARCHAR(1), INCLUDE_IDENTITY VARCHAR(1))
    LOAD_SCHEMA(ATABLE VARCHAR(128), INCLUDE_GENERATED VARCHAR(1), INCLUDE_IDENTITY VARCHAR(1))
    LOAD_SCHEMA(ATABLE VARCHAR(128))

    RETURNS TABLE(
        TABSCHEMA VARCHAR(128),
        TABNAME VARCHAR(128),
        SQL VARCHAR(8000)
    )

Description
===========

This table function can be used to generate a script containing LOAD
commands for all tables (not views) in the specified schema or the current
schema if the **ASCHEMA** parameter is omitted. This is intended to be used in
scripts for migrating the database.

This function is the counterpart of :ref:`EXPORT_SCHEMA`. See
:ref:`EXPORT_SCHEMA` and :ref:`LOAD_TABLE` function for more information on the
commands generated.

Parameters
==========

ASCHEMA
    If provided, the schema containing the tables to generate LOAD commands
    for. If omitted, defaults to the value of the *CURRENT SCHEMA* special
    register.

INCLUDE_GENERATED
    If this parameter is ``'Y'`` then the routine assumes generated columns are
    included in the source files, and the LOAD commands will include the
    *GENERATEDOVERRIDE* modifier. Otherwise, if ``'N'``, the *GENERATEDMISSING*
    modifier will be used instead. Defaults to ``'Y'`` if omitted.

INCLUDE_IDENTITY
    If this parameter is ``'Y'`` then the routine assumes identity columns are
    included in the source files, and the LOAD commands will include the
    *IDENTITYOVERRIDE* modifier. Otherwise, if ``'N'``, the *IDENTITYMISSING*
    modifier will be used instead. Defaults to ``'Y'`` if omitted.

Returns
=======

The function returns one row per table present in the source schema. Note that
the function does *not* filter out invalidated or inoperative tables. The
result table contains three columns:

TABSCHEMA
    Contains the name of the schema containing the table named in *TABNAME*.

TABNAME
    Contains the name of the table that will be loaded by the command in the
    *SQL* column.
SQL
    Contains the text of the generated LOAD command.

The purpose of including the (otherwise redundant) *TABSCHEMA* and *TABNAME*
columns is to permit the result to be filtered further without having to
dissect the *SQL* column.

Examples
========

Generated LOAD commands for all tables in the current schema, excluding all
generated columns:


.. code-block:: sql

    SELECT SQL FROM TABLE(LOAD_SCHEMA('N', 'N'))

::

    SQL
    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    LOAD FROM "DB2INST1.CL_SCHED.IXF" OF IXF METHOD N (CLASS_CODE,DAY,STARTING,ENDING) REPLACE INTO DB2INST1.CL_SCHED (CLASS_CODE,DAY,STARTING,ENDING)
    LOAD FROM "DB2INST1.DEPARTMENT.IXF" OF IXF METHOD N (DEPTNO,DEPTNAME,MGRNO,ADMRDEPT,LOCATION) REPLACE INTO DB2INST1.DEPARTMENT (DEPTNO,DEPTNAME,MGRNO,ADMRDEPT,LOCATION)
    LOAD FROM "DB2INST1.ACT.IXF" OF IXF METHOD N (ACTNO,ACTKWD,ACTDESC) REPLACE INTO DB2INST1.ACT (ACTNO,ACTKWD,ACTDESC)
    LOAD FROM "DB2INST1.EMPLOYEE.IXF" OF IXF METHOD N (EMPNO,FIRSTNME,MIDINIT,LASTNAME,WORKDEPT,PHONENO,HIREDATE,JOB,EDLEVEL,SEX,BIRTHDATE,SALARY,BONUS,COMM) REPLACE INTO DB2INST1.EMPLOYEE (EMPNO,FIRSTNME,MIDINIT,LASTNAME,WORKDEPT,PHONENO,HIREDATE,JOB,EDLEVEL,SEX,BIRTHDATE,SALARY,BONUS,COMM)
    LOAD FROM "DB2INST1.EMP_PHOTO.IXF" OF IXF METHOD N (EMPNO,PHOTO_FORMAT,PICTURE) REPLACE INTO DB2INST1.EMP_PHOTO (EMPNO,PHOTO_FORMAT,PICTURE)
    LOAD FROM "DB2INST1.EMP_RESUME.IXF" OF IXF METHOD N (EMPNO,RESUME_FORMAT,RESUME) REPLACE INTO DB2INST1.EMP_RESUME (EMPNO,RESUME_FORMAT,RESUME)
    LOAD FROM "DB2INST1.PROJECT.IXF" OF IXF METHOD N (PROJNO,PROJNAME,DEPTNO,RESPEMP,PRSTAFF,PRSTDATE,PRENDATE,MAJPROJ) REPLACE INTO DB2INST1.PROJECT (PROJNO,PROJNAME,DEPTNO,RESPEMP,PRSTAFF,PRSTDATE,PRENDATE,MAJPROJ)
    LOAD FROM "DB2INST1.PROJACT.IXF" OF IXF METHOD N (PROJNO,ACTNO,ACSTAFF,ACSTDATE,ACENDATE) REPLACE INTO DB2INST1.PROJACT (PROJNO,ACTNO,ACSTAFF,ACSTDATE,ACENDATE)
    LOAD FROM "DB2INST1.EMPPROJACT.IXF" OF IXF METHOD N (EMPNO,PROJNO,ACTNO,EMPTIME,EMSTDATE,EMENDATE) REPLACE INTO DB2INST1.EMPPROJACT (EMPNO,PROJNO,ACTNO,EMPTIME,EMSTDATE,EMENDATE)
    LOAD FROM "DB2INST1.IN_TRAY.IXF" OF IXF METHOD N (RECEIVED,SOURCE,SUBJECT,NOTE_TEXT) REPLACE INTO DB2INST1.IN_TRAY (RECEIVED,SOURCE,SUBJECT,NOTE_TEXT)
    LOAD FROM "DB2INST1.ORG.IXF" OF IXF METHOD N (DEPTNUMB,DEPTNAME,MANAGER,DIVISION,LOCATION) REPLACE INTO DB2INST1.ORG (DEPTNUMB,DEPTNAME,MANAGER,DIVISION,LOCATION)
    LOAD FROM "DB2INST1.STAFF.IXF" OF IXF METHOD N (ID,NAME,DEPT,JOB,YEARS,SALARY,COMM) REPLACE INTO DB2INST1.STAFF (ID,NAME,DEPT,JOB,YEARS,SALARY,COMM)
    LOAD FROM "DB2INST1.SALES.IXF" OF IXF METHOD N (SALES_DATE,SALES_PERSON,REGION,SALES) REPLACE INTO DB2INST1.SALES (SALES_DATE,SALES_PERSON,REGION,SALES)
    LOAD FROM "DB2INST1.STAFFG.IXF" OF IXF METHOD N (ID,NAME,DEPT,JOB,YEARS,SALARY,COMM) REPLACE INTO DB2INST1.STAFFG (ID,NAME,DEPT,JOB,YEARS,SALARY,COMM)
    LOAD FROM "DB2INST1.EMPMDC.IXF" OF IXF METHOD N (EMPNO,DEPT,DIV) REPLACE INTO DB2INST1.EMPMDC (EMPNO,DEPT,DIV)
    LOAD FROM "DB2INST1.PRODUCT.IXF" OF IXF METHOD N (PID,NAME,PRICE,PROMOPRICE,PROMOSTART,PROMOEND,DESCRIPTION) REPLACE INTO DB2INST1.PRODUCT (PID,NAME,PRICE,PROMOPRICE,PROMOSTART,PROMOEND,DESCRIPTION)
    LOAD FROM "DB2INST1.INVENTORY.IXF" OF IXF METHOD N (PID,QUANTITY,LOCATION) REPLACE INTO DB2INST1.INVENTORY (PID,QUANTITY,LOCATION)
    LOAD FROM "DB2INST1.CUSTOMER.IXF" OF IXF METHOD N (CID,INFO,HISTORY) REPLACE INTO DB2INST1.CUSTOMER (CID,INFO,HISTORY)
    LOAD FROM "DB2INST1.PURCHASEORDER.IXF" OF IXF METHOD N (POID,STATUS,CUSTID,ORDERDATE,PORDER,COMMENTS) REPLACE INTO DB2INST1.PURCHASEORDER (POID,STATUS,CUSTID,ORDERDATE,PORDER,COMMENTS)
    LOAD FROM "DB2INST1.CATALOG.IXF" OF IXF METHOD N (NAME,CATLOG) REPLACE INTO DB2INST1.CATALOG (NAME,CATLOG)
    LOAD FROM "DB2INST1.SUPPLIERS.IXF" OF IXF METHOD N (SID,ADDR) REPLACE INTO DB2INST1.SUPPLIERS (SID,ADDR)
    LOAD FROM "DB2INST1.PRODUCTSUPPLIER.IXF" OF IXF METHOD N (PID,SID) REPLACE INTO DB2INST1.PRODUCTSUPPLIER (PID,SID)

Generate LOAD commands for all tables in the DB2INST1 schema whose names
begin with ``'EMP'``, including generated columns which aren't also identity
columns:

.. code-block:: sql

    SELECT SQL
    FROM TABLE(LOAD_SCHEMA('DB2INST1', 'Y', 'N'))
    WHERE TABNAME LIKE 'EMP%'

::

    SQL
    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    LOAD FROM "DB2INST1.EMPLOYEE.IXF" OF IXF METHOD N (EMPNO,FIRSTNME,MIDINIT,LASTNAME,WORKDEPT,PHONENO,HIREDATE,JOB,EDLEVEL,SEX,BIRTHDATE,SALARY,BONUS,COMM) REPLACE INTO DB2INST1.EMPLOYEE (EMPNO,FIRSTNME,MIDINIT,LASTNAME,WORKDEPT,PHONENO,HIREDATE,JOB,EDLEVEL,SEX,BIRTHDATE,SALARY,BONUS,COMM)
    LOAD FROM "DB2INST1.EMPMDC.IXF" OF IXF METHOD N (EMPNO,DEPT,DIV) REPLACE INTO DB2INST1.EMPMDC (EMPNO,DEPT,DIV)
    LOAD FROM "DB2INST1.EMPPROJACT.IXF" OF IXF METHOD N (EMPNO,PROJNO,ACTNO,EMPTIME,EMSTDATE,EMENDATE) REPLACE INTO DB2INST1.EMPPROJACT (EMPNO,PROJNO,ACTNO,EMPTIME,EMSTDATE,EMENDATE)
    LOAD FROM "DB2INST1.EMP_PHOTO.IXF" OF IXF METHOD N (EMPNO,PHOTO_FORMAT,PICTURE) REPLACE INTO DB2INST1.EMP_PHOTO (EMPNO,PHOTO_FORMAT,PICTURE)
    LOAD FROM "DB2INST1.EMP_RESUME.IXF" OF IXF METHOD N (EMPNO,RESUME_FORMAT,RESUME) REPLACE INTO DB2INST1.EMP_RESUME (EMPNO,RESUME_FORMAT,RESUME)

See Also
========

* `Source code`_
* :ref:`EXPORT_TABLE`
* :ref:`EXPORT_SCHEMA`
* :ref:`LOAD_TABLE`
* `LOAD`_ (built-in command)
* `EXPORT`_ (built-in command)

.. _Source code: https://github.com/waveform80/db2utils/blob/master/export_load.sql#L426
.. _EXPORT: http://pic.dhe.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.admin.cmd.doc/doc/r0008303.html
.. _LOAD: http://pic.dhe.ibm.com/infocenter/db2luw/v9r7/topic/com.ibm.db2.luw.admin.cmd.doc/doc/r0008305.html
