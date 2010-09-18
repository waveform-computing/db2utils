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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <pcre.h>
#include <sqludf.h>
#include <sqlsystm.h>
#include <sqlstate.h>
#include <errno.h>

#include "pcre_udfs.h"

// Dirty hacks for passing thru TRAIL_ARGS[_ALL] to another function
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

struct generic_scratch_pad {
    char *pattern;     // currently compiled pattern
    pcre *re;          // compiled regular expression
    pcre_extra *extra; // extra study data
    const char *error; // compilation error message
    int error_offset;  // compilation error position
};

struct groups_scratch_pad {
    pcre *re;          // compiled regular expression
    pcre_extra *extra; // extra study data
    const char *error; // compilation error message
    int error_offset;  // compilation error position
    int group;         // current group
    int group_count;   // number of matched groups
    int *groups;       // vector of (start, end) group positions
};

struct split_scratch_pad {
    char *pattern;     // currently compiled pattern
    pcre *re;          // compiled regular expression
    pcre_extra *extra; // extra study data
    const char *error; // compilation error message
    int error_offset;  // compilation error position
    // Note that this struct is an extension of generic_scratch_pad
    int element;       // match counter
    int separator;     // current row is separator indicator
    int start;         // match start position
    int group_count;   // number of matched groups
    int *groups;       // vector of (start, end) group positions
};

/**
 * This is a utility function used by most routines in the library. Using the
 * generic_scratch_pad structure, it compiles the provided pattern and stores
 * the result in the "re" element. It also copies the pattern into the
 * "pattern" element of the scratch pad and on subsequent calls will check
 * whether the pattern has changed and recompile if necessary.
 *
 * If the initialization is successful, the function returns zero.  If an error
 * occurs, the SQLSTATE and error message is set accordingly and the function
 * returns a non-zero value. Likewise, if SQLUDF_CALLT indicates this is the
 * final call in a run of calls, memory allocated to the scratchpad is cleaned
 * and the function returns a non-zero value. In the event of non-zero return
 * from this function, the caller should immediately return.
 */
int pcre_udf_init_generic(
    SQLUDF_VARCHAR *pattern,
    SQLUDF_TRAIL_ARGS_ALL)
{
    struct generic_scratch_pad *sp = NULL;

    sp = (struct generic_scratch_pad*)SQLUDF_SCRAT->data;
    switch (SQLUDF_CALLT) {
        case SQLUDF_NORMAL_CALL:
        //case SQLUDF_TF_FETCH:
            // If this isn't the first call, check whether the provided pattern
            // matches the last one we compiled. If it's changed, then free the
            // current copy of the pattern, and fall through to the first call
            // case to compile the new pattern
            if (strcmp(sp->pattern, pattern) == 0)
                break;
            free(sp->pattern);
            sp->pattern = NULL;
        case SQLUDF_FIRST_CALL:
        //case SQLUDF_TF_OPEN:
            // If the pattern's changed since the last call, or if this is the
            // first call being made then grab a copy of the pattern (to
            // compare with the next call's pattern), then compile & study it.
            // If anything goes wrong with compilation or studying, fall
            // through to the final call case to perform clean up
            sp->pattern = (char *)(*pcre_malloc)(strlen(pattern) + 1);
            if (sp->pattern == NULL) {
                snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_MALLOC_ERROR);
                strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_MALLOC_ERROR);
            }
            strcpy(sp->pattern, pattern);
            sp->re = pcre_compile(pattern, PCRE_UTF8, &sp->error, &sp->error_offset, NULL);
            if (sp->re == NULL) {
                snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_COMPILE_ERROR, sp->error, sp->error_offset + 1);
                strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_COMPILE_ERROR);
            }
            else {
                sp->extra = pcre_study(sp->re, 0, &sp->error);
                if (sp->error == NULL)
                    break;
                snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_STUDY_ERROR, sp->error);
                strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_STUDY_ERROR);
            }
        case SQLUDF_FINAL_CALL:
        //case SQLUDF_TF_CLOSE:
            // In the case of the final call, or in the case that an error
            // occurs in compilation or studying in the earlier case, free
            // anything we allocated and return
            (*pcre_free)(sp->pattern);
            sp->pattern = NULL;
            (*pcre_free)(sp->re);
            sp->re = NULL;
            (*pcre_free)(sp->extra);
            sp->extra = NULL;
            return -1;
    }
    return 0;
}

