FROM mcr.microsoft.com/devcontainers/php:1-8.5-bookworm

# Note: apt-get is unavailable during Coder's Docker build phase (restricted network).
# Packages like mariadb-client are installed at runtime in post_create.sh instead.

# Install PHP extensions for database connectivity
RUN docker-php-ext-install mysqli pdo pdo_mysql sockets pcntl

# Install Node.js LTS, yarn, and Claude Code CLI
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install --lts && nvm use --lts && npm install -g yarn @anthropic-ai/claude-code" 2>&1

