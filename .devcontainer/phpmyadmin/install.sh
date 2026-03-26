#!/usr/bin/env bash

set -euo pipefail

BOLD='\033[0;1m'
RESET='\033[0m'

printf "%sInstalling phpMyAdmin%s\n\n" "${BOLD}" "${RESET}"

# phpMyAdmin version - use 5.2.2 for PHP 8.4 compatibility
VERSION="5.2.2"
INSTALL_DIR="/opt/phpmyadmin"

# Check if phpMyAdmin is already installed
if [ ! -d "${INSTALL_DIR}" ]; then
    echo "Downloading phpMyAdmin ${VERSION}..."

    # Download phpMyAdmin
    curl -fsSL "https://files.phpmyadmin.net/phpMyAdmin/${VERSION}/phpMyAdmin-${VERSION}-all-languages.tar.gz" -o /tmp/phpmyadmin.tar.gz

    # Extract
    sudo mkdir -p ${INSTALL_DIR}
    sudo tar -xzf /tmp/phpmyadmin.tar.gz -C ${INSTALL_DIR} --strip-components=1

    # Create tmp directory for phpMyAdmin
    sudo mkdir -p ${INSTALL_DIR}/tmp
    sudo chmod 777 ${INSTALL_DIR}/tmp

    # Clean up
    rm /tmp/phpmyadmin.tar.gz

    echo "phpMyAdmin installed to ${INSTALL_DIR}"
fi

# Create configuration file with error suppression for PHP 8.4
# Reads credentials from environment variables set by docker-compose
sudo tee ${INSTALL_DIR}/config.inc.php > /dev/null <<'PHPCONFIG'
<?php
// Suppress deprecation warnings for PHP 8.4 compatibility
error_reporting(E_ALL & ~E_DEPRECATED & ~E_STRICT);

$cfg['blowfish_secret'] = 'devcontainer-phpmyadmin-secret-key-32ch';

$i = 0;
$i++;

// Force TCP connection instead of socket
$cfg['Servers'][$i]['host'] = getenv('PMA_HOST') ?: getenv('DB_HOST') ?: '127.0.0.1';
$cfg['Servers'][$i]['port'] = getenv('PMA_PORT') ?: getenv('DB_PORT') ?: '3306';
$cfg['Servers'][$i]['socket'] = '';
$cfg['Servers'][$i]['connect_type'] = 'tcp';

// Auto-login configuration - read from environment variables
$cfg['Servers'][$i]['auth_type'] = 'config';
$cfg['Servers'][$i]['user'] = getenv('DB_USER') ?: 'root';
$cfg['Servers'][$i]['password'] = getenv('DB_PASSWORD') ?: 'mariadb';
$cfg['Servers'][$i]['AllowNoPassword'] = true;
$cfg['Servers'][$i]['compress'] = false;

$cfg['TempDir'] = '/opt/phpmyadmin/tmp';
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';

// Hide deprecation warnings in output
$cfg['SendErrorReports'] = 'never';
PHPCONFIG

# Create entrypoint script
cat | sudo tee /usr/local/bin/phpmyadmin-entrypoint > /dev/null <<'EOF'
#!/usr/bin/env bash

PORT="${PORT:-8081}"
DB_HOST="${DBHOST:-${DB_HOST:-127.0.0.1}}"
DB_PORT="${DBPORT:-${DB_PORT:-3306}}"
LOG_PATH="/tmp/phpmyadmin.log"
INSTALL_DIR="/opt/phpmyadmin"

# Ensure log file exists and is writable
touch "${LOG_PATH}" 2>/dev/null || sudo touch "${LOG_PATH}"
chmod 666 "${LOG_PATH}" 2>/dev/null || sudo chmod 666 "${LOG_PATH}"

# Export for PHP to read
export PMA_HOST="${DB_HOST}"
export PMA_PORT="${DB_PORT}"

printf "Starting phpMyAdmin...\n"
printf "Port: %s\n" "${PORT}"
printf "Database Host: %s:%s\n" "${DB_HOST}" "${DB_PORT}"
printf "Database Name: %s\n" "${DB_NAME:-default}"
printf "Database User: %s\n" "${DB_USER:-root}"

# Start PHP built-in server for phpMyAdmin with error suppression
cd ${INSTALL_DIR}
nohup php -d error_reporting="E_ALL & ~E_DEPRECATED & ~E_STRICT" -S 0.0.0.0:${PORT} >> "${LOG_PATH}" 2>&1 &

printf "phpMyAdmin started at http://localhost:%s\n" "${PORT}"
printf "Logs at %s\n\n" "${LOG_PATH}"
EOF

sudo chmod +x /usr/local/bin/phpmyadmin-entrypoint

printf "%sInstallation complete!%s\n\n" "${BOLD}" "${RESET}"
