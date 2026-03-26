FROM php:8.5-cli-bookworm AS php85

# Build required extensions in the PHP 8.5 image
RUN apt-get update && apt-get install -y --no-install-recommends \
        libicu-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev libpq-dev unzip \
    && docker-php-ext-install mysqli pdo pdo_mysql pdo_pgsql pgsql sockets pcntl intl zip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Download pgweb here where unzip is available
RUN curl -fsSL "https://github.com/sosedoff/pgweb/releases/download/v0.16.2/pgweb_linux_amd64.zip" -o /tmp/pgweb.zip \
    && unzip -o /tmp/pgweb.zip -d /tmp/ \
    && chmod +x /tmp/pgweb_linux_amd64

FROM mcr.microsoft.com/devcontainers/php:1-8.4-bookworm

# Replace PHP 8.4 with PHP 8.5 binaries and extensions from official image
COPY --from=php85 /usr/local/bin/php /usr/local/bin/php
COPY --from=php85 /usr/local/bin/php-config /usr/local/bin/php-config
COPY --from=php85 /usr/local/bin/phpize /usr/local/bin/phpize
COPY --from=php85 /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=php85 /usr/local/etc/php/ /usr/local/etc/php/

# Copy libpq from build stage (apt-get unavailable during Coder's Docker build)
COPY --from=php85 /usr/lib/x86_64-linux-gnu/libpq.so* /usr/lib/x86_64-linux-gnu/

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local

# Install Mailpit (email testing)
RUN curl -fsSL "https://github.com/axllent/mailpit/releases/download/v1.24.1/mailpit-linux-amd64.tar.gz" | tar -xz -C /usr/local/bin/ mailpit \
    && chmod +x /usr/local/bin/mailpit

# Copy pgweb from build stage
COPY --from=php85 /tmp/pgweb_linux_amd64 /usr/local/bin/pgweb

# Install Node.js LTS, yarn, and Claude Code CLI
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install --lts && nvm use --lts && npm install -g yarn @anthropic-ai/claude-code" 2>&1
