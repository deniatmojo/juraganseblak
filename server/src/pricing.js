// Hitung rincian tagihan — satu sumber kebenaran untuk POS & pesanan online.
//   pajak / biaya layanan = persen dari subtotal (dibulatkan ke rupiah)
//   pembulatan = naik ke kelipatan rounding_step (mis. 1000: 4.200 → 5.000);
//   rounding_step 0 = tanpa pembulatan.
export function computeTotals(subtotal, { tax_rate = 0, service_rate = 0, rounding_step = 0 } = {}, discount = 0) {
  const tax = Math.round(subtotal * tax_rate);
  const service = Math.round(subtotal * service_rate);
  const raw = subtotal + tax + service - Number(discount || 0);
  const step = Number(rounding_step) || 0;
  const total = step > 0 ? Math.ceil(raw / step) * step : raw;
  return { tax, service, rounding: total - raw, total };
}