/**
 * This is a utility routine used by the other routines in the unit to handle
 * reporting pcre_exec errors. Note that *any* code passed as err_code to this
 * function will be treated as an error (even positive codes which are, by
 * definition, not errors). In other words, don't pass something unless you
 * really mean it as an error.
 *
 * The source parameter specifies a short human-readable name for the caller to
 * include in the error message (which may aid users in debugging statements
 * involving several PCRE functions).  The substring parameter indicates which
 * substring was requested (used in the case of the PCRE_ERROR_NOSUBSTRING
 * error - can be ignored otherwise).
 */
void pcre_udf_error(
    int err_code,
    char *source,
    int substring,
    SQLUDF_TRAIL_ARGS_ALL)
{
    switch (err_code) {
        case PCRE_ERROR_NOMATCH:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: no match found", source);
            break;
        case PCRE_ERROR_NULL:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: invalid NULL parameters", source);
            break;
        case PCRE_ERROR_BADOPTION:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: invalid option", source);
            break;
        case PCRE_ERROR_BADMAGIC:
        case PCRE_ERROR_UNKNOWN_OPCODE:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: invalid compiled pattern", source);
            break;
        case PCRE_ERROR_NOMEMORY:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: insufficient memory", source);
            break;
        case PCRE_ERROR_NOSUBSTRING:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: no such substring %d", source, substring);
            break;
        case PCRE_ERROR_MATCHLIMIT:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: match limit reached", source);
            break;
        case PCRE_ERROR_RECURSIONLIMIT:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: match recursion limit reached", source);
            break;
        case PCRE_ERROR_BADUTF8:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: invalid UTF-8 encoding", source);
            break;
        case PCRE_ERROR_BADUTF8_OFFSET:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: invalid UTF-8 offset", source);
            break;
        case PCRE_ERROR_BADNEWLINE:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: invalid newline value", source);
            break;
        case PCRE_ERROR_INTERNAL:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: internal error", source);
            break;
        default:
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "%s error: unknown error (%d)", source, err_code);
            break;
    }
    snprintf(SQLUDF_STATE, SQLUDF_SQLSTATE_LEN + 1, PCRE_SQLSTATE_PREFIX "%02d", -err_code);
}

/**
 * This is the implementation for the PCRE_SEARCH scalar function. See the
 * pcre_udfs.sql script for a full description of this function's purpose and
 * parameters.
 */
SQL_API_RC SQL_API_FN
pcre_udf_search(
    // input parameters
    SQLUDF_VARCHAR *pattern, SQLUDF_VARCHAR *text, SQLUDF_INTEGER *start,
    // output parameters
    SQLUDF_INTEGER *result,
    // null indicators
    SQLUDF_NULLIND *pattern_ind,  SQLUDF_NULLIND *text_ind, SQLUDF_NULLIND *start_ind,
    SQLUDF_NULLIND *result_ind,
    SQLUDF_TRAIL_ARGS_ALL)
{
    int rc;
    int group_count;
    int *groups;
    struct generic_scratch_pad *sp;

    sp = (struct generic_scratch_pad*)SQLUDF_SCRAT->data;
    *result_ind = 0;

    // Compile the pattern (if necessary)
    if (pcre_udf_init_generic(pattern, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU))
        return;

    // Search the search text. In the case of a successful search, return the
    // (1-based) position of the match in the search text. This is actually a
    // byte index, not a character index. In the case of an unsuccessful
    // search, return 0. In the case of an error, set the message and SQLSTATE
    // accordingly
    rc = pcre_fullinfo(sp->re, sp->extra, PCRE_INFO_CAPTURECOUNT, &group_count);
    if (rc != 0)
        pcre_udf_error(rc, "search", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
    else {
        group_count++; // for group 0
        groups = (int*)(*pcre_malloc)(sizeof(int) * group_count * 3);
        if (groups == NULL) {
            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_MALLOC_ERROR);
            strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_MALLOC_ERROR);
            return;
        }
        rc = pcre_exec(sp->re, sp->extra, text, strlen(text), *start - 1, 0, groups, group_count * 3);
        if (rc >= 0)
            *result = groups[0] + 1;
        else if (rc == PCRE_ERROR_NOMATCH)
            *result = 0;
        else
            pcre_udf_error(rc, "search", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
        (*pcre_free)(groups);
    }
}

