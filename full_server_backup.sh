#!/bin/bash
# =========================================
# UNIVERSĀLAIS SERVERA BACKUP (Viss 1 failā)
# =========================================

BACKUP_DIR="/root/full_server_backup_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Pārveido Apache -> Nginx (ja konfigi eksistē)
if [ -d "/etc/apache2" ]; then
  echo "🔵 Konvertē Apache konfigus uz Nginx formātu..."
  mkdir -p "$BACKUP_DIR/web/nginx_converted"
  for site in $(ls /etc/apache2/sites-available/); do
    if [ "$site" != "000-default.conf" ]; then
      # Izmanto 'apache2nginx' rīku (instalējam to pirms backup)
      apache2nginx /etc/apache2/sites-available/$site > "$BACKUP_DIR/web/nginx_converted/${site}.nginx" 2>/dev/null
    fi
  done
fi

# 1. Atslēgas un konfigi (~/.ssh, ~/.config, Docker, Git, GPG, cron)
mkdir -p "$BACKUP_DIR/keys"
cp -r ~/.ssh "$BACKUP_DIR/keys/"
cp ~/.gitconfig "$BACKUP_DIR/keys/" 2>/dev/null
gpg --export-secret-keys > "$BACKUP_DIR/keys/gpg_private.keys" 2>/dev/null
crontab -l > "$BACKUP_DIR/keys/crontab.txt" 2>/dev/null

# 2. Servera iestatījumi (hostname, timezone)
cp /etc/hostname "$BACKUP_DIR/"
timedatectl | grep "Time zone" | awk '{print $3}' > "$BACKUP_DIR/timezone"

# 3. SSL sertifikāti (Let's Encrypt + custom)
mkdir -p "$BACKUP_DIR/ssl"
[ -d "/etc/letsencrypt" ] && cp -r /etc/letsencrypt "$BACKUP_DIR/ssl/"
[ -d "/etc/ssl/custom" ] && cp -r /etc/ssl/custom "$BACKUP_DIR/ssl/"

# 4. Web serveris (Nginx/Apache)
mkdir -p "$BACKUP_DIR/web"
[ -d "/etc/nginx" ] && cp -r /etc/nginx "$BACKUP_DIR/web/"
[ -d "/etc/apache2" ] && cp -r /etc/apache2 "$BACKUP_DIR/web/"

# 5. Izveido arhīvu
tar -czvf "/root/full_server_backup_$(date +%Y%m%d).tar.gz" "$BACKUP_DIR" >/dev/null
rm -rf "$BACKUP_DIR"

echo "✅ FULL BACKUP: /root/full_server_backup_$(date +%Y%m%d).tar.gz"
echo "📥 Lejupielāde: scp root@server:/root/full_server_backup_*.tar.gz ."