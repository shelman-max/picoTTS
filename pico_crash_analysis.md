# PicoTTS Android 15 Crash Analysis and Fix

## Problem Description
The PicoTTS library is experiencing a native crash (SIGSEGV) when integrated into AOSP Android 15. The crash occurs in the `picobase_get_next_utf8char` function with the following stack trace:

```
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Build fingerprint: 'ATT/U656AA/U656AA:15/AP3A.240905.015.A2/1752313756:userdebug/release-keys'
ABI: 'arm'
Process uptime: 8s
Cmdline: com.svox.pico
pid: 5406, tid: 5422, name: SynthThread  >>> com.svox.pico <<<
signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x5f99d67c

#00 pc 00012772  /system/lib/libttspico.so (picobase_get_next_utf8char+10)
#01 pc 0001b315  /system/lib/libttspico.so (pr_processToken+796)
```

## Root Cause Analysis

### Location of Crash
The crash occurs at line 963 in `pico/lib/picobase.c`:

```c
picoos_uint8 picobase_get_next_utf8char(const picoos_uint8 *utf8s,
                                        const picoos_uint32 utf8slenmax,
                                        picoos_uint32 *pos,
                                        picobase_utf8char utf8char) {
    // ...
    len = picobase_det_utf8_length(utf8s[*pos]);  // <- CRASH HERE (line 963)
    // ...
}
```

### Analysis of Crash Data
- **Fault Address**: `0x5f99d67c` 
- **Register r0**: `5f99d67c` (same as fault address)
- **Register r8**: `5f99d67c` (likely contains computed address `utf8s + (*pos)`)

This indicates that either:
1. `utf8s` is NULL or points to invalid memory
2. `*pos` contains an invalid/large value causing memory access outside valid bounds
3. The computed address `utf8s + (*pos)` results in invalid memory access

### Call Chain
The crash occurs in the following call sequence:
1. `tok_tokenDigitStrToInt` (line 633 in `picopr.c`)
2. `picobase_get_next_utf8char` (line 963 in `picobase.c`)

### Missing Validation
The `picobase_get_next_utf8char` function lacks proper input validation:
- No NULL check for `utf8s` parameter
- No NULL check for `pos` parameter  
- No bounds checking before accessing `utf8s[*pos]`

## Android 15 Specific Issues

The Android 15 build configuration includes stricter compiler flags:
```make
LOCAL_CFLAGS += \
    -Wall -Werror \
    -Wno-error=infinite-recursion \
    ...
```

This may expose existing memory safety issues that were previously hidden due to:
- Compiler optimizations
- Different memory layout
- Stricter runtime checks

## Solution

### Primary Fix: Add Input Validation to picobase_get_next_utf8char

Add proper null pointer and bounds checking to prevent the crash:

```c
picoos_uint8 picobase_get_next_utf8char(const picoos_uint8 *utf8s,
                                        const picoos_uint32 utf8slenmax,
                                        picoos_uint32 *pos,
                                        picobase_utf8char utf8char) {
    picoos_uint8 i;
    picoos_uint8 len;
    picoos_uint32 poscnt;

    // Add input validation
    if (utf8s == NULL || pos == NULL || utf8char == NULL) {
        if (utf8char != NULL) utf8char[0] = 0;
        return FALSE;
    }
    
    // Check bounds before accessing utf8s[*pos]
    if (*pos >= utf8slenmax) {
        utf8char[0] = 0;
        return FALSE;
    }

    utf8char[0] = 0;
    len = picobase_det_utf8_length(utf8s[*pos]);
    if ((((*pos) + len) > utf8slenmax) ||
        (len > PICOBASE_UTF8_MAXLEN)) {
        return FALSE;
    }

    poscnt = *pos;
    i = 0;
    while ((i < len) && (utf8s[poscnt] != 0)) {
        utf8char[i] = utf8s[poscnt];
        poscnt++;
        i++;
    }
    utf8char[i] = 0;
    if ((i < len) && (utf8s[poscnt] == 0)) {
        return FALSE;
    }
    *pos = poscnt;
    return TRUE;
}
```

### Secondary Fix: Add Validation to Calling Functions

Also add validation in `tok_tokenDigitStrToInt` to catch issues earlier:

```c
static picoos_int32 tok_tokenDigitStrToInt (picodata_ProcessingUnit this, pr_subobj_t * pr, picoos_uchar stokenStr[])
{
    picoos_uint32 i;
    picoos_uint32 l;
    picoos_int32 id;
    picoos_int32 val;
    picoos_uint32 n;
    picobase_utf8char utf8char;

    // Add null check
    if (stokenStr == NULL) {
        return 0;
    }

    val = 0;
    i = 0;
    l = pr_strlen(stokenStr);
    while (i < l) {
        if (!picobase_get_next_utf8char(stokenStr, PR_MAX_DATA_LEN, &i, utf8char)) {
            // Handle error case - break out of loop on failure
            break;
        }
        // ... rest of function unchanged
    }
    return val;
}
```

## Implementation Details