/**
 * This is the implementation for the PCRE_SUB scalar function. See the
 * pcre_udfs.sql script for a full description of this function's purpose and
 * parameters.
 */
SQL_API_RC SQL_API_FN
pcre_udf_sub(
    // input parameters
    SQLUDF_VARCHAR *pattern, SQLUDF_VARCHAR *repl, SQLUDF_VARCHAR *text, SQLUDF_INTEGER *start,
    // output parameters
    SQLUDF_VARCHAR *result,
    // null indicators
    SQLUDF_NULLIND *pattern_ind, SQLUDF_NULLIND *repl_ind, SQLUDF_NULLIND *text_ind, SQLUDF_NULLIND *start_ind,
    SQLUDF_NULLIND *result_ind,
    SQLUDF_TRAIL_ARGS_ALL)
{
    int exec_rc;
    int copy_rc;
    int group;
    int group_count;
    int *groups = NULL;
    char *repl_start;
    char *repl_end;
    char *repl_scan;
    char *result_end;
    struct generic_scratch_pad *sp;

    sp = (struct generic_scratch_pad*)SQLUDF_SCRAT->data;

    // Compile the pattern (if necessary)
    if (pcre_udf_init_generic(pattern, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU))
        return;

    // Execute the search. In the case of a successful search, parse the repl
    // string and build the substituted result. In the case of an unsuccessful
    // search, return NULL.  In the case of an error, set the message and
    // SQLSTATE accordingly
    exec_rc = pcre_fullinfo(sp->re, sp->extra, PCRE_INFO_CAPTURECOUNT, &group_count);
    if (exec_rc != 0) {
        pcre_udf_error(exec_rc, "sub", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
        return;
    }
    group_count++; // for group 0
    groups = (int*)(*pcre_malloc)(sizeof(int) * group_count * 3);
    if (groups == NULL) {
        snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_MALLOC_ERROR);
        strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_MALLOC_ERROR);
        return;
    }
    exec_rc = pcre_exec(sp->re, sp->extra, text, strlen(text), *start - 1, 0, groups, group_count * 3);
    if (exec_rc > 0) {
        *result_ind = 0;
        repl_start = repl;
        repl_end = repl + strlen(repl);
        result_end = result + PCRE_MAX_STR_LEN;
        while (repl && *repl && (result < result_end)) {
            // Find the next backslash character (or the end of the template
            // string if none remain)
            repl_scan = strchr(repl, '\\');
            if (!repl_scan)
                repl_scan = repl_end;
            // Copy all characters from the current position up to the
            // backslash to the result
            if (repl_scan > repl) {
                if (result + (repl_scan - repl) > result_end) {
                    pcre_udf_error(PCRE_ERROR_NOMEMORY, "sub", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
                    goto snafu;
                }
                memcpy(result, repl, repl_scan - repl);
                result += repl_scan - repl;
                repl = repl_scan;
            }
            // If we found a backslash, intepret the following character(s) and
            // add a backslash or the matched sub-group to the result
            // accordingly
            if (*repl == '\\') {
                repl++;
                if (*repl == '\\') {
                    // Escaped backslash case
                    *result = '\\';
                    repl++;
                    result++;
                }
                else {
                    // Matched sub-group case
                    if (*repl == '\0') {
                        snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "sub error: " PCRE_MSGTX_INCOMPLETE_TEMPLATE, repl - repl_start);
                        strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_INVALID_TEMPLATE);
                        goto snafu;
                    }
                    else if ((*repl < '0') || (*repl > '9')) {
                        snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "sub error: " PCRE_MSGTX_INVALID_TEMPLATE, *repl, repl - repl_start);
                        strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_INVALID_TEMPLATE);
                        goto snafu;
                    }
                    errno = 0;
                    group = strtol(repl, &repl_scan, 10);
                    // XXX This appears broken on Linux (at least when I tested
                    // the pattern \9999999999999, strtol() quite happily
                    // converted it to LONG_MAX but didn't set errno). Still,
                    // LONG_MAX is guaranteed to cause pcre_copy_substring() to
                    // barf, so never mind
                    if (errno != 0 || group >= group_count) {
                        snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "sub error: " PCRE_MSGTX_INVALID_GROUP, repl - repl_start);
                        strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_INVALID_GROUP);
                        goto snafu;
                    }
                    if (group < exec_rc) {
                        copy_rc = pcre_copy_substring(text, groups, exec_rc, group, result, result_end - result);
                        if (copy_rc < 0) {
                            pcre_udf_error(copy_rc, "sub", group, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
                            goto snafu;
                        }
                        result += copy_rc;
                    }
                    repl = repl_scan;
                }
            }
        }
    } else if (exec_rc == 0) {
        snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, "sub error: " PCRE_MSGTX_TOO_MANY_GROUPS);
        strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_TOO_MANY_GROUPS);
    } else if (exec_rc == PCRE_ERROR_NOMATCH)
        *result_ind = -1;
    else
        pcre_udf_error(exec_rc, "sub", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
snafu:
    (*pcre_free)(groups);
    return;
}

