import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/ui.dart';
import '../services/model_fit.dart';

/// "Runs well" / "Tight fit" / "Too big": whether a model suits this phone.
class FitBadge extends StatelessWidget {
  final ModelFit fit;
  const FitBadge(this.fit, {super.key});

  static String label(ModelFit fit) => switch (fit) {
        ModelFit.ideal => 'Runs well'.tr,
        ModelFit.tight => 'Tight fit'.tr,
        ModelFit.tooBig => 'Too big'.tr,
        ModelFit.unknown => '',
      };

  /// One sentence on what the fit means for the user.
  static String explain(ModelFit fit) => switch (fit) {
        ModelFit.ideal => 'Runs comfortably on this phone.'.tr,
        ModelFit.tight =>
          'Loads on this phone with little memory to spare: it can be slow, or fail when other apps are open.'
              .tr,
        ModelFit.tooBig =>
          'Needs more memory than this phone has. Phone cluster can run it across several phones.'
              .tr,
        ModelFit.unknown => '',
      };

  static Color color(ModelFit fit, AppTokens t) => switch (fit) {
        ModelFit.ideal => t.green,
        ModelFit.tight => t.orange,
        ModelFit.tooBig => t.red,
        ModelFit.unknown => t.muted,
      };

  static IconData icon(ModelFit fit) => switch (fit) {
        ModelFit.ideal => Icons.check_circle_rounded,
        ModelFit.tight => Icons.error_rounded,
        ModelFit.tooBig => Icons.cancel_rounded,
        ModelFit.unknown => Icons.help_rounded,
      };

  @override
  Widget build(BuildContext context) {
    if (fit == ModelFit.unknown) return const SizedBox.shrink();
    final t = AppTokens.of(context);
    return AppTag(label(fit), color: color(fit, t), icon: icon(fit));
  }
}