### Constants Used
- `PR_MAX_DATA_LEN` = `IN_BUF_SIZE` = 255
- `PICOBASE_UTF8_MAXLEN` (needs to be verified from headers)

### Function Behavior Changes
1. **picobase_get_next_utf8char**: Now returns FALSE for invalid inputs instead of crashing
2. **tok_tokenDigitStrToInt**: Now handles invalid UTF-8 parsing gracefully

## Testing Recommendations

1. **Null Pointer Tests**: Test with NULL parameters
2. **Boundary Tests**: Test with invalid position values
3. **UTF-8 Edge Cases**: Test with malformed UTF-8 sequences
4. **Memory Safety**: Run with AddressSanitizer/Valgrind if available
5. **Integration Testing**: Test full TTS synthesis pipeline

## Risk Assessment

**Low Risk**: The fixes add defensive programming without changing core functionality. The changes:
- Only add validation that should have been there originally
- Maintain backward compatibility for valid inputs
- Gracefully handle invalid inputs instead of crashing
- Follow existing error handling patterns in the codebase

---

## UPDATE: Additional Crash Analysis (July 14, 2025)

### New Crash Information
A new crash has been reported with slightly different characteristics:

```
07-14 15:46:17.445  4983  4983 F DEBUG   : signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x607dd69c
07-14 15:46:17.445  4983  4983 F DEBUG   :     r0  607dd69c  r1  000000ff  r2  e07d60f4  r3  e07d60f8
07-14 15:46:17.445  4983  4983 F DEBUG   :       #00 pc 00012782  /system/lib/libttspico.so (picobase_get_next_utf8char+26)
07-14 15:46:17.445  4983  4983 F DEBUG   :       #01 pc 0001b34d  /system/lib/libttspico.so (pr_processToken+796)
```

### Key Differences from Previous Crash
1. **Crash Offset**: Now at `+26` instead of `+10`
2. **Fault Address**: `0x607dd69c` (different from previous `0x5f99d67c`)
3. **Same Call Stack**: Still in `pr_processToken` → `picobase_get_next_utf8char`

### Analysis of New Crash
The change from `+10` to `+26` offset suggests that the initial input validation fixes are working (the function is getting past the early validation checks), but the crash is now occurring later in the function, likely in the character copying loop:

```c
while ((i < len) && (utf8s[poscnt] != 0)) {
    utf8char[i] = utf8s[poscnt];  // <- POTENTIAL CRASH LOCATION
    poscnt++;
    i++;
}
```

### Enhanced Fix Required
The current fix may be incomplete. We need to add additional bounds checking within the loop to prevent `poscnt` from exceeding `utf8slenmax`:

```c
picoos_uint8 picobase_get_next_utf8char(const picoos_uint8 *utf8s,
                                        const picoos_uint32 utf8slenmax,
                                        picoos_uint32 *pos,
                                        picobase_utf8char utf8char) {
    picoos_uint8 i;
    picoos_uint8 len;
    picoos_uint32 poscnt;

    /* Enhanced input validation */
    if (utf8s == NULL || pos == NULL || utf8char == NULL) {
        if (utf8char != NULL) utf8char[0] = 0;
        return FALSE;
    }
    
    /* Check bounds before accessing utf8s[*pos] */
    if (*pos >= utf8slenmax) {
        utf8char[0] = 0;
        return FALSE;
    }

    utf8char[0] = 0;
    len = picobase_det_utf8_length(utf8s[*pos]);
    if ((((*pos) + len) > utf8slenmax) ||
        (len > PICOBASE_UTF8_MAXLEN) ||
        (len == 0)) {  /* Additional check for invalid UTF-8 */
        return FALSE;
    }

    poscnt = *pos;
    i = 0;
    /* Enhanced loop with bounds checking */
    while ((i < len) && (poscnt < utf8slenmax) && (utf8s[poscnt] != 0)) {
        utf8char[i] = utf8s[poscnt];
        poscnt++;
        i++;
    }
    
    utf8char[i] = 0;
    
    /* Check if we completed the character successfully */
    if (i < len) {
        return FALSE;  /* Incomplete character */
    }
    
    *pos = poscnt;
    return TRUE;
}
```

### Additional Recommendations

1. **Memory Corruption Investigation**: The different fault addresses suggest possible memory corruption issues elsewhere in the codebase that are affecting the input data.

2. **Input Data Validation**: Add logging or debugging to track what kind of input data is being passed to `picobase_get_next_utf8char` when crashes occur.

3. **Defensive Programming**: Consider adding more defensive checks in the calling functions to validate string integrity before passing to UTF-8 parsing functions.

4. **Runtime Debugging**: Use tools like AddressSanitizer or Valgrind to detect memory corruption issues during development.

### Priority Actions

1. **Immediate**: Apply the enhanced bounds checking fix above
2. **Short-term**: Add comprehensive input validation logging 
3. **Medium-term**: Investigate potential memory corruption in calling code
4. **Long-term**: Consider refactoring UTF-8 handling to use safer string handling libraries