#!/bin/bash
# setup_systemd.sh v1.0 - egyszeri beallitas
# Utana a program sudo NELKUL fut memory-first modban!
#
# Mit csinal:
#   1. PAM limits: korlatlan mlock a felhasznalonak
#   2. systemd user service: automatikus indulas (opcionalis)
#   3. Huge pages kernel param: 4096 db 2MB-os lap (8GB)

if [ "$(id -u)" -ne 0 ]; then
    echo "HIBA: ezt a szkriptet sudo-val kell futtatni:"
    echo "  sudo ./setup_systemd.sh"
    exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
echo "=== Secure PassGen System Setup ==="
echo "Felhasznalo: $USER_NAME"
echo

# --- 1. PAM limits (mlock jog) ---
echo "[1/3] PAM limits beallitasa (korlatlan mlock)..."
cat > /etc/security/limits.d/99-secure-passgen.conf << EOF
# Secure PassGen - unlimited mlock for user
$USER_NAME  soft  memlock  unlimited
$USER_NAME  hard  memlock  unlimited
EOF
echo "  OK: /etc/security/limits.d/99-secure-passgen.conf"

# --- 2. Huge pages engedelyezes (8GB = 4096 × 2MB) ---
echo "[2/3] Huge pages engedelyezese (4096 × 2MB = 8GB)..."
echo 4096 > /proc/sys/vm/nr_hugepages
# Persistent: /etc/sysctl.d/
cat > /etc/sysctl.d/99-hugepages.conf << EOF
# Secure PassGen - huge pages
vm.nr_hugepages = 4096
EOF
sysctl -p /etc/sysctl.d/99-hugepages.conf 2>/dev/null
echo "  OK: vm.nr_hugepages = $(cat /proc/sys/vm/nr_hugepages)"

# --- 3. systemd user service (opcionalis) ---
echo "[3/3] systemd user service telepitese..."
USER_HOME=$(eval echo "~$USER_NAME")
SERVICE_DIR="$USER_HOME/.config/systemd/user"
mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_DIR/secure-passgen.service" << EOF
[Unit]
Description=Secure PassGen memory-first
After=local-fs.target

[Service]
Type=oneshot
ExecStart=$USER_HOME/secure-passgen/target/release/secure-passgen --memory-first --huge-pages
LimitMEMLOCK=infinity
LimitNOFILE=65536

[Install]
WantedBy=default.target
EOF

chown -R "$USER_NAME:$USER_NAME" "$SERVICE_DIR"

# Engedelyezes a user systemd-jenek (loginctl)
loginctl enable-linger "$USER_NAME" 2>/dev/null || true

echo "  OK: $SERVICE_DIR/secure-passgen.service"
echo
echo "========================================"
echo "  BEFEJEZVE!"
echo "========================================"
echo
echo "UJ BEJELENTKEZES SZUKSEGES (vagy: su - $USER_NAME)"
echo "Utana a program SUDO NELKUL futtathato:"
echo "  ./target/release/secure-passgen --memory-first -c -n -s -l 16 -10M -o /dev/shm/test.csv"
echo
echo "Ellenorzes: ulimit -l   (korlatlan kell legyen)"
echo

# ===== END OF SCRIPT v1.0 =====
