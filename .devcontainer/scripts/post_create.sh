#!/bin/bash

set -e

echo "Running post-create setup..."

# Wait for DNS/network to be ready (network_mode: service:db may delay resolution)
echo "Waiting for network..."
for i in $(seq 1 30); do
    if getent hosts github.com > /dev/null 2>&1; then
        echo "  Network ready"
        break
    fi
    echo "  Waiting for DNS... ($i/30)"
    sleep 2
done

# Remove stale yarn repo (expired GPG key breaks apt-get update)
sudo rm -f /etc/apt/sources.list.d/yarn.list

# Helper: apt-get install with retries for flaky Coder network
apt_install_retry() {
    local max=3
    for attempt in $(seq 1 $max); do
        echo "  apt-get install attempt $attempt/$max..."
        if sudo apt-get install -y --no-install-recommends --fix-missing "$@"; then
            return 0
        fi
        echo "  Retrying after failure..."
        sleep 5
        sudo apt-get update
    done
    echo "ERROR: apt-get install failed after $max attempts"
    return 1
}

# Install system packages (non-fatal — Coder network can be flaky)
echo "Installing system packages..."
sudo apt-get update 2>/dev/null
apt_install_retry mariadb-client || echo "Warning: mariadb-client install failed (network issue). Install manually later: sudo apt-get install mariadb-client"

echo "PHP version: $(php -v | head -1)"

# Ensure nvm and Node.js are available
export NVM_DIR="${HOME}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "/usr/local/share/nvm/nvm.sh" ] && \. "/usr/local/share/nvm/nvm.sh"

# Get database credentials from environment (set by docker-compose from .devcontainer/.env)
DB_NAME="${DB_NAME:-devdb}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-mariadb}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"

echo "Database available: $DB_NAME @ $DB_HOST:$DB_PORT"

# Generate root .env file from .env.example with actual credentials
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    sed -i -E "s/^DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
    sed -i -E "s/^DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
    sed -i -E "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
    sed -i -E "s/^DB_HOST=.*/DB_HOST=$DB_HOST/" .env
    sed -i -E "s/^DB_PORT=.*/DB_PORT=$DB_PORT/" .env
    echo ".env configured with DB and Mailpit credentials"
fi

# Install PHP dependencies if composer.json exists
if [ -f "composer.json" ] && [ ! -d "vendor" ]; then
    echo "Installing Composer dependencies..."
    composer install --no-interaction --prefer-dist --optimize-autoloader
fi

# Install Node.js dependencies if package.json exists
if [ -f "package.json" ] && [ ! -d "node_modules" ]; then
    echo "Installing Node.js dependencies with yarn..."
    set +e
    yarn install --frozen-lockfile 2>&1 || yarn install 2>&1
    if [ ! -d "node_modules" ]; then
        echo "Warning: yarn install failed. Run 'yarn install' manually after container starts."
    fi
    set -e
fi

# Build frontend assets if vite config exists
if [ -d "node_modules" ] && { [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; }; then
    echo "Building frontend assets..."
    yarn build 2>/dev/null || echo "Warning: yarn build failed. Run it manually."
fi

# Laravel-specific setup (only if artisan exists)
if [ -f "artisan" ]; then
    # Create .env from .env.example if needed
    if [ -f ".env.example" ] && [ ! -f ".env" ]; then
        cp .env.example .env
    fi

    # Configure database credentials in .env
    if [ -f ".env" ]; then
        sed -i -E 's/^#?\s*DB_CONNECTION=.*/DB_CONNECTION=mariadb/' .env
        sed -i -E 's/^#?\s*DB_HOST=.*/DB_HOST='"$DB_HOST"'/' .env
        sed -i -E 's/^#?\s*DB_PORT=.*/DB_PORT='"$DB_PORT"'/' .env
        sed -i -E 's/^#?\s*DB_DATABASE=.*/DB_DATABASE='"$DB_NAME"'/' .env
        sed -i -E 's/^#?\s*DB_USERNAME=.*/DB_USERNAME='"$DB_USER"'/' .env
        sed -i -E 's/^#?\s*DB_PASSWORD=.*/DB_PASSWORD='"$DB_PASSWORD"'/' .env
    fi

    # Generate app key if not set
    if grep -q "^APP_KEY=$" .env 2>/dev/null || grep -q "^APP_KEY=\"\"" .env 2>/dev/null; then
        php artisan key:generate --no-interaction
    fi

    # Wait for MariaDB and run migrations
    echo "Waiting for MariaDB..."
    MAX_TRIES=30
    COUNT=0
    while ! mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" --silent 2>/dev/null; do
        COUNT=$((COUNT + 1))
        if [ $COUNT -ge $MAX_TRIES ]; then
            echo "Warning: MariaDB not ready after ${MAX_TRIES}s, skipping migrations"
            break
        fi
        sleep 1
    done

    if [ $COUNT -lt $MAX_TRIES ]; then
        php artisan migrate --force --no-interaction
        php artisan db:seed --force --no-interaction 2>/dev/null || true
    fi
fi

# Initialize fresh git repository
WORKSPACE_NAME="${CODER_WORKSPACE_NAME:-$(basename $(pwd))}"
if [ ! -d ".git" ]; then
    echo "Initializing git repository: $WORKSPACE_NAME"
    git init
    git add .
    git commit -m "Initial commit - $WORKSPACE_NAME" --no-verify || true
elif [ -d ".git" ]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if echo "$REMOTE_URL" | grep -q "template\|Template" 2>/dev/null; then
        rm -rf .git
        git init
        git add .
        git commit -m "Initial commit - $WORKSPACE_NAME" --no-verify || true
    fi
fi

# Ensure filebrowser entrypoint is executable
if [ -f /usr/local/bin/filebrowser-entrypoint ]; then
    sudo chmod +x /usr/local/bin/filebrowser-entrypoint 2>/dev/null || true
fi

# Set up Claude Code authentication
# Priority: 1) ANTHROPIC_API_KEY env var, 2) Host credentials copied by initializeCommand
CRED_FILE=".devcontainer/.claude-credentials"
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "ANTHROPIC_API_KEY is set for Claude Code"
elif [ -f "$CRED_FILE" ]; then
    echo "Copying Claude Code credentials from host..."
    mkdir -p ~/.claude
    cp "$CRED_FILE" ~/.claude/.credentials.json
    chmod 600 ~/.claude/.credentials.json
    echo "Claude Code credentials configured (OAuth from host)"
else
    echo "Note: Set ANTHROPIC_API_KEY or auth with 'claude auth login' after startup"
fi

# Copy SSH keys from host if available
if [ -d "/mnt/home/${USER}/.ssh" ]; then
    cp -r /mnt/home/${USER}/.ssh ~/. 2>/dev/null || true
    chmod 700 ~/.ssh 2>/dev/null || true
    chmod 600 ~/.ssh/* 2>/dev/null || true
fi

# Copy git config if available
if [ -f "/mnt/home/${USER}/.gitconfig" ]; then
    cp /mnt/home/${USER}/.gitconfig ~/. 2>/dev/null || true
fi

# Start code-server
if command -v code-server > /dev/null 2>&1; then
    echo "Starting code-server on port 13337..."
    nohup code-server --auth none --port 13337 --host 0.0.0.0 > /tmp/code-server.log 2>&1 &
fi

echo "Post-create setup complete!"
