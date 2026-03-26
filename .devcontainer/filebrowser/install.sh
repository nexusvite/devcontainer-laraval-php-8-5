#!/usr/bin/env bash

set -euo pipefail

BOLD='\033[0;1m'

printf "%sInstalling filebrowser\n\n" "${BOLD}"

# Check if filebrowser is installed.
if ! command -v filebrowser &>/dev/null; then
	VERSION="v2.42.1"
	EXPECTED_HASH="7d83c0f077df10a8ec9bfd9bf6e745da5d172c3c768a322b0e50583a6bc1d3cc"

	curl -fsSL "https://github.com/filebrowser/filebrowser/releases/download/${VERSION}/linux-amd64-filebrowser.tar.gz" -o /tmp/filebrowser.tar.gz
	echo "${EXPECTED_HASH} /tmp/filebrowser.tar.gz" | sha256sum -c
	tar -xzf /tmp/filebrowser.tar.gz -C /tmp
	sudo mv /tmp/filebrowser /usr/local/bin/
	sudo chmod +x /usr/local/bin/filebrowser
	rm /tmp/filebrowser.tar.gz
fi

# Create entrypoint - Pass ALL options on command line to bypass config issues
cat >/usr/local/bin/filebrowser-entrypoint <<EOF
#!/usr/bin/env bash

PORT="${PORT}"
FOLDER="${FOLDER:-}"
FOLDER="\${FOLDER:-\$(pwd)}"
LOG_PATH=/tmp/filebrowser.log
DB_PATH="/tmp/filebrowser.db"

printf "Starting filebrowser...\n\n"

# Remove any existing database
rm -f "\${DB_PATH}"

# Start filebrowser with ALL options on command line
# --noauth disables authentication completely
# --database creates a fresh database
filebrowser \\
    --noauth \\
    --database="\${DB_PATH}" \\
    --address=0.0.0.0 \\
    --port=\${PORT} \\
    --root="\${FOLDER}" \\
    >>\${LOG_PATH} 2>&1 &

printf "Serving \${FOLDER} at http://localhost:\${PORT}\n"
printf "Logs at \${LOG_PATH}\n\n"
EOF

chmod +x /usr/local/bin/filebrowser-entrypoint

printf "Installation complete!\n\n"
