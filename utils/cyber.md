# CyberArk EPM Performance Analysis

## Analysis Date

August 13, 2025

## Quick Diagnostic Commands

**Run these commands to get real-time CyberArk performance data:**

```bash
# 1. Check current CyberArk processes and CPU usage
ps aux | grep -i cyberark | grep -v grep

# 2. Monitor recent security errors
log show --last 30m --predicate 'eventMessage contains "MacOS error: -67062"' | head -10

# 3. See process interception delays
log show --last 1h --predicate 'process contains "cyberark"' | grep -i "decision time" | head -10

# 4. Check system load and top CPU consumers
uptime && ps aux | sort -k3 -nr | head -10

# 5. View CyberArk system extensions
systemextensionsctl list | grep -i cyberark

# 6. Check what files CyberArk has locked
sudo lsof -p 342 | head -20
```

## Overview

CyberArk EPM (Endpoint Privilege Manager) is causing significant performance degradation on this corporate development machine through excessive process monitoring and security validation overhead.

## What CyberArk EPM Does

CyberArk EPM is a **privileged access management** and **application control** solution that:

- Monitors and controls process execution (every `exec` call)
- Validates digital signatures and certificates
- Enforces privilege elevation policies
- Logs all security-relevant events
- Performs real-time threat analysis

## Key Failing Components

### 1. Security Framework Errors (Error -67062)

**Command to diagnose:**

```bash
# Check for recurring security errors
log show --last 30m --predicate 'eventMessage contains "MacOS error: -67062"' | head -10
```

- **MacOS Error -67062** = `errSecInvalidTrustSettings`
- Occurs **every 15 seconds** consistently
- Related to trust chain validation failures
- Indicates certificate/signature validation issues

### 2. Process Monitoring Overhead

**Command to diagnose:**

```bash
# Monitor CyberArk process interceptions and decision times
log show --last 1h --predicate 'process contains "cyberark" OR process contains "CyberArk"' --info --debug | head -30
```

- Intercepts **every** process execution (`exec` calls)
- Decision times ranging from **0.001 to 6 seconds** per process
- Heavy signature verification (`SecKeyVerifySignature`, `SecTrustEvaluateIfNecessary`)

## Resource Locks & Performance Impact

### File System Locks

**Command to diagnose:**

```bash
# Check what files CyberArk has open
sudo lsof -p 342 | head -20

# View CyberArk data files
sudo ls -la "/Library/Application Support/CyberArk/Data/"
```

```text
AuditEvents.networkAccess     (12KB - constantly written)
AuditEvents.policyUsage       (12KB - constantly written)
AuditEvents.restrictedAccess  (12KB - constantly written)
AuditEvents.inbox            (20KB - audit queue)
Data_v2                      (240KB - main policy database)
```

### Memory Usage

**Command to diagnose:**

```bash
# Check memory usage of CyberArk processes
ps aux | grep -i cyberark | grep -v grep
```

- Main process: **293MB** resident memory
- Multiple system extensions running simultaneously
- Heavy crypto operations for signature validation

### CPU Bottlenecks

**Command to diagnose:**

```bash
# Check CPU usage sorted by consumption
ps aux | sort -k3 -nr | head -20

# Monitor top CPU consumers real-time
top -l 1 -n 10 -o cpu
```

- **Every shell command** gets intercepted
- Examples from logs:
  - `docker` commands: 1.9-6 second delays
  - `tmux` commands: intercepted and validated
  - Even `bash`/`sh` calls are monitored

## Why Your System Slows Down

### 1. Development Workflow Impact

- Every `git`, `docker`, `npm`, `brew` command gets validated
- VS Code plugin executions are monitored
- Shell scripts trigger multiple policy lookups

### 2. Cascading Effects

- Trust validation failures create retry loops
- Policy database locks during heavy development activity
- Audit logging creates disk I/O pressure

### 3. "No Policy Found" Messages

These indicate:

- CyberArk is blocking/delaying execution while checking policies
- Your development tools aren't pre-approved in the corporate policy
- Each new process triggers a full security evaluation

## Specific Problematic Patterns

These activities cause the most CyberArk overhead:

- VS Code launching multiple helper processes
- Docker commands (4-6 second delays observed)
- Homebrew installations/updates
- Git operations with multiple subprocesses
- Shell scripts that spawn multiple processes

## Current Process Status

**Command to diagnose:**

```bash
# Get detailed CyberArk process information
ps aux | grep -i cyberark | grep -v grep

# Check system extensions
systemextensionsctl list | grep -i cyberark

# Check launch services
sudo launchctl list | grep -i cyberark
```

From `ps aux` analysis:

```text
PID   %CPU  %MEM  COMMAND
342   7.0   0.8   com.cyberark.CyberArkEPMEndpointSecurityExtension (main process)
324   0.0   0.0   com.cyberark.CyberArkEPMNetworkExtension
401   0.0   0.1   com.cyberark.CyberArkEPMNetworkSession
479   0.0   0.1   CyberArk EPM Agent
568   0.0   0.1   CyberArkEPMFinderExtension
```

## Log Evidence

**Command to diagnose:**

```bash
# Get recent CyberArk activity logs
log show --last 1h --predicate 'process contains "cyberark" OR process contains "CyberArk"' | grep -i -E "(decision time|try to exec)" | head -10

# Check for recent system errors
log show --last 2h --predicate 'eventType == activityCreateEvent OR eventType == logEvent' --info --debug | grep -i -E "(error|fail|crash|timeout|slow)" | head -20
```

