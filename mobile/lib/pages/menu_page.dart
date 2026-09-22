import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Manajemen Menu — daftar menu + form tambah/edit (lokal, Tahap 1).
class MenuPage extends StatefulWidget {
  final AppUser user;
  const MenuPage({super.key, required this.user});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<MenuItem> products = List.of(MockData.menu);
  String search = '';
  String activeCat = 'semua';

  @override
  Widget build(BuildContext context) {
    final filtered = products
        .where((p) =>
            (activeCat == 'semua' || p.category == activeCat) &&
            p.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    final available =
        products.where((p) => p.isAvailable).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Expanded(
            child: GridView.count(
              crossAxisCount:
                  MediaQuery.of(context).size.width > 640 ? 3 : 3,
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
                    value: '$available',
                    label: 'Tersedia'),
                StatCard(
                    icon: Icons.error_outline,
                    iconColor: AppColors.chili,
                    iconBg: AppColors.redBg,
                    value: '${products.length - available}',
                    label: 'Habis / Nonaktif'),
              ],
            ),
          ),
        ]),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
                      ...MockData.categories.map((c) => (c.key, c.label)),
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
                    child: Icon(Icons.ramen_dining,
                        color: AppColors.chili.withValues(alpha: 0.5)),
                  ),
                  title: Text(p.name,
                      style:
                          AppText.body(size: 14, weight: FontWeight.w700)),
                  subtitle: Text(
                      '${catLabel(p.category)} · HPP ${formatRp(p.hpp)}',
                      style: AppText.body(size: 11, color: Colors.black45)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatRp(p.price),
                          style: AppText.body(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.chili)),
                      const SizedBox(width: 10),
                      p.isAvailable
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
    );
  }

  String catLabel(String key) =>
      MockData.categories.firstWhere((c) => c.key == key,
          orElse: () => const Category('', 'Lainnya')).label;

  void _openForm(MenuItem? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final price = TextEditingController(
        text: existing != null ? '${existing.price}' : '');
    final hpp = TextEditingController(
        text: existing != null ? '${existing.hpp}' : '');
    String cat =
        existing?.category ?? MockData.categories.first.key;
    bool available = existing?.isAvailable ?? true;

    showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(existing == null ? 'Menu Baru' : 'Edit Menu',
              style: AppText.display(size: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama Menu')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: cat,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final c in MockData.categories)
                  DropdownMenuItem(value: c.key, child: Text(c.label)),
              ],
              onChanged: (v) => setD(() => cat = v ?? cat),
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
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.chili, elevation: 0),
              onPressed: () {
                final p = int.tryParse(price.text) ?? 0;
                final hp = int.tryParse(hpp.text) ?? 0;
                setState(() {
                  if (existing == null) {
                    products.add(MenuItem(
                        products.length + 1,
                        name.text.trim(),
                        cat,
                        p,
                        hp,
                        isAvailable: available));
                  } else {
                    final i = products.indexOf(existing);
                    products[i] = MenuItem(existing.id, name.text.trim(),
                        cat, p, hp,
                        isAvailable: available);
                  }
                });
                Navigator.pop(d);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
