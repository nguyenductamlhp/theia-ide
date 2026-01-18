#!/bin/bash
set -e

# Ensure theia user owns home directory
if [ -w /home/theia ]; then
    echo "Fixing permissions for /home/theia..."
    chmod -R 755 /home/theia 2>/dev/null || true
fi

# Execute the main command as theia user
exec "$@"
