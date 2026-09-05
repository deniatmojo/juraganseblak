#!/bin/bash
set -e
SITE=/www/wwwroot/template-one.airadynamics.com
REPO=https://github.com/deniatmojo/juraganseblak.git

echo "== 1. Bersihkan file lama (keep .well-known & .user.ini) =="
sudo find "$SITE" -mindepth 1 -maxdepth 1 \
  ! -name '.well-known' ! -name '.user.ini' -exec rm -rf {} +

echo "== 2. Clone repo =="
sudo chown deniatmojoo:www "$SITE"
cd "$SITE"
git config --global --add safe.directory "$SITE"
git init -q .
git remote add origin "$REPO" 2>/dev/null || git remote set-url origin "$REPO"
git fetch -q origin
git reset -q --hard origin/main

echo "== 3. Deploy hasil build (web/dist) ke docroot =="
sudo cp -r "$SITE/web/dist/." "$SITE/"

echo "== 4. Script deploy untuk update berikutnya =="
cat > "$SITE/deploy.sh" <<'EOF'
#!/bin/bash
set -e
SITE=/www/wwwroot/template-one.airadynamics.com
cd "$SITE"
git pull origin main
find "$SITE" -mindepth 1 -maxdepth 1 \
  ! -name '.well-known' ! -name '.user.ini' ! -name '.git' \
  ! -name 'web' ! -name 'tools' ! -name 'database' ! -name 'deploy.sh' \
  ! -name 'README.md' ! -name 'AGENTS.md' ! -name 'GRAPHIFY_SETUP.md' \
  ! -name 'graphify-on.bat' ! -name 'graphify-off.bat' \
  ! -name 'graphify-status.bat' ! -name 'graphify-report.bat' \
  ! -name '.gitignore' ! -name '.graphifyignore' -exec rm -rf {} +
cp -r web/dist/. "$SITE/"
echo "Deploy selesai."
EOF
chmod +x "$SITE/deploy.sh"

echo "== 5. Setup database MariaDB =="
DBPASS=$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS juragan_seblak CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'seblak_app'@'localhost' IDENTIFIED BY '${DBPASS}';
ALTER USER 'seblak_app'@'localhost' IDENTIFIED BY '${DBPASS}';
GRANT ALL PRIVILEGES ON juragan_seblak.* TO 'seblak_app'@'localhost';
FLUSH PRIVILEGES;
SQL
sudo mysql juragan_seblak < "$SITE/database/schema.sql"
sudo mysql -e "SELECT COUNT(*) AS produk FROM juragan_seblak.products;"

echo "== 6. Simpan kredensial (di luar docroot) =="
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

echo "== 7. Perbaiki kepemilikan file web =="
sudo chown -R www:www "$SITE" --except-of 2>/dev/null || sudo bash -c "chown -R www:www '$SITE' && chown -R deniatmojoo:www '$SITE/.git' && chown deniatmojoo:www '$SITE/deploy.sh'"
echo "== SELESAI =="
ls -la "$SITE" | head -25
