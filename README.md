**🛠️ Unified Backup & Restore Script (All in One!)**

To avoid conflicts and simplify the process, I've combined all 4 scripts into one:

#### **📌 1. `full_server_backup.sh`** (Backs up EVERYTHING: keys, hostname, SSL, timezone, web configs)

Bash

```
#!/bin/bash
# =========================================
# UNIVERSAL SERVER BACKUP (All in 1 file)
# =========================================

BACKUP_DIR="/root/full_server_backup_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# 1. Keys and configs (~/.ssh, ~/.config, Docker, Git, GPG, cron)
mkdir -p "$BACKUP_DIR/keys"
cp -r ~/.ssh "$BACKUP_DIR/keys/"
cp ~/.gitconfig "$BACKUP_DIR/keys/" 2>/dev/null
gpg --export-secret-keys > "$BACKUP_DIR/keys/gpg_private.keys" 2>/dev/null
crontab -l > "$BACKUP_DIR/keys/crontab.txt" 2>/dev/null

# 2. Server settings (hostname, timezone)
cp /etc/hostname "$BACKUP_DIR/"
timedatectl | grep "Time zone" | awk '{print $3}' > "$BACKUP_DIR/timezone"

# 3. SSL certificates (Let's Encrypt + custom)
mkdir -p "$BACKUP_DIR/ssl"
[ -d "/etc/letsencrypt" ] && cp -r /etc/letsencrypt "$BACKUP_DIR/ssl/"
[ -d "/etc/ssl/custom" ] && cp -r /etc/ssl/custom "$BACKUP_DIR/ssl/"

# 4. Web server (Nginx/Apache)
mkdir -p "$BACKUP_DIR/web"
[ -d "/etc/nginx" ] && cp -r /etc/nginx "$BACKUP_DIR/web/"
[ -d "/etc/apache2" ] && cp -r /etc/apache2 "$BACKUP_DIR/web/"

# 5. Create archive
tar -czvf "/root/full_server_backup_$(date +%Y%m%d).tar.gz" "$BACKUP_DIR" >/dev/null
rm -rf "$BACKUP_DIR"

echo "✅ FULL BACKUP: /root/full_server_backup_$(date +%Y%m%d).tar.gz"
echo "📥 Download: scp root@server:/root/full_server_backup_*.tar.gz ."
```

#### **📌 2. `full_server_restore.sh`** (Restores EVERYTHING from backup)

Bash

```
#!/bin/bash
# =========================================
# UNIVERSAL SERVER RESTORE (All from 1 file)
# =========================================

[ -z "$1" ] && echo "❌ Usage: $0 full_server_backup_YYYYMMDD.tar.gz" && exit 1

BACKUP_FILE="$1"
RESTORE_DIR="/tmp/full_restore_$(date +%s)"
mkdir -p "$RESTORE_DIR"
tar -xzvf "$BACKUP_FILE" -C "$RESTORE_DIR" >/dev/null

# 1. Restore keys
cp -r "$RESTORE_DIR"/keys/.ssh ~/
cp "$RESTORE_DIR"/keys/.gitconfig ~/ 2>/dev/null
gpg --import "$RESTORE_DIR/keys/gpg_private.keys" 2>/dev/null
crontab "$RESTORE_DIR/keys/crontab.txt" 2>/dev/null

# 2. Restore server settings
cp "$RESTORE_DIR/hostname" /etc/hostname
hostname -F /etc/hostname
timedatectl set-timezone "$(cat $RESTORE_DIR/timezone)"

# 3. Restore SSL
[ -d "$RESTORE_DIR/ssl/letsencrypt" ] && cp -r "$RESTORE_DIR/ssl/letsencrypt" /etc/
[ -d "$RESTORE_DIR/ssl/custom" ] && cp -r "$RESTORE_DIR/ssl/custom" /etc/ssl/

# 4. Restore web server
[ -d "$RESTORE_DIR/web/nginx" ] && cp -r "$RESTORE_DIR/web/nginx" /etc/
[ -d "$RESTORE_DIR/web/apache2" ] && cp -r "$RESTORE_DIR/web/apache2" /etc/

# 5. Restart services
systemctl restart nginx apache2 sshd crond 2>/dev/null
certbot renew --dry-run 2>/dev/null

rm -rf "$RESTORE_DIR"
echo "✅ FULL RESTORE COMPLETED! Restart the server: reboot"
```