/**
 * This is the implementation for the PCRE_GROUPS table function. See the
 * pcre_udfs.sql script for a full description of this function's purpose and
 * parameters.
 */
SQL_API_RC SQL_API_FN
pcre_udf_groups(
    // input parameters
    SQLUDF_VARCHAR *pattern, SQLUDF_VARCHAR *text,
    // output parameters
    SQLUDF_INTEGER *group, SQLUDF_INTEGER *position, SQLUDF_VARCHAR *content,
    // null indicators
    SQLUDF_NULLIND *pattern_ind, SQLUDF_NULLIND *text_ind,
    SQLUDF_NULLIND *group_ind, SQLUDF_NULLIND *position_ind, SQLUDF_NULLIND *content_ind,
    SQLUDF_TRAIL_ARGS_ALL)
{
    int rc;
    struct groups_scratch_pad *sp = NULL;

    sp = (struct groups_scratch_pad*)SQLUDF_SCRAT->data;
    switch (SQLUDF_CALLT) {
        case SQLUDF_TF_OPEN:
            // If this is the opening call, compile, study, and execute the
            // provided pattern.  If anything goes wrong with any step, fall
            // through to the closing call case to perform clean up
            sp->re = pcre_compile(pattern, PCRE_UTF8, &sp->error, &sp->error_offset, NULL);
            if (sp->re == NULL) {
                snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_COMPILE_ERROR, sp->error, sp->error_offset + 1);
                strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_COMPILE_ERROR);
            }
            else {
                sp->extra = pcre_study(sp->re, 0, &sp->error);
                if (sp->error != NULL) {
                    snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_STUDY_ERROR, sp->error);
                    strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_STUDY_ERROR);
                }
                else {
                    rc = pcre_fullinfo(sp->re, sp->extra, PCRE_INFO_CAPTURECOUNT, &sp->group_count);
                    if (rc != 0)
                        pcre_udf_error(rc, "groups", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
                    else {
                        sp->group_count++; // for group 0
                        sp->groups = (int*)(*pcre_malloc)(sizeof(int) * sp->group_count * 3);
                        if (sp->groups == NULL) {
                            snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_MALLOC_ERROR);
                            strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_MALLOC_ERROR);
                        }
                        else {
                            sp->group = 0;
                            rc = pcre_exec(sp->re, sp->extra, text, strlen(text), 0, 0, sp->groups, sp->group_count * 3);
                            if (rc >= 0) {
                                sp->group_count = rc;
                                break;
                            }
                            else if (rc == PCRE_ERROR_NOMATCH) {
                                sp->group_count = 0;
                                break;
                            }
                            else
                                pcre_udf_error(rc, "groups", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
                        }
                    }
                }
            }
        case SQLUDF_TF_CLOSE:
            // In the case of the closing call, or in the case that an error
            // occurs in the earlier case, free anything we allocated and
            // return
            (*pcre_free)(sp->re);
            sp->re = NULL;
            (*pcre_free)(sp->extra);
            sp->extra = NULL;
            (*pcre_free)(sp->groups);
            sp->groups = NULL;
            break;
        case SQLUDF_TF_FETCH:
            // In the fetch case simply find the next non-empty matched group
            // and return it's index, position, and content
            while (sp->group < sp->group_count && sp->groups[sp->group * 2] < 0)
                sp->group++;
            if (sp->group >= sp->group_count) {
                strcpy(SQLUDF_STATE, SQL_NODATA_EXCEPTION);
                break;
            }
            *group_ind = 0;
            *position_ind = 0;
            *content_ind = 0;
            *group = sp->group;
            *position = sp->groups[sp->group * 2] + 1;
            rc = pcre_copy_substring(text, sp->groups, sp->group_count, *group, content, PCRE_MAX_STR_LEN);
            if (rc < 0) {
                pcre_udf_error(rc, "groups", *group, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
                break;
            }
            sp->group++;
    }
    return;
}

