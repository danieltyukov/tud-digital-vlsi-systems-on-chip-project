#!/bin/bash
# Run a command on the ET4351 server via SSH
# Usage: ./ssh_cmd.sh "command to run"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CRED_FILE="$PROJECT_ROOT/credentials.txt"

SERVER="et4351.ewi.tudelft.nl"
USERNAME="datyukov"
PASSWORD=$(grep '^password:' "$CRED_FILE" | sed 's/^password: //')

sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$SERVER" "$1"