------

### **⭐ Key Advantages:**

1. **All in 1 file** - no more 4 separate backups
2. **No conflicts** - scripts run sequentially, not overwriting each other
3. **Simple migration** between servers

------

### **📚 Usage Instructions:**

#### **Backup:**

Bash

```
chmod +x full_server_backup.sh
./full_server_backup.sh  # Creates /root/full_server_backup_YYYYMMDD.tar.gz
```

#### **Restore:**

Bash

```
scp full_server_backup_YYYYMMDD.tar.gz new_server:/root/
chmod +x full_server_restore.sh
./full_server_restore.sh full_server_backup_YYYYMMDD.tar.gz
reboot
```

------

### **🔐 Security Tips:**

1. Encrypt the backup

    before transferring:

   Bash

   ```
   gpg -c full_server_backup_YYYYMMDD.tar.gz
   ```

2. Make sure

    the new server has:

   - The same OS (Ubuntu/Debian/CentOS)
   - Basic packages installed (nginx, certbot, etc.)

### **🔄 Changes If Migrating from Apache to Nginx (in the context of backup/restore)**

If the old server had **Apache**, but the new one has **Nginx** installed, the following adjustments are needed for a smooth migration:

------

## **1. Backup Adjustments (`full_server_backup.sh`)**

Add **conversion filters** to automatically convert Apache configs to Nginx-compatible format:

Bash

```
# =====[ WEB SERVER BACKUP ]=====
# Convert Apache -> Nginx (if configs exist)
if [ -d "/etc/apache2" ]; then
  echo "🔵 Converting Apache configs to Nginx format..."
  mkdir -p "$BACKUP_DIR/web/nginx_converted"
  for site in $(ls /etc/apache2/sites-available/); do
    if [ "$site" != "000-default.conf" ]; then
      # Use 'apache2nginx' tool (install it before backup)
      apache2nginx /etc/apache2/sites-available/$site > "$BACKUP_DIR/web/nginx_converted/${site}.nginx" 2>/dev/null
    fi
  done
fi
```

### **Mandatory actions before backup:**

1. Install the 

   apache2nginx

    tool:

   Bash

   ```
   sudo apt install -y apache2-utils  # Debian/Ubuntu
   sudo yum install -y httpd-tools    # CentOS
   ```

------

## **2. Restore Adjustments (`full_server_restore.sh`)**

Replace Apache configs with the converted Nginx files:

Bash

```
# =====[ WEB SERVER RESTORE ]=====
# If there are converted Nginx configs from Apache
if [ -d "$RESTORE_DIR/web/nginx_converted" ]; then
  echo "🔵 Installing converted Nginx configs..."
  sudo apt install -y nginx  # If not already installed
  mkdir -p /etc/nginx/conf.d
  cp "$RESTORE_DIR"/web/nginx_converted/*.nginx /etc/nginx/conf.d/
  
  # Check and restart
  sudo nginx -t && sudo systemctl restart nginx
fi
```

------

## **3. Key Changes in Configs**

Nginx doesn't understand Apache directives, so during conversion, the following changes:

| **Apache Directive**                        | **Nginx Equivalent**                    |
| ------------------------------------------- | --------------------------------------- |
| `DocumentRoot /path`                        | `root /path;`                           |
| `<VirtualHost *:80>`                        | `server { listen 80; ... }`             |
| `ErrorLog logs/error.log`                   | `error_log /path/error.log;`            |
| `RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]` | `rewrite ^/(.*)$ /index.php?q=$1 last;` |

------

## **4. Manual Verification Steps After Restore**

1. Verify if Nginx is processing PHP

   :

   Nginx

   ```
   location ~ \.php$ {
     fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
     include fastcgi_params;
   }
   ```

