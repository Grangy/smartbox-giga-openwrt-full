#!/bin/bash
# Восстановление на роутер. Требует sshpass: brew install sshpass
# ROUTER_IP=192.168.23.1 SSH_PASSWORD=REDACTED ./scripts/restore.sh

RELEASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROUTER_IP="${ROUTER_IP:-192.168.23.1}"
SSH_PASSWORD="${SSH_PASSWORD:-REDACTED}"

run_ssh() { sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "root@$ROUTER_IP" "$@"; }

echo "=== Восстановление на $ROUTER_IP ==="

echo "1. config-backup"
for cfg in wireless podkop network dhcp firewall sing-box; do
  [ -f "$RELEASE_DIR/config-backup/$cfg" ] && cat "$RELEASE_DIR/config-backup/$cfg" | run_ssh "cat > /etc/config/$cfg" && echo "  ✓ $cfg"
done
[ -f "$RELEASE_DIR/config-backup/cursor.lst" ] && cat "$RELEASE_DIR/config-backup/cursor.lst" | run_ssh "cat > /etc/podkop/cursor.lst" && echo "  ✓ cursor.lst"

echo "2. sing-box config.json.master + UCI"
[ -f "$RELEASE_DIR/etc/sing-box/config.json.master" ] && cat "$RELEASE_DIR/etc/sing-box/config.json.master" | run_ssh "cat > /etc/sing-box/config.json.master" && echo "  ✓ config.json.master"
run_ssh "uci set sing-box.main.conffile='/etc/sing-box/config.json.master'; uci set podkop.settings.config_path='/etc/sing-box/config.json'; uci commit sing-box; uci commit podkop" && echo "  ✓ UCI"

echo "3. rulesets"
run_ssh "mkdir -p /etc/podkop/rulesets"
for f in main-local-domains-ruleset.json main-telegram-ruleset.json main-tiktok-ruleset.json main-user-domains-ruleset.json; do
  [ -f "$RELEASE_DIR/etc/podkop/rulesets/$f" ] && cat "$RELEASE_DIR/etc/podkop/rulesets/$f" | run_ssh "cat > /etc/podkop/rulesets/$f" && echo "  ✓ $f"
done

echo "4. telegram-subnets-fix + init + rc.local + cron"
[ -f "$RELEASE_DIR/etc/telegram-subnets-fix" ] && cat "$RELEASE_DIR/etc/telegram-subnets-fix" | run_ssh "cat > /usr/bin/telegram-subnets-fix" && run_ssh "chmod +x /usr/bin/telegram-subnets-fix" && echo "  ✓ telegram-subnets-fix"
[ -f "$RELEASE_DIR/etc/init.d/telegram-subnets" ] && cat "$RELEASE_DIR/etc/init.d/telegram-subnets" | run_ssh "cat > /etc/init.d/telegram-subnets" && run_ssh "chmod +x /etc/init.d/telegram-subnets" && run_ssh "/etc/init.d/telegram-subnets enable" && echo "  ✓ telegram-subnets"
[ -f "$RELEASE_DIR/etc/rc.local" ] && cat "$RELEASE_DIR/etc/rc.local" | run_ssh "cat > /etc/rc.local" && run_ssh "chmod +x /etc/rc.local" && echo "  ✓ rc.local"
run_ssh 'grep -q "\*/2 \* \* \* \* /usr/bin/telegram-subnets-fix" /etc/crontabs/root 2>/dev/null || (echo "*/2 * * * * /usr/bin/telegram-subnets-fix" >> /etc/crontabs/root && /etc/init.d/cron restart 2>/dev/null)' && echo "  ✓ cron */2"

echo "5. Restart"
run_ssh "/etc/init.d/network reload 2>/dev/null; /etc/init.d/dnsmasq restart 2>/dev/null; /etc/init.d/podkop restart 2>/dev/null; sleep 2; /usr/bin/telegram-subnets-fix"

echo ""
echo "Готово. Перезагрузите: ssh root@$ROUTER_IP reboot"
