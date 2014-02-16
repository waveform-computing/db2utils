.. _FirstSteps:

===========
First Steps
===========

The package installs a variety of functions and procedures under the ``UTILS`` schema by default. The functions are divided into modules and each module defines at least two roles which can be used to grant access to the functions of that module. The roles are always named UTILS_*module*_USER and UTILS_*module*_ADMIN. For example, the `auth.sql`_ defines UTILS_AUTH_USER and UTILS_AUTH_ADMIN. The UTILS_AUTH_USER role has the ability to execute all procedures and functions within the module. The UTILS_AUTH_ADMIN role also has these execute privileges and in addition has the ability to grant the UTILS_AUTH_USER role to other users and roles.

In addition to the per-module roles, there are also a couple of other roles: UTILS_USER and UTILS_ADMIN. UTILS_USER holds all the per-module user roles, while UTILS_ADMIN holds all the per-module administrative roles so if you wish to grant access to the entire suite, simply grant one of these two roles. Naturally, UTILS_ADMIN also holds the ability to grant UTILS_USER, and in addition has CREATEIN, DROPIN, and ALTERIN privileges on the target schema.

Hence, after installing the package your first step will likely be to assign some roles to other roles. For example, let's assume you have a role called DEVELOPERS who should have access to the entire suite of functions in db2utils. Let's also assume there's a role for ordinary users called QUERY_USERS who should only have access to the enhanced date-time functions in the `date_time.sql`_ module. Finally, there's a role for administrative users called ADMINS who should have administrative control over the package. In this case, after installation you would do the following:

::

    $ db2 GRANT ROLE UTILS_ADMIN TO ROLE ADMINS WITH ADMIN OPTION
    $ db2 GRANT ROLE UTILS_USER TO ROLE DEVELOPERS
    $ db2 GRANT ROLE UTILS_DATE_TIME_USER TO ROLE QUERY_USERS


In order to provide easier access to the functions and procedures in the package you will likely want to alter your function search path:

::

    $ db2 SET PATH SYSTEM PATH, USER, UTILS


If you use the utilities regularly you may wish to construct a small script, alias, or function for connecting to your database and setting the function search path automatically. For example, in my ``.bashrc`` I have:

::

    sample() {
        # Ensure the correct instance is active
        db2 TERMINATE
        source ~db2inst1/sqllib/db2profile
        # Connect to the database and set up the environment
        db2 CONNECT TO SAMPLE
        db2 SET PATH SYSTEM PATH, USER, UTILS
        db2 SET SCHEMA MAIN
    }


.. _auth.sql: https://github.com/waveform80/db2utils/blob/master/auth.sql
.. _date_time.sql: https://github.com/waveform80/db2utils/blob/master/date_time.sql
