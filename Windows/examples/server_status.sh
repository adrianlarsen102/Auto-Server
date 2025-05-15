#!/bin/bash

REMOTE_USER="sysadmin"
REMOTE_HOST="targetserver.dystopia.local"

echo "=== SYSTEM STATUS FROM $REMOTE_HOST ==="

ssh $REMOTE_USER@$REMOTE_HOST bash << 'EOF'
echo "-- CPU Usage --"
top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "% used"}'
echo ""

echo "-- Memory Usage --"
free -h
echo ""

echo "-- Disk Usage --"
df -h | grep '^/dev'
echo ""

echo "-- Uptime --"
uptime -p
EOF