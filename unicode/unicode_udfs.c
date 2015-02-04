/**
 * Unicode UDFs for IBM DB2 for Linux
 *
 * Copyright (c) 2015 Dave Hughes <dave@waveform.org.uk>
 * Copyright (c) 2008-2009 Bjoern Hoehrmann <bjoern@hoehrmann.de>
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
 * the contained functions with the database (see also unicode.sql). Parts
 * of this unit were taken from Bjoern Hoerhmann's excellent little UTF-8
 * decoder which can be found at:
 *
 * <http://bjoern.hoehrmann.de/utf-8/decoder/dfa/>
 *
 */

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sqludf.h>
#include <sqlsystm.h>
#include <sqlstate.h>
#include <errno.h>

#include "unicode_udfs.h"

// Macros for passing thru TRAIL_ARGS[_ALL] to another function
#define SQLUDF_TRAIL_ARGS_PASSTHRU sqludf_sqlstate, \
    sqludf_fname, \
    sqludf_fspecname, \
    sqludf_msgtext
#define SQLUDF_TRAIL_ARGS_ALL_PASSTHRU sqludf_sqlstate, \
    sqludf_fname, \
    sqludf_fspecname, \
    sqludf_msgtext, \
    sqludf_scratchpad, \
    sqludf_call_type

// Code derived from http://bjoern.hoehrmann.de/utf-8/decoder/dfa/
#define UTF8_ACCEPT 0
#define UTF8_REJECT 1

static const uint8_t utf8d[] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 00..1f
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 20..3f
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 40..5f
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 60..7f
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, // 80..9f
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7, // a0..bf
  8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, // c0..df
  0xa,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x4,0x3,0x3, // e0..ef
  0xb,0x6,0x6,0x6,0x5,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8, // f0..ff
  0x0,0x1,0x2,0x3,0x5,0x8,0x7,0x1,0x1,0x1,0x4,0x6,0x1,0x1,0x1,0x1, // s0..s0
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,1, // s1..s2
  1,2,1,1,1,1,1,2,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1, // s3..s4
  1,2,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,3,1,1,1,1,1,1, // s5..s6
  1,3,1,1,1,1,1,3,1,3,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1, // s7..s8
};

uint8_t inline
decode_utf8(uint8_t* state, uint32_t* codep, uint8_t byte) {
  uint8_t type = utf8d[byte];

  *codep = (*state != UTF8_ACCEPT) ?
    (byte & 0x3fu) | (*codep << 6) :
    (0xff >> type) & (byte);

  *state = utf8d[256 + (*state * 16) + type];
  return *state;
}

/**
 * This is a utility routine used by the other routines in the unit to handle
 * reporting errors. Note that *any* code passed as err_code to this function
 * will be treated as an error (even positive codes which are, by definition,
 * not errors). In other words, don't pass something unless you really mean it
 * as an error.
 *
 * The source parameter specifies a short human-readable name for the caller to
 * include in the error message (which may aid users in debugging statements
 * involving several functions).
 */
void unicode_udf_error(
    int err_code,
    char *source,
    SQLUDF_TRAIL_ARGS)
{
    switch (err_code) {
        case UNICODE_TRUNC_ERROR:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: %s", source, UNICODE_TRUNC_MSG);
            break;
        default:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: unknown error (%d)", source, err_code);
            break;
    }
    snprintf(SQLUDF_STATE, SQLUDF_SQLSTATE_LEN + 1, UNICODE_SQLSTATE_PREFIX "%02d", err_code);

    return;
}

/**
 * This is the implementation for the UNICODE_REPLACE_BAD function. See the
 * unicode_udfs.sql script for a full description of this function's purpose
 * and parameters.
 */
SQL_API_RC SQL_API_FN
unicode_udf_replace_bad(
    // input parameters
    SQLUDF_VARCHAR *source, SQLUDF_VARCHAR *repl,
    // output parameters
    SQLUDF_VARCHAR *result,
    // null indicators
    SQLUDF_NULLIND *source_ind, SQLUDF_NULLIND *repl_ind,
    SQLUDF_NULLIND *result_ind,
    SQLUDF_TRAIL_ARGS)
{
    unsigned char *s = source; // current position in source
    unsigned char *c = source; // start of current char in source
    unsigned char *r = result; // current position in result
    unsigned char *result_end = result + UNICODE_MAX_STR_LEN;
    uint32_t codepoint, repl_len = strlen(repl);
    uint8_t prev, current;

    // Return NULL on NULL input
    if (*source_ind == -1 || *repl_ind == -1) {
        *result_ind = -1;
        return;
    }

    // A little macro for checking for overflow before copying to result
#define CHECK_AND_COPY(S, N) \
        if ((r + (N)) > result_end) { \
            unicode_udf_error(UNICODE_TRUNC_ERROR, "replace_bad", SQLUDF_TRAIL_ARGS_PASSTHRU); \
            return; \
        } \
        memcpy(r, (S), (N)); \
        r += (N);

    // Copy valid chars from source to result, and repl when an invalid
    // combination is encountered
    for (prev = current = UTF8_ACCEPT; *s; prev = current, ++s) {
        switch (decode_utf8(&current, &codepoint, *s)) {
            case UTF8_ACCEPT:
                CHECK_AND_COPY(c, s - c + 1);
                c = s + 1;
                break;
            case UTF8_REJECT:
                CHECK_AND_COPY(repl, repl_len);
                current = UTF8_ACCEPT;
                if (prev != UTF8_ACCEPT) s--;
                c = s + 1;
                break;
        }
    }
    if (current != UTF8_ACCEPT) {
        CHECK_AND_COPY(repl, repl_len);
    }
    *r = '\0';
    *result_ind = 0;

    return;
}

/*
int main(int argc, char *argv[]) {
    char state[6] = "00000";
    char msg[SQLUDF_MSGTX_LEN + 1] = "";
    char *source = "Direc\xc7\xc3\xa7\xc3\xa3o Nacional de\xed\xa0\x80 Investiga\xc3\xa7\xc3";
    char *repl = "!!";
    char *result;
    SQLUDF_NULLIND source_ind = 0;
    SQLUDF_NULLIND repl_ind = 0;
    SQLUDF_NULLIND result_ind = 0;

    result = malloc(UNICODE_MAX_STR_LEN + 1);

    unicode_udf_replace_bad(
            source, repl, result,
            &source_ind, &repl_ind, &result_ind,
            state, "foo", "foo", msg);
    printf("result=%s\n", result);

    free(result);

    return 0;
}
*/

/* vim: set et sw=4 sts=4: */
