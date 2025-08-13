# Executive Summary: Socket EOF Bug Discovery and Fix

## Problem Statement
Production TACACS+ servers experiencing extremely high CPU usage (40-60% per process) with system load averages exceeding 30 on 16-core systems. Processes were getting stuck in infinite loops, holding TCP connections in CLOSE-WAIT state for hours.

## Discovery Process

### 1. Initial Symptoms Observed
```bash
# Check system load
uptime
# Output: load average: 32.45, 31.89, 30.12

# Identify high CPU processes
top -b -n 1 | grep tac_plus
# Multiple processes showing 40-60% CPU usage

# Check socket states
ss -tn state close-wait '( sport = :49 )' 
# CLOSE-WAIT  0  0  10.235.34.40:49  10.233.132.12:38648  timer:(keepalive,119min,0)
```

### 2. Process Behavior Analysis
```bash
# Trace system calls on stuck process
strace -p <PID>
# Output showed infinite loop:
# recvfrom(24, "", 12, 0, NULL, NULL) = 0  # Returns 0 indicating EOF
# recvfrom(24, "", 12, 0, NULL, NULL) = 0  # Repeats infinitely
# recvfrom(24, "", 12, 0, NULL, NULL) = 0
```

### 3. Code Investigation Commands
```bash
# Search for recv/recvfrom calls in codebase
grep -r "recv\(" --include="*.c" .
grep -r "recvfrom\(" --include="*.c" .

# Found main socket handling in:
# - tac_plus-ng/main.c (recv_inject function)
# - tac_plus-ng/packet.c (tac_read and rad_read functions)

# Check for EOF handling
grep -r "len == 0" --include="*.c" .
# No results - confirmed missing EOF checks
```

## Root Cause Analysis

### The Bug Location
File: `tac_plus-ng/main.c`, line 1526 in `recv_inject()` function:
```c
ssize_t res = recv(ctx->sock, buf, len, flags);
return (!res && len) ? -1 : res;  // BUG: Converts EOF (0) to error (-1)
```

### Why It Caused Infinite Loops
1. When remote peer closes connection, `recv()` returns 0 (EOF)
2. `recv_inject()` converts 0 to -1 (making it look like an error)
3. Calling code checks if return < 0 and errno != EAGAIN
4. Since `recv()` doesn't set errno on EOF, errno retains EAGAIN from previous operations
5. Code skips cleanup and returns to event loop
6. Socket remains readable (EOF condition persists)
7. Event loop immediately calls read handler again → infinite loop

## The Fix

### Code Changes Applied
```bash
# Files modified
git diff --stat
# tac_plus-ng/main.c   | 10 +++++++---
# tac_plus-ng/packet.c | 24 ++++++++++++++++++++++++
# 2 files changed, 31 insertions(+), 3 deletions(-)
```

### Key Modifications
1. **main.c**: Removed EOF-to-error conversion, now returns recv() result directly
2. **packet.c**: Added explicit EOF checks (len == 0) in all four recv_inject() call sites
3. When EOF detected, triggers proper connection cleanup

## Verification Commands
```bash
# After applying fix and recompiling:

# Test with intentional connection drops
nc -w1 localhost 49 < /dev/null

# Monitor for stuck processes
watch 'ps aux | grep tac_plus | grep -v grep'

# Check for CLOSE-WAIT sockets
watch 'ss -tn state close-wait | grep ":49"'

# Trace to confirm no infinite loops
strace -p <PID> -e trace=network
```

## Impact
- Eliminates CPU spinning on closed connections
- Prevents CLOSE-WAIT socket accumulation
- Reduces system load from 30+ to normal levels
- Fixes both single-connection=yes and single-connection=no modes

## Additional Findings
- tacplus-ng has built-in HAProxy support for production deployments
- HAProxy can provide connection management and load balancing
- However, the EOF bug needed fixing at the application level regardless of proxy usage

## Commit Information
```bash
git log --oneline -1
# c8b408a Fix socket EOF handling bug causing infinite CPU loops
```