2. Update SSL certificate paths

    (if there was Apache 

   ```
   SSLCertificateFile
   ```

   ):

   Nginx

   ```
   ssl_certificate /etc/letsencrypt/live/domains/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/domains/privkey.pem;
   ```

3. Make sure static files are served

   :

   Nginx

   ```
   location /static/ {
     alias /var/www/html/static/;
   }
   ```

------

## **5. Full Migration Process**

Code snippet

```
flowchart TD
    A[Perform full backup with full_server_backup.sh] --> B[Convert Apache configs to Nginx]
    B --> C[Install Nginx on the new server]
    C --> D[Restore from backup with full_server_restore.sh]
    D --> E[Check logs: journalctl -u nginx -f]
```

------

### **⚠️ Important!**

- **Don't replace both servers at the same time** — test the new configuration first.
- **Use `nginx -t` before restarting** to check for syntax errors.
- **Migrate one domain at a time**, not all at once.

If errors occur, check:

Bash

```
sudo tail -100 /var/log/nginx/error.log
```

### **🔧 Commands for Migration with Your GitHub Repository**

Since you've placed the backup/restore scripts on GitHub ([Trusardi/server_backup_restore](https://www.google.com/search?q=https://github.com/Trusardi/server_backup_restore)), here are **specific commands** to migrate from the old server (with Apache) to the new one (with Nginx):

------

## **1. On the Old Server (Backup)**

#### **Download and run the backup script from GitHub:**

Bash

```
# Download scripts from GitHub
git clone git@github.com:Trusardi/server_backup_restore.git
cd server_backup_restore

# Make scripts executable
chmod +x full_server_backup.sh

# Install necessary tools (for Apache -> Nginx conversion)
sudo apt install -y apache2-utils  # Debian/Ubuntu
sudo yum install -y httpd-tools    # CentOS

# Run full backup (with Apache config conversion to Nginx)
./full_server_backup.sh
```

Result:

The backup file will be saved on the old server:

/root/full_server_backup_YYYYMMDD.tar.gz

------

## **2. On the New Server (Restore)**

#### **Download the backup and run restore:**

Bash

```
# Download scripts from GitHub
git clone git@github.com:Trusardi/server_backup_restore.git
cd server_backup_restore
chmod +x full_server_restore.sh

# Download the backup file from the old server (using SCP)
scp root@old_server:/root/full_server_backup_*.tar.gz .

# Run restore (with Nginx configs)
./full_server_restore.sh full_server_backup_YYYYMMDD.tar.gz

# Check if Nginx is working
sudo nginx -t && sudo systemctl restart nginx
```

------

## **3. Post-Migration Checks**

#### **Make sure everything is working:**

Bash

```
# Check Nginx errors
sudo tail -100 /var/log/nginx/error.log

# Check if PHP is working (if applicable)
curl -I http://localhost/index.php

# Check SSL certificates
sudo certbot renew --dry-run

# Check cron jobs
crontab -l
```

------

## **4. If Problems Arise**

#### **Common errors and solutions:**

| **Problem**                         | **Solution**                                                 |
| ----------------------------------- | ------------------------------------------------------------ |
| **Nginx not working after restart** | `sudo nginx -t` (check configs) → Compare with converted files from `nginx_converted/` |
| **PHP not working**                 | Make sure `php-fpm` is running: `sudo systemctl status php8.1-fpm` |
| **SSL errors**                      | Renew certificates: `sudo certbot --nginx -d your_domain.lv` |
| **403 Forbidden (static files)**    | Check `root` path in Nginx config and file permissions (`chmod -R 755 /var/www`) |

------

### **🌐 Additional Actions (If Necessary)**

- Manually convert specific Apache rules

   (e.g., 

  ```
  .htaccess
  ```

  ):

  Nginx

  ```
  # Example: Rewrite .htaccess rewrite rules
  location / {
      try_files $uri $uri/ /index.php?$args;
  }
  ```

- **Update DNS records** if migrating to a different server IP.

------

### **✅ Done!**

If everything is done correctly, the new server will have:

- **Nginx** (instead of Apache)
- **All domains and SSL certificates**
- **Cron jobs and keys**

