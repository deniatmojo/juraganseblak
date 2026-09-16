#!/bin/bash
# Deploy Juragan Seblak: git pull + static site + backend API (PM2).
# Jalankan di server: bash /www/wwwroot/template-one.airadynamics.com/deploy.sh
set -e
SITE=/www/wwwroot/template-one.airadynamics.com
cd "$SITE"
git config --global --add safe.directory "$SITE" 2>/dev/null || true
sudo git config --global --add safe.directory "$SITE" 2>/dev/null || true
sudo git pull origin main

# Static: bersihkan docroot kecuali folder yang dipertahankan (server/ = backend API)
sudo find "$SITE" -mindepth 1 -maxdepth 1 \
  ! -name '.well-known' ! -name '.user.ini' ! -name '.git' \
  ! -name 'web' ! -name 'tools' ! -name 'database' ! -name 'server' \
  ! -name 'deploy.sh' ! -name '.gitignore' ! -name '.graphifyignore' \
  ! -name 'AGENTS.md' ! -name 'GRAPHIFY_SETUP.md' ! -name '*.bat' \
  -exec rm -rf {} +
sudo cp -r "$SITE/web/dist/." "$SITE/"

# Backend API (Express + PM2)
cd "$SITE/server"
sudo npm install --omit=dev --no-audit --no-fund
sudo mkdir -p uploads
# .env dibuat sekali (tidak ditimpa deploy berikutnya)
if [ ! -f .env ]; then
  DB_PASS_VAL=$(grep '^DB_PASS=' /www/wwwroot/juragan_seblak.env | cut -d= -f2)
  JWT_VAL=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 64)
  sudo bash -c "cat > .env <<EOF
PORT=3001
DB_HOST=localhost
DB_PORT=3306
DB_NAME=juragan_seblak
DB_USER=seblak_app
DB_PASS=$DB_PASS_VAL
JWT_SECRET=$JWT_VAL
EOF"
  echo ".env backend dibuat."
fi
if sudo pm2 describe juragan-seblak-api > /dev/null 2>&1; then
  sudo pm2 restart juragan-seblak-api
else
  sudo pm2 start src/index.js --name juragan-seblak-api
fi
sudo pm2 save

# .user.ini milik aaPanel immutable — jangan sampai chown menggagalkan deploy
sudo chown -R www:www "$SITE" 2>/dev/null || true
sudo chattr -i "$SITE/.user.ini" 2>/dev/null || true
sudo chown deniatmojoo:www "$SITE/.user.ini" 2>/dev/null || true
sudo chown -R deniatmojoo:www "$SITE/.git" "$SITE/deploy.sh" "$SITE/server/.env" 2>/dev/null || true
echo "Deploy selesai."
