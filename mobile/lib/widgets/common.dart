import 'package:flutter/material.dart';
import '../theme.dart';

/// Widget bersama ala kartu ERP web: kartu putih rounded-2xl + border halus.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const SectionCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Kartu ringkasan statistik (seperti summary cards Dashboard/Stock/Menu web).
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final String? badge;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.cream, borderRadius: BorderRadius.circular(999)),
                  child: Text(badge!,
                      style: AppText.body(
                          size: 10, weight: FontWeight.w700, color: Colors.black45)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: AppText.display(size: 22)),
          const SizedBox(height: 4),
          Text(label, style: AppText.body(size: 11, color: Colors.black45)),
        ],
      ),
    );
  }
}

/// Chip status (Lunas / Pending / Kritis / Aman / Hadir / ...).
class StatusChip extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;

  const StatusChip(this.label, {super.key, required this.fg, required this.bg});

  StatusChip.ok(String l)
      : this(l, fg: AppColors.greenOk, bg: AppColors.greenBg);
  StatusChip.warn(String l) : this(l, fg: AppColors.ember, bg: AppColors.ember.withValues(alpha: 0.12));
  StatusChip.danger(String l) : this(l, fg: AppColors.chili, bg: AppColors.redBg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: AppText.body(size: 11, weight: FontWeight.w700, color: fg)),
    );
  }
}

/// Tombol pill utama (bg chili) & sekunder (bg char) seperti di web.
Widget primaryButton(String label, {VoidCallback? onPressed, Color? color, Widget? icon}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon ?? const SizedBox.shrink(),
      label: Text(label,
          style: AppText.body(
              size: 14, weight: FontWeight.w700, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.chili,
        disabledBackgroundColor: (color ?? AppColors.chili).withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 0,
      ),
    ),
  );
}
