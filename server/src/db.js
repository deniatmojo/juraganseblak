import mysql from 'mysql2/promise';

export const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'juragan_seblak',
  waitForConnections: true,
  connectionLimit: 10,
  namedPlaceholders: true,
  dateStrings: true,
});
// Kunci semua NOW()/CURDATE()/DATE_FORMAT MySQL ke WIB (+07:00) — mesin server
// produksi berjalan UTC, tanpa ini absen/nomor order antara 00:00–07:00 WIB
// tercatat mundur sehari.
pool.on('connection', (conn) => conn.query("SET time_zone = '+07:00'"));
