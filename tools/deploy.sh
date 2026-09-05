#!/bin/bash
# Deploy Juragan Seblak: git pull + copy hasil build ke docroot.
# Jalankan di server: bash /www/wwwroot/template-one.airadynamics.com/deploy.sh
set -e
SITE=/www/wwwroot/template-one.airadynamics.com
cd "$SITE"
sudo git pull origin main
sudo find "$SITE" -mindepth 1 -maxdepth 1 \
  ! -name '.well-known' ! -name '.user.ini' ! -name '.git' \
  ! -name 'web' ! -name 'tools' ! -name 'database' ! -name 'deploy.sh' \
  ! -name '.gitignore' ! -name '.graphifyignore' -exec rm -rf {} +
sudo cp -r "$SITE/web/dist/." "$SITE/"
sudo chown -R www:www "$SITE"
sudo chown -R deniatmojoo:www "$SITE/.git" "$SITE/deploy.sh" 2>/dev/null || true
echo "Deploy selesai."
