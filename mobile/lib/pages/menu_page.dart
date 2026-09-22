import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Manajemen Menu — GET /products?includeInactive=1 + /categories,
/// simpan via POST/PATCH /products.
class MenuPage extends StatefulWidget {
  final AppUser user;
  const MenuPage({super.key, required this.user});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> categories = [];
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
      ]);
      if (mounted) {
        setState(() {
          products = (results[0] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          categories = (results[1] as List)
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

  String _catLabel(String key) {
    for (final c in categories) {
      if ('${c['key']}' == key) return '${c['label']}';
    }
    return key;
  }

  Future<void> _openForm(Map<String, dynamic>? existing) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(existing == null ? 'Menu Baru' : 'Edit Menu',
              style: AppText.display(size: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama Menu')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
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
            const SizedBox(height: 12),
            TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Harga Jual (Rp)')),
            const SizedBox(height: 12),
            TextField(
                controller: hpp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'HPP (Rp)')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Tersedia dijual',
                  style: AppText.body(size: 13, weight: FontWeight.w600)),
              value: available,
              activeThumbColor: AppColors.chili,
              onChanged: (v) => setD(() => available = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Menu aktif',
                  style: AppText.body(size: 13, weight: FontWeight.w600)),
              value: active,
              activeThumbColor: AppColors.chili,
              onChanged: (v) => setD(() => active = v),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.chili, elevation: 0),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final body = {
        'name': name.text.trim(),
        'category_id': catId,
        'price': num.tryParse(price.text) ?? 0,
        'hpp': num.tryParse(hpp.text) ?? 0,
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
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 2.1,
            children: [
              StatCard(
                  icon: Icons.restaurant_menu,
                  iconColor: AppColors.char,
                  iconBg: AppColors.char.withValues(alpha: 0.05),
                  value: '${products.length}',
                  label: 'Total Menu'),
              StatCard(
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.greenOk,
                  iconBg: AppColors.greenBg,
                  value: '$avail',
                  label: 'Tersedia'),
              StatCard(
                  icon: Icons.error_outline,
                  iconColor: AppColors.chili,
                  iconBg: AppColors.redBg,
                  value: '${products.length - avail}',
                  label: 'Habis / Nonaktif'),
            ],
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
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.chili.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          '${p['image_url'] ?? ''}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.ramen_dining,
                              color: AppColors.chili.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    title: Text('${p['name']}',
                        style:
                            AppText.body(size: 14, weight: FontWeight.w700)),
                    subtitle: Text(
                        '${_catLabel('${p['category']}')} · HPP ${formatRp(num.tryParse('${p['hpp']}') ?? 0)}',
                        style:
                            AppText.body(size: 11, color: Colors.black45)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            formatRp(num.tryParse('${p['price']}') ?? 0),
                            style: AppText.body(
                                size: 14,
                                weight: FontWeight.w700,
                                color: AppColors.chili)),
                        const SizedBox(width: 10),
                        (p['is_active'] == 1 || p['is_active'] == true) &&
                                (p['is_available'] == 1 ||
                                    p['is_available'] == true)
                            ? StatusChip.ok('Tersedia')
                            : StatusChip.danger('Habis'),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _openForm(p),
                        ),
                      ],
                    ),
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