/**
 * This is the implementation for the PCRE_SPLIT table function. See the
 * pcre_udfs.sql script for a full description of this function's purpose and
 * parameters.
 */
SQL_API_RC SQL_API_FN
pcre_udf_split(
    // input parameters
    SQLUDF_VARCHAR *pattern, SQLUDF_VARCHAR *text,
    // output parameters
    SQLUDF_INTEGER *element, SQLUDF_INTEGER *separator, SQLUDF_INTEGER *position, SQLUDF_VARCHAR *content,
    // null indicators
    SQLUDF_NULLIND *pattern_ind, SQLUDF_NULLIND *text_ind,
    SQLUDF_NULLIND *element_ind, SQLUDF_NULLIND *separator_ind, SQLUDF_NULLIND *position_ind, SQLUDF_NULLIND *content_ind,
    SQLUDF_TRAIL_ARGS_ALL)
{
    int rc;
    struct split_scratch_pad *sp = NULL;

    sp = (struct split_scratch_pad*)SQLUDF_SCRAT->data;

    switch (SQLUDF_CALLT) {
        case SQLUDF_TF_OPEN:
        case SQLUDF_TF_CLOSE:
            // Compile the pattern. Unlike the scalar functions, we don't call
            // init in the general case since pattern cannot change during
            // iteration of the result set
            pcre_udf_init_generic(pattern, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
            break;
        case SQLUDF_TF_FETCH:
            element_ind = 0;
            separator_ind = 0;
            position_ind = 0;
            content_ind = 0;
            *element = sp->element + 1;
            *separator = sp->separator;
            if (sp->separator) {
                sp->separator = 0;
                if (sp->start >= strlen(text))
                    strcpy(SQLUDF_STATE, SQL_NODATA_EXCEPTION);
                else {
                    *position = sp->groups[0] + 1;
                    rc = pcre_copy_substring(text, sp->groups, sp->group_count, 0, content, PCRE_MAX_STR_LEN);
                    if (rc < 0)
                        pcre_udf_error(rc, "split", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
                    else {
                        sp->start = sp->groups[1];
                        sp->element++;
                    }
                }
                (*pcre_free)(sp->groups);
                sp->groups = NULL;
            }
            else {
                sp->separator = 1;
                *position = sp->start + 1;
                rc = pcre_fullinfo(sp->re, sp->extra, PCRE_INFO_CAPTURECOUNT, &sp->group_count);
                if (rc != 0)
                    pcre_udf_error(rc, "split", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
                else {
                    sp->group_count++; // for group 0
                    sp->groups = (int*)(*pcre_malloc)(sizeof(int) * sp->group_count * 3);
                    if (sp->groups == NULL) {
                        snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_MALLOC_ERROR);
                        strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_MALLOC_ERROR);
                    }
                    else {
                        rc = pcre_exec(sp->re, sp->extra, text, strlen(text), sp->start, 0, sp->groups, sp->group_count * 3);
                        if (rc >= 0) {
                            if (sp->groups[0] == sp->groups[1]) {
                                snprintf(SQLUDF_MSGTX, SQLUDF_MSGTX_LEN, PCRE_MSGTX_EMPTY_SPLIT);
                                strcpy(SQLUDF_STATE, PCRE_SQLSTATE_PREFIX PCRE_SQLSTATE_EMPTY_SPLIT);
                            }
                            else {
                                strncpy(content, text + sp->start, sp->groups[0] - sp->start);
                                content[sp->groups[0] - sp->start] = '\0';
                                sp->start = sp->groups[0];
                            }
                        }
                        else if (rc == PCRE_ERROR_NOMATCH) {
                            strcpy(content, text + sp->start);
                            sp->start = strlen(text);
                        }
                        else
                            pcre_udf_error(rc, "split", 0, SQLUDF_TRAIL_ARGS_ALL_PASSTHRU);
                    }
                }
            }
            break;
    }
    return;
}

/*
int main(int argc, char *argv[]) {
    char state[6] = "00000";
    char msg[SQLUDF_MSGTX_LEN + 1] = "";
    char *pattern = ",?";
    char *text = "a,b,c";
    int separator;
    int position;
    char *content = "";
    void *pad;
    SQLUDF_NULLIND pattern_ind = 0;
    SQLUDF_NULLIND text_ind = 0;
    SQLUDF_NULLIND separator_ind = 0;
    SQLUDF_NULLIND position_ind = 0;
    SQLUDF_NULLIND content_ind = 0;
    int calltype = 0;

    pad = malloc(100);
    memset(pad, 0, 100);
    content = (char*)malloc(4000);

    calltype = SQLUDF_TF_OPEN;
    pcre_udf_split(
            pattern, text, &separator, &position, content,
            &pattern_ind, &text_ind, &separator_ind, &position_ind, &content_ind,
            state, "foo", "foo", msg, pad, &calltype);
    printf("state=%s\n", state);
    printf("msg=%s\n", msg);
    while (!strcmp(state, "00000")) {
        calltype = SQLUDF_TF_FETCH;
        pcre_udf_split(
                pattern, text, &separator, &position, content,
                &pattern_ind, &text_ind, &separator_ind, &position_ind, &content_ind,
                state, "foo", "foo", msg, pad, &calltype);
        printf("--------------------\n");
        printf("state=%s\n", state);
        printf("msg=%s\n", msg);
        printf("separator=%d\n", separator);
        printf("position=%d\n", position);
        printf("content_ind=%d\n", content_ind);
        printf("content=%s\n", content);
    }
    calltype = SQLUDF_TF_CLOSE;
    pcre_udf_split(
            pattern, text, &separator, &position, content,
            &pattern_ind, &text_ind, &separator_ind, &position_ind, &content_ind,
            state, "foo", "foo", msg, pad, &calltype);
    free(pad);
    free(content);
    return 0;
}
*/

/* vim: set et sw=4 sts=4: */
