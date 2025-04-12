### **🛠️ Apvienotais Backup & Restore Skripts (Viss vienā!)**
Lai izvairītos no konfliktiem un vienkāršotu procesu, es apvienoju visus 4 skriptus vienā:

#### **📌 1. `full_server_backup.sh`** (Backupo VISU: atslēgas, hostname, SSL, timezone, web konfigus)
```bash
#!/bin/bash
# =========================================
# UNIVERSĀLAIS SERVERA BACKUP (Viss 1 failā)
# =========================================

BACKUP_DIR="/root/full_server_backup_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

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
```

#### **📌 2. `full_server_restore.sh`** (Atjauno VISU no backup)
```bash
#!/bin/bash
# =========================================
# UNIVERSĀLAIS SERVERA RESTORE (Viss no 1 faila)
# =========================================

[ -z "$1" ] && echo "❌ Lietojums: $0 full_server_backup_YYYYMMDD.tar.gz" && exit 1

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
```

---

### **⭐ Galvenās priekšrocības:**
1. **Viss 1 failā** - nav vairs 4 atsevišķi backupi
2. **Nekonfliktē** - skripti darbosies secīgi, nevis pārrakstīs viens otru
3. **Vienkārša migrācija** starp serveriem

---

### **📚 Lietošanas instrukcija:**
#### **Backup:**
```bash
chmod +x full_server_backup.sh
./full_server_backup.sh  # Izveido /root/full_server_backup_YYYYMMDD.tar.gz
```

#### **Restore:**
```bash
scp full_server_backup_YYYYMMDD.tar.gz jaunais_serveris:/root/
chmod +x full_server_restore.sh
./full_server_restore.sh full_server_backup_YYYYMMDD.tar.gz
reboot
```

---

### **🔐 Drošības padomi:**
1. **Šifrē backup** pirms pārsūtīšanas:
   ```bash
   gpg -c full_server_backup_YYYYMMDD.tar.gz
   ```
2. **Pārliecinies**, ka jaunajam serverim ir:
   - Tāds pats OS (Ubuntu/Debian/CentOS)
   - Instalēti pamata pakotnes (nginx, certbot u.c.)



### **🔄 Izmaiņas, ja pāriet no Apache uz Nginx (backup/restore kontekstā)**

Ja vecajā serverī bija **Apache**, bet jaunajā instalē **Nginx**, ir vajadzīgas šādas korekcijas, lai migrācija notiktu bez problēmām:

---

## **1. Backup Pielāgojumi (`full_server_backup.sh`)**
Pievieno **konversijas filtrus**, lai automātiski pārveidotu Apache konfigus uz Nginx saderīgu formātu:

```bash
# =====[ WEB SERVER BACKUP ]=====
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
```

### **Obligāti darbības pirms backup:**
1. Instalē **apache2nginx** rīku:
   ```bash
   sudo apt install -y apache2-utils  # Debian/Ubuntu
   sudo yum install -y httpd-tools    # CentOS
   ```

---

## **2. Restore Pielāgojumi (`full_server_restore.sh`)**
Aizstāj Apache konfigus ar pārveidotajiem Nginx failiem:

```bash
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
```

---

## **3. Būtiskās Izmaiņas Konfigos**
Nginx neizprot Apache direktīvas, tāpēc konvertējot, mainās:

| **Apache Direktīva**       | **Nginx Ekvivalents**          |
|---------------------------|-------------------------------|
| `DocumentRoot /path`      | `root /path;`                |
| `<VirtualHost *:80>`      | `server { listen 80; ... }`  |
| `ErrorLog logs/error.log` | `error_log /path/error.log;` |
| `RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]` | `rewrite ^/(.*)$ /index.php?q=$1 last;` |

---

## **4. Manuālie Pārbaudes Soļi Pēc Restore**
1. **Pārbauda, vai Nginx apstrādā PHP**:
   ```nginx
   location ~ \.php$ {
     fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
     include fastcgi_params;
   }
   ```
2. **Atjaunina SSL sertifikātu ceļus** (ja bija Apache `SSLCertificateFile`):
   ```nginx
   ssl_certificate /etc/letsencrypt/live/domains/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/domains/privkey.pem;
   ```
3. **Pārliecinies, ka statiskie faili tiek apkalpoti**:
   ```nginx
   location /static/ {
     alias /var/www/html/static/;
   }
   ```

---

## **5. Pilns Migrācijas Process**
```mermaid
flowchart TD
    A[Veic pilnu backup ar full_server_backup.sh] --> B[Konvertē Apache konfigus uz Nginx]
    B --> C[Instalē Nginx jaunajā serverī]
    C --> D[Restore no backup ar full_server_restore.sh]
    D --> E[Pārbauda žurnālus: journalctl -u nginx -f]
```

