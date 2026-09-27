import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Manajemen Menu — menyalin web/src/pages/admin/Menu.jsx:
/// kategori CRUD (POST/DELETE /categories), CRUD menu (POST/PATCH/DELETE
/// /products), toggle Set Habis/Tersedia, foto via URL atau upload
/// (/api/upload), dan editor Bahan Stok Terhubung (stock_links).
class MenuPage extends StatefulWidget {
  final AppUser user;
  const MenuPage({super.key, required this.user});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> stockItems = [];
  String search = '';
  String activeCat = 'semua';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        api.get('/products?includeInactive=1'),
        api.get('/categories'),
        api.get('/stock'),
      ]);
      if (mounted) {
        setState(() {
          products = (results[0] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          categories = (results[1] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          stockItems = (results[2] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// URL gambar: path relatif /uploads/... di-resolve ke origin server.
  String _imgUrl(dynamic path) {
    final s = '$path';
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    return ApiClient.baseUrl.replaceAll(RegExp(r'/api$'), '') + s;
  }

  String _catLabel(String key) {
    for (final c in categories) {
      if ('${c['key']}' == key) return '${c['label']}';
    }
    return key;
  }

  /// Teks kolom "Bahan" — daftar "nama (qty)" dipisah koma (web Menu.jsx:254-257).
  String linksText(Map<String, dynamic> p) {
    if (p['stock_links'] is! List || (p['stock_links'] as List).isEmpty) {
      return 'tidak terhubung';
    }
    return (p['stock_links'] as List).map((l) {
      final m = Map<String, dynamic>.from(l as Map);
      return '${m['stock_item_name'] ?? '?'} (${m['qty_per_unit']})';
    }).join(', ');
  }

  // ---- Kategori (web Menu.jsx:135-151) ----
  Future<void> _addCategory(String labelRaw) async {
    final label = labelRaw.trim();
    if (label.isEmpty) return;
    try {
      await api.post('/categories', {
        'key': label.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
        'label': label,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _removeCategory(Map<String, dynamic> c) async {
    final ok = await _confirm('Hapus kategori "${c['label']}"?');
    if (ok != true) return;
    try {
      await api.del('/categories/${c['id']}');
      if (activeCat == '${c['key']}') activeCat = 'semua';
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ---- Aksi per menu (web Menu.jsx:120-133) ----
  Future<void> _toggleAvailable(Map<String, dynamic> p) async {
    try {
      await api.patch('/products/${p['id']}', {
        'is_available':
            (p['is_available'] == 1 || p['is_available'] == true) ? 0 : 1,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _deactivate(Map<String, dynamic> p) async {
    final ok = await _confirm(
        'Nonaktifkan "${p['name']}"? Menu tidak akan tampil di POS.');
    if (ok != true) return;
    try {
      await api.del('/products/${p['id']}');
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<bool?> _confirm(String message) {
    return showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(message, style: AppText.body(size: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.chili, elevation: 0),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }

  /// Upload foto via galeri — padanan input file web (maks 2MB, jpg/png/webp).
  Future<void> _pickAndUpload(
      void Function(String url) onUploaded, void Function(String msg) onError,
      {required void Function(bool) setUploading}) async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80, maxWidth: 1400);
      if (img == null) return;
      setUploading(true);
      final bytes = await File(img.path).length() > 0
          ? await File(img.path).readAsBytes()
          : <int>[];
      final ext = img.path.toLowerCase().endsWith('.png')
          ? 'png'
          : img.path.toLowerCase().endsWith('.webp')
              ? 'webp'
              : 'jpg';
      final data = await api.upload('/upload',
          field: 'photo',
          filename: 'menu.$ext',
          bytes: bytes,
          contentType: 'image/$ext');
      onUploaded('${data['url']}');
    } catch (e) {
      onError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setUploading(false);
    }
  }

  /// Modal Tambah/Edit Menu — menyalin web Menu.jsx:287-364 termasuk
  /// editor Bahan Stok Terhubung (dropdown bahan + takaran per porsi).
  Future<void> _openForm(Map<String, dynamic>? existing) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final imageUrl =
        TextEditingController(text: '${existing?['image_url'] ?? ''}');
    final price = TextEditingController(
        text: existing != null && existing['price'] != null
            ? '${existing['price']}'
            : '');
    final hpp = TextEditingController(
        text: existing != null && existing['hpp'] != null
            ? '${existing['hpp']}'
            : '');
    int? catId = existing != null && existing['category_id'] != null
        ? int.tryParse('${existing['category_id']}')
        : (categories.isNotEmpty ? int.tryParse('${categories.first['id']}') : null);
    bool available = existing?['is_available'] == 1 ||
        existing?['is_available'] == true ||
        existing == null;
    bool active = existing?['is_active'] == 1 ||
        existing?['is_active'] == true ||
        existing == null;
    bool uploading = false;
    String? formError;

    // Baris link bahan: pasangan (stock_item_id, controller takaran).
    final links = <MapEntry<int?, TextEditingController>>[];
    if (existing != null && existing['stock_links'] is List) {
      for (final l in (existing['stock_links'] as List)) {
        final lm = Map<String, dynamic>.from(l as Map);
        links.add(MapEntry(int.tryParse('${lm['stock_item_id']}'),
            TextEditingController(text: '${lm['qty_per_unit']}')));
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Menu Baru' : 'Edit Menu',
                  style: AppText.display(size: 18)),
              if (formError != null) ...[
                const SizedBox(height: 10),
                Text(formError!,
                    style: AppText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.chili)),
              ],
              const SizedBox(height: 16),
              TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nama Menu')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: catId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem(
                            value: int.tryParse('${c['id']}'),
                            child: Text('${c['label']}')),
                    ],
                    onChanged: (v) => setD(() => catId = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                      controller: imageUrl,
                      decoration: const InputDecoration(
                          labelText: 'URL Foto',
                          hintText: '/images/...')),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.char,
                        side: const BorderSide(color: Colors.black12),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: uploading
                        ? null
                        : () => _pickAndUpload(
                              (url) => setD(() {
                                imageUrl.text = url;
                                formError = null;
                              }),
                              (msg) => setD(() => formError = msg),
                              setUploading: (v) => setD(() => uploading = v),
                            ),
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text('Upload Foto',
                        style: AppText.body(size: 12, weight: FontWeight.w700)),
                  ),
                ),
                if (uploading) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 6),
                  Text('Mengunggah...',
                      style: AppText.body(size: 11, color: Colors.black45)),
                ],
                if (imageUrl.text.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Image.network(_imgUrl(imageUrl.text),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Harga Jual (Rp)')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                      controller: hpp,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'HPP (modal)')),
                ),
              ]),
              const SizedBox(height: 16),
              Text('Bahan Stok Terhubung (bisa lebih dari satu)',
                  style: AppText.body(size: 12, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (var i = 0; i < links.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: links[i].key,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: '— pilih bahan —',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: [
                          for (final s in stockItems)
                            DropdownMenuItem(
                                value: int.tryParse('${s['id']}'),
                                child: Text(
                                    '${s['name']} (${s['unit']}) — sisa ${s['qty']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) =>
                            setD(() => links[i] =
                                MapEntry(v, links[i].value)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 88,
                      child: TextField(
                        controller: links[i].value,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                            labelText: 'per porsi',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.chili),
                      onPressed: () =>
                          setD(() => links.removeAt(i)),
                    ),
                  ]),
                ),
              TextButton.icon(
                onPressed: () => setD(() => links.add(
                    MapEntry(null, TextEditingController(text: '1')))),
                icon: const Icon(Icons.add, size: 16),
                label: Text('+ Tambah Bahan',
                    style: AppText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.chili)),
              ),
              Text(
                'Angka di kanan = takaran terpakai per 1 porsi (mis. 0.15 kg beras). Stok semua bahan berkurang otomatis saat POS menjual menu ini, dan nilai persediaannya masuk ke HPP Laba Rugi.',
                style: AppText.body(size: 10, color: Colors.black38),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Tersedia hari ini',
                    style: AppText.body(size: 13, weight: FontWeight.w600)),
                value: available,
                activeThumbColor: AppColors.chili,
                onChanged: (v) => setD(() => available = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Aktif',
                    style: AppText.body(size: 13, weight: FontWeight.w600)),
                value: active,
                activeThumbColor: AppColors.chili,
                onChanged: (v) => setD(() => active = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(d, false),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black12),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.chili,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('Simpan'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final stockLinks = [
        for (final l in links)
          if (l.key != null && (num.tryParse(l.value.text) ?? 0) > 0)
            {'stock_item_id': l.key, 'qty_per_unit': num.tryParse(l.value.text)},
      ];
      final body = {
        'name': name.text.trim(),
        'category_id': catId,
        'price': num.tryParse(price.text) ?? 0,
        'hpp': num.tryParse(hpp.text) ?? 0,
        'image_url': imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
        'stock_links': stockLinks,
        'is_available': available ? 1 : 0,
        'is_active': active ? 1 : 0,
      };
      if (existing == null) {
        await api.post('/products', body);
      } else {
        await api.patch('/products/${existing['id']}', body);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.chili));
    }
    final filtered = products
        .where((p) =>
            (activeCat == 'semua' || '${p['category']}' == activeCat) &&
            '${p['name']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList();
    final avail = products
        .where((p) =>
            (p['is_active'] == 1 || p['is_active'] == true) &&
            (p['is_available'] == 1 || p['is_available'] == true))
        .length;

    return RefreshIndicator(
      color: AppColors.chili,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(error!,
                  style: AppText.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.chili)),
            ),
          Row(children: [
            Expanded(
                child: StatCardRow(
                    icon: Icons.restaurant_menu,
                    iconColor: AppColors.char,
                    iconBg: AppColors.char.withValues(alpha: 0.05),
                    value: '${products.length}',
                    label: 'Total Menu')),
            const SizedBox(width: 10),
            Expanded(
                child: StatCardRow(
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.greenOk,
                    iconBg: AppColors.greenBg,
                    value: '$avail',
                    label: 'Tersedia')),
            const SizedBox(width: 10),
            Expanded(
                child: StatCardRow(
                    icon: Icons.error_outline,
                    iconColor: AppColors.chili,
                    iconBg: AppColors.redBg,
                    value: '${products.length - avail}',
                    label: 'Habis')),
          ]),
          const SizedBox(height: 20),
          // ---- Section Kategori (web Menu.jsx:173-192) ----
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Kategori',
                  style: AppText.body(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    Container(
                      padding: const EdgeInsets.only(left: 14, right: 4),
                      decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.black12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${c['label']}',
                            style: AppText.body(
                                size: 12, weight: FontWeight.w700)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close,
                              size: 14, color: Colors.black45),
                          tooltip: 'Hapus kategori',
                          onPressed: () => _removeCategory(c),
                        ),
                      ]),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _NewCategoryRow(onAdd: _addCategory),
            ]),
          ),
          const SizedBox(height: 20),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => search = v),
                        decoration: InputDecoration(
                          hintText: 'Cari menu...',
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.black26),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.chili,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999))),
                      onPressed: () => _openForm(null),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Menu Baru',
                          style: AppText.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ]),
                ),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      for (final c in [
                        ('semua', 'Semua'),
                        ...categories.map((c) => ('${c['key']}', '${c['label']}')),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.$2),
                            selected: activeCat == c.$1,
                            onSelected: (_) =>
                                setState(() => activeCat = c.$1),
                            labelStyle: AppText.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: activeCat == c.$1
                                    ? Colors.white
                                    : Colors.black54),
                            selectedColor: AppColors.char,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.black12),
                            showCheckmark: false,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                for (final p in filtered)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Column(children: [
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.chili.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _imgUrl(p['image_url']),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.ramen_dining,
                                  color: AppColors.chili.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p['name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                      size: 13, weight: FontWeight.w700)),
                              Text(
                                  '${_catLabel('${p['category']}')} · HPP ${p['hpp'] != null && num.tryParse('${p['hpp']}') != null && num.tryParse('${p['hpp']}')! > 0 ? formatRp(num.tryParse('${p['hpp']}')!) : '-'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                      size: 11, color: Colors.black45)),
                              Text(
                                  'Bahan: ${linksText(p)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                      size: 11, color: Colors.black38)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                formatRp(num.tryParse('${p['price']}') ?? 0),
                                style: AppText.body(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: AppColors.chili)),
                            (p['is_active'] == 1 || p['is_active'] == true)
                                ? ((p['is_available'] == 1 ||
                                        p['is_available'] == true)
                                    ? StatusChip.ok('Tersedia')
                                    : StatusChip.danger('Habis'))
                                : StatusChip(
                                    'Nonaktif',
                                    fg: Colors.black45,
                                    bg: Colors.black.withValues(alpha: 0.05)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 8),
                      // ---- Aksi per baris (web Menu.jsx:268-278) ----
                      Row(children: [
                        if (p['is_active'] == 1 || p['is_active'] == true)
                          TextButton(
                            onPressed: () => _toggleAvailable(p),
                            child: Text(
                                (p['is_available'] == 1 ||
                                        p['is_available'] == true)
                                    ? 'Set Habis'
                                    : 'Set Tersedia',
                                style: AppText.body(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: Colors.black54)),
                          ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.char,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8)),
                          onPressed: () => _openForm(p),
                          child: Text('Edit',
                              style: AppText.body(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                        if (p['is_active'] == 1 || p['is_active'] == true) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _deactivate(p),
                            child: Text('Hapus',
                                style: AppText.body(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: AppColors.chili)),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child: Text('Menu tidak ditemukan.',
                            style: AppText.body(
                                size: 13, color: Colors.black26))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris input "Kategori baru..." + tombol Tambah (web Menu.jsx:181-191).
class _NewCategoryRow extends StatefulWidget {
  final ValueChanged<String> onAdd;
  const _NewCategoryRow({required this.onAdd});

  @override
  State<_NewCategoryRow> createState() => _NewCategoryRowState();
}

class _NewCategoryRowState extends State<_NewCategoryRow> {
  final ctrl = TextEditingController();

  void _submit() {
    if (ctrl.text.trim().isEmpty) return;
    widget.onAdd(ctrl.text);
    ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: ctrl,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
              hintText: 'Kategori baru...',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        ),
      ),
      const SizedBox(width: 10),
      FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: AppColors.char,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
        onPressed: _submit,
        child: Text('Tambah',
            style: AppText.body(
                size: 12, weight: FontWeight.w700, color: Colors.white)),
      ),
    ]);
  }
}
