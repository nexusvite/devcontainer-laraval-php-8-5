#!/usr/bin/env bash

set -euo pipefail

BOLD='\033[0;1m'
RESET='\033[0m'

printf "%sInstalling Mailpit%s\n\n" "${BOLD}" "${RESET}"

SMTP_PORT="${SMTPPORT:-1025}"
UI_PORT="${UIPORT:-8025}"

# Install Mailpit binary
if ! command -v mailpit &>/dev/null; then
    VERSION="v1.24.1"
    echo "Downloading Mailpit ${VERSION}..."
    curl -fsSL "https://github.com/axllent/mailpit/releases/download/${VERSION}/mailpit-linux-amd64.tar.gz" -o /tmp/mailpit.tar.gz
    tar -xzf /tmp/mailpit.tar.gz -C /tmp
    sudo mv /tmp/mailpit /usr/local/bin/
    sudo chmod +x /usr/local/bin/mailpit
    rm -f /tmp/mailpit.tar.gz
    echo "Mailpit installed"
fi

# Create entrypoint script
cat | sudo tee /usr/local/bin/mailpit-entrypoint > /dev/null <<EOF
#!/usr/bin/env bash

SMTP_PORT="\${SMTP_PORT:-${SMTP_PORT}}"
UI_PORT="\${UI_PORT:-${UI_PORT}}"
LOG_PATH="/tmp/mailpit.log"

touch "\${LOG_PATH}" 2>/dev/null || sudo touch "\${LOG_PATH}"
chmod 666 "\${LOG_PATH}" 2>/dev/null || sudo chmod 666 "\${LOG_PATH}"

printf "Starting Mailpit...\n"
printf "SMTP: 0.0.0.0:\${SMTP_PORT}\n"
printf "Web UI: http://localhost:\${UI_PORT}\n"

nohup mailpit --smtp 0.0.0.0:\${SMTP_PORT} --listen 0.0.0.0:\${UI_PORT} >> "\${LOG_PATH}" 2>&1 &

printf "Mailpit started\n"
printf "Logs at \${LOG_PATH}\n\n"
EOF

sudo chmod +x /usr/local/bin/mailpit-entrypoint

printf "%sInstallation complete!%s\n\n" "${BOLD}" "${RESET}"
