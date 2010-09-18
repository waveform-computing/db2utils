/**
 * PERL compatible regular expression UDFs for IBM DB2 for Linux
 *
 * Copyright (c) 2005-2010 Dave Hughes <dave@waveform.org.uk>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 *
 * Inspired by Knut Stolze's excellent developerWorks article, "Bringing the
 * Power of Regular Expression Matching to SQL", available from:
 *
 *   <http://www.ibm.com/developerworks/data/library/techarticle/0301stolze/0301stolze.html>
 *
 * Use the provided Makefile to build and install this library, and to register
 * the contained functions with the database (see also pcre_udfs.sql).
 */

// This is the prefix for any SQLSTATEs used to indicate a PCRE error. The
// first two characters must be "38", the third character may not be "0"
// through "5" (these are reserved by DB2)
#define PCRE_SQLSTATE_PREFIX "386"

// These are the suffixes for SQLSTATEs and the corresponding error messages
// used to indicate an error in this library
#define PCRE_SQLSTATE_MALLOC_ERROR        "99"
#define PCRE_SQLSTATE_COMPILE_ERROR       "98"
#define PCRE_SQLSTATE_STUDY_ERROR         "97"
#define PCRE_SQLSTATE_INCOMPLETE_TEMPLATE "96"
#define PCRE_SQLSTATE_INVALID_TEMPLATE    "95"
#define PCRE_SQLSTATE_INVALID_GROUP       "94"
#define PCRE_SQLSTATE_TOO_MANY_GROUPS     "93"
#define PCRE_SQLSTATE_EMPTY_SPLIT         "92"

#define PCRE_MSGTX_MALLOC_ERROR           "failed to allocate memory"
#define PCRE_MSGTX_COMPILE_ERROR          "%s at position %d"
#define PCRE_MSGTX_STUDY_ERROR            "%s"
#define PCRE_MSGTX_INCOMPLETE_TEMPLATE    "incomplete template at position %ld"
#define PCRE_MSGTX_INVALID_TEMPLATE       "invalid template \\%c at position %ld"
#define PCRE_MSGTX_INVALID_GROUP          "invalid group in template at position %ld"
#define PCRE_MSGTX_TOO_MANY_GROUPS        "too many capturing groups"
#define PCRE_MSGTX_EMPTY_SPLIT            "split pattern matched the empty string"

// Maximum length of the result of PCRE_SUB or the CONTENT column of
// PCRE_GROUPS.  Must match the function definitions in pcre_udfs.sql
#define PCRE_MAX_STR_LEN (4000)

// The maximum length of the buffer provided for error messages. Do not alter
// this value
#define SQLUDF_MSGTX_LEN (70)

/* vim: set et sw=4 sts=4: */