---

### **⚠️ Svarīgi!**
- **Neaizstāj vienlaikus abus serverus** — vispirms pārbaudi jauno konfigurāciju.  
- **Izmanto `nginx -t` pirms restartēšanas**, lai pārbaudītu sintakses kļūdas.  
- **Migrē pa vienam domēnam**, nevis visus uzreiz.  

Ja rodas kļūdas, pārbaudi:  
```bash
sudo tail -100 /var/log/nginx/error.log
```


### **🔧 Komandas Migrācijai ar Jūsu GitHub Repozitoriju**  
Tā kā esat ievietojis backup/restore skriptus GitHub ([Trusardi/server_backup_restore](https://github.com/Trusardi/server_backup_restore)), šeit ir **konkrētas komandas**, lai migrētu no vecā servera (ar Apache) uz jauno (ar Nginx):

---

## **1. Vecajā Serverī (Backup)**
#### **Lejupielādē un palaid backup skriptu no GitHub:**
```bash
# Lejupielādē skriptus no GitHub
git clone git@github.com:Trusardi/server_backup_restore.git
cd server_backup_restore

# Padara skriptus izpildāmus
chmod +x full_server_backup.sh

# Instalē nepieciešamos rīkus (Apache -> Nginx konversijai)
sudo apt install -y apache2-utils  # Debian/Ubuntu
sudo yum install -y httpd-tools    # CentOS

# Palaid pilnu backup (ar Apache konfigu konversiju uz Nginx)
./full_server_backup.sh
```
**Rezultāts:**  
Backup fails tiks saglabāts vecajā serverī:  
`/root/full_server_backup_YYYYMMDD.tar.gz`

---

## **2. Jaunajā Serverī (Restore)**
#### **Lejupielādē backup un palaid restore:**
```bash
# Lejupielādē skriptus no GitHub
git clone git@github.com:Trusardi/server_backup_restore.git
cd server_backup_restore
chmod +x full_server_restore.sh

# Lejupielādē backup failu no vecā servera (izmantojot SCP)
scp root@vecais_serveris:/root/full_server_backup_*.tar.gz .

# Palaid restore (ar Nginx konfigiem)
./full_server_restore.sh full_server_backup_YYYYMMDD.tar.gz

# Pārbauda, vai Nginx strādā
sudo nginx -t && sudo systemctl restart nginx
```

---

## **3. Pārbaudes Pēc Migrācijas**
#### **Pārliecinies, ka viss darbojas:**
```bash
# Pārbauda Nginx kļūdas
sudo tail -100 /var/log/nginx/error.log

# Pārbauda, vai PHP darbojas (ja ir)
curl -I http://localhost/index.php

# Pārbauda SSL sertifikātus
sudo certbot renew --dry-run

# Pārbauda cron uzdevumus
crontab -l
```

---

## **4. Ja Rodas Problēmas**
#### **Biežākās kļūdas un risinājumi:**
| **Problēma**                  | **Risinājums**                                                                 |
|-------------------------------|-------------------------------------------------------------------------------|
| **Nginx nestrādā pēc restart** | `sudo nginx -t` (pārbauda konfigus) → Salīdzini ar konvertētajiem failiem no `nginx_converted/` |
| **PHP nestrādā**              | Pārliecinies, ka `php-fpm` ir palaists: `sudo systemctl status php8.1-fpm`    |
| **SSL kļūdas**                | Atjaunini sertifikātus: `sudo certbot --nginx -d tavs_domēns.lv`              |
| **403 Forbidden (statiskie faili)** | Pārbauda `root` ceļu Nginx konfigā un failu atļaujas (`chmod -R 755 /var/www`) |

---

### **🌐 Papildu Darbības (Ja Nepieciešams)**
- **Manuāli pārveido specifiskus Apache noteikumus** (piem., `.htaccess`):  
  ```nginx
  # Piemērs: Pārraksta .htaccess rewrite noteikumus
  location / {
      try_files $uri $uri/ /index.php?$args;
  }
  ```
- **Atjaunini DNS ierakstus**, ja migrē uz citu servera IP.

---

### **✅ Gatavs!**  
Ja viss izdarīts pareizi, jaunajā serverī būs:  
- **Nginx** (nevis Apache)  
- **Visi domēni un SSL sertifikāti**  
- **Cron uzdevumi un atslēgas**  

Ja kaut kas nav skaidrs, raksti! 🚀
