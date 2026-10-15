#!/usr/bin/env bash
# ==============================================================================
# Setup & Deploy Script for Gemini-Web2API on Linux VPS (Systemd)
# ==============================================================================
set -e

# Detect current directory and running user
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="$(id -un)"
SERVICE_NAME="gemini-web2api"

echo "=== Deploying Gemini-Web2API ==="
echo "Directory: $APP_DIR"
echo "User:      $CURRENT_USER"

# Check sudo / root
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

# 1. Install prerequisites (Python 3, venv, curl)
echo "--> Installing system packages..."
if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq python3 python3-venv python3-pip curl
elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y -q python3 python3-pip curl
elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y -q python3 python3-pip curl
fi

# 2. Setup Virtual Environment
echo "--> Setting up virtual environment..."
if [ ! -d "$APP_DIR/.venv" ]; then
    python3 -m venv "$APP_DIR/.venv"
fi

# 3. Install Python Dependencies
echo "--> Installing Python dependencies..."
"$APP_DIR/.venv/bin/pip" install --upgrade pip -q
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt" -q

# 4. Check configuration files
if [ ! -f "$APP_DIR/config.json" ]; then
    echo "--> config.json not found, copying from config.example.json..."
    cp "$APP_DIR/config.example.json" "$APP_DIR/config.json"
fi

if [ ! -f "$APP_DIR/cookie.txt" ]; then
    echo "[!] PERINGATAN: cookie.txt belum ada di $APP_DIR."
    echo "    Jangan lupa isi cookie.txt jika menggunakan fitur akun Gemini Advanced!"
fi

# 5. Create Systemd Service File
echo "--> Configuring systemd service (/etc/systemd/system/${SERVICE_NAME}.service)..."
$SUDO bash -c "cat <<EOF > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=Gemini Web to OpenAI API Service
After=network.target

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${APP_DIR}
ExecStart=${APP_DIR}/.venv/bin/python ${APP_DIR}/gemini_web2api.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF"

# 6. Reload & Enable Systemd Service
echo "--> Starting and enabling ${SERVICE_NAME} service..."
$SUDO systemctl daemon-reload
$SUDO systemctl enable "${SERVICE_NAME}"
$SUDO systemctl restart "${SERVICE_NAME}"

echo ""
echo "=== Deployment Selesai! ==="
echo "Status Service:"
$SUDO systemctl status "${SERVICE_NAME}" --no-pager -l || true
echo ""
echo "Perintah berguna:"
echo "  - Cek Log Realtime : journalctl -u ${SERVICE_NAME} -f"
echo "  - Restart Service  : sudo systemctl restart ${SERVICE_NAME}"
echo "  - Stop Service     : sudo systemctl stop ${SERVICE_NAME}"
echo "  - Cek Status       : sudo systemctl status ${SERVICE_NAME}"
