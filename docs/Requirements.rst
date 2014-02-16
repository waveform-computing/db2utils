.. _Requirements:

============
Requirements
============

Obviously you'll want a relatively recent installation of DB2. Currently, the package has been tested on the following versions and platforms:

* DB2 9.5 for Linux (64-bit)
* DB2 9.7 for Linux (64-bit)

Linux
=====

As db2utils includes C-based external routines, a C compiler is required (gcc is the only one I've tested thus far). GNU make is used to ease the installation process, and GNU awk is used as part of the test script. The PCRE library and headers are required by the pcre functions. All these pre-requisites can be installed quite easily using your distro's package manager. Instructions for specific distros are below:

Ubuntu
    {{{$ sudo apt-get install build-essential gawk libpcre3 libpcre3-dev}}}

Gentoo (with Portage)
    (you almost certainly already have all pre-requisites installed, but if not):`[BR`_]
    {{{# emerge sys-apps/gawk sys-devel/make sys-devel/gcc dev-libs/libpcre}}}

Gentoo (with Paludis)
    (you almost certainly already have all pre-requisites installed, but if not):`[BR`_]
    {{{# cave resolve -x sys-apps/gawk sys-devel/make sys-devel/gcc dev-libs/libpcre}}}

Fedora
    {{{???}}}

OpenSUSE
    {{{???}}}

Windows
=======

What compiler is required for building C-based external routines? How does one install and configure it? How does one execute Makefiles on Windows? Can Cygwin/MingW be used for any of this? If anyone wants to figure this all out, be my guest...

.. _[BR: [BR
