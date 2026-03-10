#!/bin/bash

# AI4ALL-SRE: Background Service Installer
# Registers the dashboard tunnels as a systemd user service.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="ai4all-sre-dashboards.service"
SERVICE_PATH="${PROJECT_ROOT}/platforms/automation/${SERVICE_NAME}"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"

echo "🚀 Installing AI4ALL-SRE Dashboard Service..."

# Ensure directory exists
mkdir -p "${USER_SYSTEMD_DIR}"

# Copy service file (Systemd %h handles the home path, but we ensure it's correct)
cp "${SERVICE_PATH}" "${USER_SYSTEMD_DIR}/"

# Reload and enable
systemctl --user daemon-reload
systemctl --user enable "${SERVICE_NAME}"
systemctl --user restart "${SERVICE_NAME}"

echo "------------------------------------------------"
echo "✅ Service Installed & Started!"
echo "------------------------------------------------"
echo "Status: $(systemctl --user is-active ${SERVICE_NAME})"
echo "Logs:   journalctl --user -u ${SERVICE_NAME} -f"
echo "Stop:   systemctl --user stop ${SERVICE_NAME}"
echo "------------------------------------------------"

# Ensure user lingering is enabled so it runs even when not logged in (optional but recommended for SRE labs)
# if ! loginctl show-user "$USER" | grep -q "Linger=yes"; then
#     echo "[*] Enabling user lingering for background persistence..."
#     sudo loginctl enable-linger "$USER"
# fi

echo "✅ All 12 endpoints will now be automatically forwarded on boot/login."
