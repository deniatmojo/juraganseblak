# API Juragan Seblak

Backend Express + MySQL (port 3306, database `juragan_seblak`).

## Setup lokal

1. Pastikan MySQL 3306 jalan lalu import skema:
   `mysql -u root -p < ../database/schema.sql`
   (Instalasi lama: jalankan juga `../database/migrate-01-pos.sql`)
2. `cp .env.example .env` lalu isi kredensial DB.
3. `npm install`
4. `npm run dev` — API jalan di `http://localhost:3001`.

Frontend dev (Vite) otomatis proxy-kan `/api` ke port 3001.

## Endpoint (fase 1)

- `GET /api/health`
- `GET|POST|PATCH|DELETE /api/products` (`?category=paket`, `?includeInactive=1`)
- `GET|POST|DELETE /api/categories`
- `GET|PATCH /api/settings` — `tax_rate`, `service_rate`, `store_name`, `receipt_footer`
- `POST /api/orders` — checkout (harga/pajak dihitung server-side, kurangi stok, catat transaksi)
- `GET /api/orders?from=&to=&status=` — riwayat
- `GET /api/orders/:id` — detail pesanan

Autentikasi API belum ada (JWT menyusul di modul Auth). Jika `API_KEY` diisi di `.env`,
semua request harus mengirim header `x-api-key`.
