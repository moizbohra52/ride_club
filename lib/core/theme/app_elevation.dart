import 'package:flutter/material.dart';

/// Dual-layer shadow system: a tight, low-opacity dark shadow for depth plus
/// a soft, wide tint shadow for glow. Replaces single flat BoxShadow literals
/// that were scattered across screens.
class AppElevation {
  AppElevation._();

  static List<BoxShadow> soft(Color tint) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> medium(Color tint) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.22),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> strong(Color tint) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.32),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];
}
