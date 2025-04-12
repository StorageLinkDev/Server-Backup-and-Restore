#!/bin/bash
# =========================================
# UNIVERSĀLAIS SERVERA RESTORE (Viss no 1 faila)
# =========================================

[ -z "$1" ] && echo "❌ Lietojums: $0 full_server_backup_YYYYMMDD.tar.gz" && exit 1

# =====[ WEB SERVER RESTORE ]=====
# Ja ir pārveidoti Nginx konfigi no Apache
if [ -d "$RESTORE_DIR/web/nginx_converted" ]; then
  echo "🔵 Instalē pārveidotos Nginx konfigus..."
  sudo apt install -y nginx  # Ja vēl nav instalēts
  mkdir -p /etc/nginx/conf.d
  cp "$RESTORE_DIR"/web/nginx_converted/*.nginx /etc/nginx/conf.d/
  
  # Pārbauda un restartē
  sudo nginx -t && sudo systemctl restart nginx
fi

BACKUP_FILE="$1"
RESTORE_DIR="/tmp/full_restore_$(date +%s)"
mkdir -p "$RESTORE_DIR"
tar -xzvf "$BACKUP_FILE" -C "$RESTORE_DIR" >/dev/null

# 1. Atjauno atslēgas
cp -r "$RESTORE_DIR"/keys/.ssh ~/
cp "$RESTORE_DIR"/keys/.gitconfig ~/ 2>/dev/null
gpg --import "$RESTORE_DIR/keys/gpg_private.keys" 2>/dev/null
crontab "$RESTORE_DIR/keys/crontab.txt" 2>/dev/null

# 2. Atjauno servera iestatījumus
cp "$RESTORE_DIR/hostname" /etc/hostname
hostname -F /etc/hostname
timedatectl set-timezone "$(cat $RESTORE_DIR/timezone)"

# 3. Atjauno SSL
[ -d "$RESTORE_DIR/ssl/letsencrypt" ] && cp -r "$RESTORE_DIR/ssl/letsencrypt" /etc/
[ -d "$RESTORE_DIR/ssl/custom" ] && cp -r "$RESTORE_DIR/ssl/custom" /etc/ssl/

# 4. Atjauno web serveri
[ -d "$RESTORE_DIR/web/nginx" ] && cp -r "$RESTORE_DIR/web/nginx" /etc/
[ -d "$RESTORE_DIR/web/apache2" ] && cp -r "$RESTORE_DIR/web/apache2" /etc/

# 5. Restartē servisus
systemctl restart nginx apache2 sshd crond 2>/dev/null
certbot renew --dry-run 2>/dev/null

rm -rf "$RESTORE_DIR"
echo "✅ FULL RESTORE PABEIGTS! Restartē serveri: reboot"