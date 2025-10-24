#!/bin/bash

# System performance monitoring script
# Run this to identify what's causing slowdowns when they occur

echo "🖥️  SYSTEM PERFORMANCE MONITOR"
echo "================================"

# Check load average
echo "📊 Load Average:"
uptime

# Check top CPU consumers
echo -e "\n🔥 Top CPU Consumers:"
ps aux | sort -k3 -nr | head -10 | awk '{printf "%-8s %-6s %-8s %s\n", $2, $3"%", $4"%", substr($0, index($0,$11))}'

# Check memory usage
echo -e "\n💾 Memory Usage:"
vm_stat | grep -E "(free|inactive|wired|compressed)" | awk '{print $1 " " $3}' | sed 's/://g'

# Check for corporate services consuming resources
echo -e "\n🏢 Corporate Services Status:"
for service in "tanium" "cyberark" "observiq" "palo"; do
    count=$(ps aux | grep -i "$service" | grep -v grep | wc -l)
    if [ $count -gt 0 ]; then
        echo "$service: $count processes running"
        ps aux | grep -i "$service" | grep -v grep | awk '{printf "  PID %-6s CPU %-6s MEM %-6s %s\n", $2, $3"%", $4"%", substr($0, index($0,$11))}'
    fi
done

# Check for stuck/problematic processes
echo -e "\n⚠️  Potentially Problematic Processes:"
ps aux | awk '$3 > 10.0 {printf "HIGH CPU: PID %-6s CPU %-6s %s\n", $2, $3"%", substr($0, index($0,$11))}'
ps aux | awk '$4 > 5.0 {printf "HIGH MEM: PID %-6s MEM %-6s %s\n", $2, $4"%", substr($0, index($0,$11))}'

# Check recent errors in system logs
echo -e "\n🚨 Recent System Errors (last 10 minutes):"
log show --last 10m --predicate 'eventType == activityCreateEvent OR eventType == logEvent' | grep -i -E "(error|fail|crash)" | tail -5

# Check WindowServer specifically (common culprit)
windowserver_cpu=$(ps aux | grep WindowServer | grep -v grep | awk '{print $3}' | head -1)
echo -e "\n🪟 WindowServer CPU Usage: $windowserver_cpu%"
if (( $(echo "$windowserver_cpu > 20" | bc -l) )); then
    echo "   ⚠️  WindowServer is using high CPU - consider restarting GUI"
fi

echo -e "\n💡 Run ~/dots/utils/clean.sh to attempt cleanup"
