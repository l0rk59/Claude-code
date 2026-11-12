import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';

/// Tonal sheet button — equal visual weight for each choice; colour carries
/// the meaning (neutral vs. destructive).
class TonalButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color fill;
  final VoidCallback onTap;

  const TonalButton({
    super.key,
    required this.label,
    required this.color,
    required this.fill,
    required this.onTap,
  });

  /// Neutral grey button matching the app's card surfaces.
  factory TonalButton.neutral(BuildContext context,
      {required String label, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TonalButton(
      label: label,
      onTap: onTap,
      color: isDark ? AppColors.textDark : AppColors.textLight,
      fill: isDark
          ? AppColors.textDark.withValues(alpha: 0.08)
          : AppColors.surfacePressedLight,
    );
  }

  /// Soft red button for destructive actions.
  factory TonalButton.destructive(BuildContext context,
      {required String label, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TonalButton(
      label: label,
      onTap: onTap,
      color: isDark ? AppColors.errorDark : AppColors.errorLight,
      fill: (isDark ? AppColors.errorDark : AppColors.error)
          .withValues(alpha: isDark ? 0.16 : 0.10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Center(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ),
        ),
      ),
    );
  }
}
