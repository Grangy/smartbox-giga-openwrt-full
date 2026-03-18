#!/bin/bash
# Ручное применение fix (если TG/Cursor не работают).
# ROUTER_IP=192.168.23.1 SSH_PASSWORD=REDACTED ./scripts/apply-fix.sh

RELEASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROUTER_IP="${ROUTER_IP:-192.168.23.1}"
SSH_PASSWORD="${SSH_PASSWORD:-REDACTED}"

run_ssh() { sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "root@$ROUTER_IP" "$@"; }

[ -f "$RELEASE_DIR/etc/sing-box/config.json.master" ] && cat "$RELEASE_DIR/etc/sing-box/config.json.master" | run_ssh "cat > /etc/sing-box/config.json.master"
run_ssh "uci set sing-box.main.conffile='/etc/sing-box/config.json.master'; uci set podkop.settings.config_path='/etc/sing-box/config.json'; uci commit sing-box; uci commit podkop"
[ -f "$RELEASE_DIR/etc/telegram-subnets-fix" ] && cat "$RELEASE_DIR/etc/telegram-subnets-fix" | run_ssh "cat > /usr/bin/telegram-subnets-fix" && run_ssh "chmod +x /usr/bin/telegram-subnets-fix"
run_ssh "/usr/bin/telegram-subnets-fix"
echo "Готово."
