FROM mcr.microsoft.com/devcontainers/php:1-8.4-bookworm

# Note: Network is restricted during Coder's Docker build phase.
# PHP 8.5 upgrade and system packages are installed at runtime in post_create.sh.

# Install Node.js LTS, yarn, and Claude Code CLI
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install --lts && nvm use --lts && npm install -g yarn @anthropic-ai/claude-code" 2>&1
