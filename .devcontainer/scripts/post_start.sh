#!/bin/sh

echo "Running post-start setup..."

# Start code-server if not already running
if ! pgrep -f "code-server" > /dev/null; then
    echo "Starting code-server..."
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
if ! pgrep -f "pgweb" > /dev/null && command -v pgweb > /dev/null 2>&1; then
    echo "Waiting for PostgreSQL..."
    for i in $(seq 1 30); do
        if nc -z 127.0.0.1 5432 2>/dev/null; then
            echo "  PostgreSQL ready"
            if [ -f /usr/local/bin/pgadmin-entrypoint ]; then
                /usr/local/bin/pgadmin-entrypoint || true
            else
                # Fallback: start pgweb directly
                PG_NAME="${PG_NAME:-${DB_NAME:-devcontainer_db}}"
                nohup pgweb --bind 0.0.0.0 --listen 8082 --host 127.0.0.1 --port 5432 --user "${PG_USER:-postgres}" --pass "${PG_PASSWORD:-postgres}" --db "$PG_NAME" --ssl disable > /tmp/pgweb.log 2>&1 &
                echo "  pgweb started on port 8082"
            fi
            break
        fi
        echo "  Waiting for PostgreSQL... ($i/30)"
        sleep 2
    done
fi

# Start Mailpit if not already running
if ! pgrep -f "mailpit" > /dev/null && command -v mailpit > /dev/null 2>&1; then
    echo "Starting Mailpit..."
    if [ -f /usr/local/bin/mailpit-entrypoint ]; then
        /usr/local/bin/mailpit-entrypoint || true
    else
        # Fallback: start mailpit directly
        nohup mailpit --smtp 0.0.0.0:1025 --listen 0.0.0.0:8025 --webroot / > /tmp/mailpit.log 2>&1 &
        echo "  Mailpit started (SMTP: 1025, UI: 8025)"
    fi
fi

echo "Post-start setup complete!"
