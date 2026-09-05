#!/bin/bash
set -e
SITE=/www/wwwroot/template-one.airadynamics.com
MYSQLROOT=$(sudo sqlite3 /www/server/panel/data/default.db "select mysql_root from config;")
my() { mysql -u root -p"$MYSQLROOT" "$@"; }

echo "== Setup database MariaDB =="
DBPASS=$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
my <<SQL
CREATE DATABASE IF NOT EXISTS juragan_seblak CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'seblak_app'@'localhost' IDENTIFIED BY '${DBPASS}';
ALTER USER 'seblak_app'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT ALL PRIVILEGES ON juragan_seblak.* TO 'seblak_app'@'localhost';
FLUSH PRIVILEGES;
SQL
my juragan_seblak < "$SITE/database/schema.sql"
my -e "SELECT COUNT(*) AS jumlah_produk FROM juragan_seblak.products; SHOW TABLES IN juragan_seblak;"

echo "== Simpan kredensial =="
sudo tee /www/wwwroot/juragan_seblak.env > /dev/null <<EOF
# Kredensial database Juragan Seblak (jangan commit ke git)
DB_HOST=localhost
DB_NAME=juragan_seblak
DB_USER=seblak_app
DB_PASS=${DBPASS}
EOF
sudo chmod 600 /www/wwwroot/juragan_seblak.env
sudo chown deniatmojoo:www /www/wwwroot/juragan_seblak.env
sudo cat /www/wwwroot/juragan_seblak.env
echo "== SELESAI =="
