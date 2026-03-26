#!/bin/sh

echo "Running post-start setup..."

# Start code-server if not already running
if ! pgrep -f "code-server" > /dev/null; then
    echo "Starting code-server..."
    if command -v code-server > /dev/null 2>&1; then
        nohup code-server --auth none --port 13337 --host 0.0.0.0 > /tmp/code-server.log 2>&1 &
    fi
fi

# Start filebrowser if not already running
if ! pgrep -f "filebrowser" > /dev/null; then
    echo "Starting filebrowser..."
    if [ -f /usr/local/bin/filebrowser-entrypoint ]; then
        /usr/local/bin/filebrowser-entrypoint || true
    fi
fi

# Start phpMyAdmin if not already running
if ! pgrep -f "php.*phpmyadmin" > /dev/null; then
    echo "Starting phpMyAdmin..."
    if [ -f /usr/local/bin/phpmyadmin-entrypoint ]; then
        /usr/local/bin/phpmyadmin-entrypoint || true
    fi
fi

echo "Post-start setup complete!"
