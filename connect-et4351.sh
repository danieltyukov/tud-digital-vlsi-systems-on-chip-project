#!/bin/bash
# ET4351 - Connect to TU Delft Digital IC Design server
# SSH with X11 forwarding for GUI applications (QuestaSim, etc.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="$SCRIPT_DIR/credentials.txt"

SERVER="et4351.ewi.tudelft.nl"
USERNAME="datyukov"
PASSWORD=$(grep '^password:' "$CRED_FILE" | sed 's/^password: //')

echo "Connecting to ET4351 server ($SERVER) as $USERNAME..."
echo "X11 forwarding enabled for GUI applications."
echo ""

sshpass -p "$PASSWORD" ssh -X -o StrictHostKeyChecking=no "$USERNAME@$SERVER"