Sample log entries showing the performance impact:

```text
2025-08-13 09:31:30.409687-0700: Process '/Applications/Visual Studio Code' try to exec '/opt/homebrew/Cellar/docker/28.3.3/bin/docker' - decision time 1.964247 seconds, no policy found

2025-08-13 09:31:36.424479-0700: Process 'Code - Insiders Helper' try to exec 'docker' - decision time 3.994961 seconds, no policy found

2025-08-13 09:31:44.444155-0700: Process 'Code - Insiders Helper' try to exec 'docker' - decision time 5.966698 seconds, no policy found
```

## Recommendations

### Request IT Policy Updates

- Pre-approve development tools (`docker`, `git`, `homebrew`, etc.)
- Exclude development directories from real-time scanning
- Configure policy caching for trusted developer tools

### Work with IT to

- Investigate the recurring `-67062` trust validation errors
- Optimize policy lookup performance
- Consider development machine exemptions

### Immediate Workarounds

- Batch operations instead of frequent small commands
- Use containerized development environments
- Minimize shell script complexity during heavy CyberArk activity
- Run cleanup scripts during high-activity periods

## Root Cause

The core issue is that CyberArk treats your development machine like a high-security server, applying enterprise-grade process monitoring to every command, which creates significant overhead for developer workflows.

## Cleanup Script Integration

The existing cleanup scripts (`obs.sh`, `tan.sh`) help by stopping some corporate services, but CyberArk EPM cannot be safely stopped as it's a critical security component. Focus should be on policy optimization and working with IT for developer-friendly configurations.

## Options for Disabling CyberArk EPM

### ⚠️ **IMPORTANT WARNING**

CyberArk EPM is enterprise security software that is likely **required by corporate policy**. Attempting to disable it may:

- Violate company security policies
- Trigger security alerts to IT/Security teams  
- Result in disciplinary action
- Leave the system non-compliant with corporate standards

### Technical Architecture (Why It's Hard to Disable)

**Command to diagnose:**

```bash
# List active system extensions
systemextensionsctl list | grep -i cyberark

# Check launch services
sudo launchctl list | grep -i cyberark

# Check installation package info
sudo pkgutil --pkg-info com.cyberark.CyberArkEPM

# Check application structure
ls -la "/Applications/CyberArk EPM.app/Contents/"
```

CyberArk EPM uses **System Extensions** (the modern replacement for kernel extensions):

```text
System Extensions (Active):
- com.cyberark.CyberArkEPMEndpointSecurityExtension (PID 342)
- com.cyberark.CyberArkEPMNetworkExtension (PID 324)

Launch Services:
- DF8U2CCCD8.com.cyberark.CyberArkEPMEndpointSecurityExtension
- com.cyberark.CyberArkEPMNetworkSession  
- NetworkExtension.com.cyberark.CyberArkEPMNetworkExtension.24.10.0.471

Installation Package: com.cyberark.CyberArkEPM v24.1.0
```

### Why Standard Disabling Methods Won't Work

1. **System Extensions Protection**: Modern macOS protects system extensions from being easily disabled
2. **SIP Protection**: System Integrity Protection prevents tampering with security extensions
3. **Enterprise Management**: Likely managed by corporate MDM that will reinstall/re-enable
4. **Tamper Detection**: CyberArk itself monitors for tampering attempts

### Theoretical Disabling Methods (NOT RECOMMENDED)

#### 1. System Extension Deactivation

```bash
# This will likely fail or trigger alerts
sudo systemextensionsctl deactivate DF8U2CCCD8 com.cyberark.CyberArkEPMEndpointSecurityExtension
sudo systemextensionsctl deactivate DF8U2CCCD8 com.cyberark.CyberArkEPMNetworkExtension
```

#### 2. Application Removal

```bash
# Will likely be reinstalled by corporate management
sudo rm -rf "/Applications/CyberArk EPM.app"
sudo rm -rf "/Library/Application Support/CyberArk/"
```

#### 3. Process Termination (Temporary Only)

```bash
# Will restart automatically, may trigger alerts
sudo kill -9 342  # Main security extension
sudo kill -9 324  # Network extension
sudo kill -9 401  # Network session
```

### Better Alternatives

#### 1. Work with IT Department

- **Request developer exemptions** for specific directories (`~/dev`, `~/work`)
- **Ask for policy tuning** to cache decisions for approved tools
- **Request whitelisting** of development tools (docker, git, homebrew)
- **Negotiate scheduled scanning** instead of real-time monitoring

#### 2. Use CyberArk's Built-in Features

- Check if CyberArk has a **"developer mode"** or **"reduced monitoring"** setting
- Look for **application-specific policies** that can be relaxed
- See if there are **time-based policies** (e.g., reduced monitoring during work hours)

#### 3. Development Environment Isolation

- Use **remote development** (SSH to a non-monitored server)
- Leverage **containerized development** (Docker Desktop with pre-approved images)
- Consider **virtual machines** for development work
- Use **cloud-based IDEs** (VS Code Server, GitHub Codespaces)

### Monitoring Detection

If you attempt to disable CyberArk, expect:

- **Immediate alerts** to security team
- **Audit logs** of tampering attempts  
- **Automatic re-installation** via MDM
- **Potential policy violations**

### Recommended Approach

1. **Document the performance impact** (this analysis helps)
2. **Quantify productivity loss** (time lost to delays)
3. **Present business case** to IT for developer-specific policies
4. **Propose compromise solutions** (scheduled scanning, directory exclusions)
5. **Work within corporate frameworks** rather than around them
