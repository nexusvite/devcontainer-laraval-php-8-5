FROM php:8.5-cli-bookworm AS php85

# Build required extensions in the PHP 8.5 image
RUN apt-get update && apt-get install -y --no-install-recommends \
        libicu-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev \
    && docker-php-ext-install mysqli pdo pdo_mysql sockets pcntl intl zip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

FROM mcr.microsoft.com/devcontainers/php:1-8.4-bookworm

# Replace PHP 8.4 with PHP 8.5 binaries and extensions from official image
COPY --from=php85 /usr/local/bin/php /usr/local/bin/php
COPY --from=php85 /usr/local/bin/php-config /usr/local/bin/php-config
COPY --from=php85 /usr/local/bin/phpize /usr/local/bin/phpize
COPY --from=php85 /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=php85 /usr/local/etc/php/ /usr/local/etc/php/

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local

# Install Node.js LTS, yarn, and Claude Code CLI
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install --lts && nvm use --lts && npm install -g yarn @anthropic-ai/claude-code" 2>&1
