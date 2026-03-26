#!/usr/bin/env bash

set -euo pipefail

BOLD='\033[0;1m'
RESET='\033[0m'

printf "%sInstalling pgweb (PostgreSQL web client)%s\n\n" "${BOLD}" "${RESET}"

PORT="${PORT:-8082}"

# Install pgweb binary (lightweight PostgreSQL web UI)
if ! command -v pgweb &>/dev/null; then
    VERSION="0.16.2"
    echo "Downloading pgweb ${VERSION}..."
    curl -fsSL "https://github.com/sosedoff/pgweb/releases/download/v${VERSION}/pgweb_linux_amd64.zip" -o /tmp/pgweb.zip
    # Install unzip if needed
    which unzip > /dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y unzip)
    cd /tmp && unzip -o pgweb.zip
    sudo mv /tmp/pgweb_linux_amd64 /usr/local/bin/pgweb
    sudo chmod +x /usr/local/bin/pgweb
    rm -f /tmp/pgweb.zip
    echo "pgweb installed"
fi

# Create entrypoint script
cat | sudo tee /usr/local/bin/pgadmin-entrypoint > /dev/null <<EOF
#!/usr/bin/env bash

PORT="\${PGWEB_PORT:-${PORT}}"
PG_HOST="\${PG_HOST:-127.0.0.1}"
PG_PORT="\${PG_PORT:-5432}"
PG_USER="\${PG_USER:-postgres}"
PG_PASSWORD="\${PG_PASSWORD:-postgres}"
PG_NAME="\${PG_NAME:-\${DB_NAME:-devcontainer_db}}"
LOG_PATH="/tmp/pgweb.log"

touch "\${LOG_PATH}" 2>/dev/null || sudo touch "\${LOG_PATH}"
chmod 666 "\${LOG_PATH}" 2>/dev/null || sudo chmod 666 "\${LOG_PATH}"

printf "Starting pgweb (PostgreSQL Admin)...\n"
printf "Port: \${PORT}\n"
printf "PostgreSQL: \${PG_HOST}:\${PG_PORT}\n"
printf "Database: \${PG_NAME}\n"
printf "User: \${PG_USER}\n"

nohup pgweb --bind 0.0.0.0 --listen \${PORT} --host \${PG_HOST} --port \${PG_PORT} --user \${PG_USER} --pass \${PG_PASSWORD} --db \${PG_NAME} --ssl disable >> "\${LOG_PATH}" 2>&1 &

printf "pgweb started at http://localhost:\${PORT}\n"
printf "Logs at \${LOG_PATH}\n\n"
EOF

sudo chmod +x /usr/local/bin/pgadmin-entrypoint

printf "%sInstallation complete!%s\n\n" "${BOLD}" "${RESET}"
