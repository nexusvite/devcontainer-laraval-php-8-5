#!/bin/bash

set -e

echo "Running post-create setup..."

# Wait for DNS/network to be ready (network_mode: service:db may delay resolution)
echo "Waiting for network..."
for i in $(seq 1 30); do
    if getent hosts packages.sury.org > /dev/null 2>&1; then
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

# Install system packages and upgrade to PHP 8.5 (done here instead of Dockerfile
# because Coder's Docker build phase has restricted network access)
echo "Installing system packages and PHP 8.5..."
sudo apt-get update
apt_install_retry mariadb-client lsb-release ca-certificates

# Add Sury PHP repository and install PHP 8.5
curl --retry 5 --retry-delay 5 --retry-all-errors -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list > /dev/null
sudo apt-get update
apt_install_retry php8.5 php8.5-cli php8.5-common php8.5-curl php8.5-mbstring \
    php8.5-xml php8.5-zip php8.5-mysql php8.5-readline php8.5-intl php8.5-gd
sudo update-alternatives --set php /usr/bin/php8.5

# Ensure all PHP 8.5 modules are enabled (mysqli needed for phpMyAdmin)
sudo phpenmod -v 8.5 mysqli pdo_mysql curl mbstring xml zip intl gd 2>/dev/null || true

sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* /tmp/debsuryorg-archive-keyring.deb
echo "PHP version: $(php -v | head -1)"
echo "PHP modules: $(php -m | tr '\n' ' ')"

# Install code-server (standalone method — no dpkg/apt dependencies needed)
if ! command -v code-server > /dev/null 2>&1; then
    echo "Installing code-server..."
    for attempt in 1 2 3; do
        if curl --retry 3 --retry-delay 3 --retry-all-errors -fsSL https://code-server.dev/install.sh | sudo sh -s -- --method=standalone --prefix=/usr/local; then
            break
        fi
        echo "  code-server install attempt $attempt failed, retrying..."
        sleep 5
    done
fi

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

# Set up Claude Code credentials from ANTHROPIC_API_KEY env var
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "ANTHROPIC_API_KEY is set for Claude Code"
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
