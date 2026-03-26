#!/bin/sh

echo "Running post-start setup..."

# Start code-server if not already running
if ! pgrep -f "code-server" > /dev/null; then
    echo "Starting code-server..."
    # Wait for code-server binary (may still be installing from post_create)
    for i in $(seq 1 30); do
        if command -v code-server > /dev/null 2>&1; then
            nohup code-server --auth none --port 13337 --host 0.0.0.0 > /tmp/code-server.log 2>&1 &
            sleep 2
            if pgrep -f "code-server" > /dev/null; then
                echo "  code-server running on port 13337"
            else
                echo "  Warning: code-server failed to start. Check /tmp/code-server.log"
            fi
            break
        fi
        echo "  Waiting for code-server binary... ($i/30)"
        sleep 2
    done
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

# Start pgweb (PostgreSQL Admin) if not already running
if ! pgrep -f "pgweb" > /dev/null; then
    if command -v pgweb > /dev/null 2>&1; then
        echo "Waiting for PostgreSQL..."
        for i in $(seq 1 20); do
            if pg_isready -h 127.0.0.1 -p 5432 -q 2>/dev/null || nc -z 127.0.0.1 5432 2>/dev/null; then
                echo "Starting pgweb..."
                /usr/local/bin/pgadmin-entrypoint || true
                break
            fi
            sleep 2
        done
    fi
fi

# Start Mailpit if not already running
if ! pgrep -f "mailpit" > /dev/null; then
    echo "Starting Mailpit..."
    if [ -f /usr/local/bin/mailpit-entrypoint ]; then
        /usr/local/bin/mailpit-entrypoint || true
    fi
fi

echo "Post-start setup complete!"
