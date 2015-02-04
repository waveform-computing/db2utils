/**
 * PERL compatible regular expression UDFs for IBM DB2 for Linux
 *
 * Copyright (c) 2015 Dave Hughes <dave@waveform.org.uk>
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
 * Use the provided Makefile to build and install this library, and to register
 * the contained functions with the database (see also unicode_udfs.sql).
 */

// This is the prefix for any SQLSTATEs used to indicate a Unicode error. The
// first two characters must be "38", the third character may not be "0"
// through "5" (these are reserved by DB2)
#define UNICODE_SQLSTATE_PREFIX "387"

// These are the suffixes for SQLSTATEs and the corresponding error messages
// used to indicate an error in this library
#define UNICODE_TRUNC_ERROR            1

#define UNICODE_TRUNC_MSG              "out of space in result string"

// Maximum length of the result of UNICODE_*.  Must match the function
// definitions in unicode_udfs.sql
#define UNICODE_MAX_STR_LEN (4000)

// The maximum length of the buffer provided for error messages. Do not alter
// this value
#define SQLUDF_MSGTX_LEN (70)

/* vim: set et sw=4 sts=4: */
