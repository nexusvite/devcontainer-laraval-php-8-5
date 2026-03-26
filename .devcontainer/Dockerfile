FROM mcr.microsoft.com/devcontainers/php:1-8.4-bookworm

# Upgrade PHP 8.4 to 8.5 via Ondrej Sury's PPA
RUN apt-get update \
    && apt-get install -y --no-install-recommends lsb-release ca-certificates curl \
    && curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb \
    && dpkg -i /tmp/debsuryorg-archive-keyring.deb \
    && echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php8.5 php8.5-cli php8.5-common php8.5-curl php8.5-mbstring \
        php8.5-xml php8.5-zip php8.5-mysql php8.5-pdo php8.5-sockets \
        php8.5-pcntl php8.5-readline php8.5-intl php8.5-gd \
    && update-alternatives --set php /usr/bin/php8.5 \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/*

# Note: apt-get is unavailable during Coder's Docker build phase (restricted network).
# Packages like mariadb-client are installed at runtime in post_create.sh instead.

# Install Node.js LTS, yarn, and Claude Code CLI
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install --lts && nvm use --lts && npm install -g yarn @anthropic-ai/claude-code" 2>&1
