import 'package:flutter/material.dart';

/// Shared corner-radius scale for RideTogether.
///
/// sm = chips/small badges, md = inputs/buttons/list tiles, lg = cards,
/// xl = sheets/dialogs/hero blocks.
class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;

  static const BorderRadius smRadius =
      BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius =
      BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius =
      BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius =
      BorderRadius.all(Radius.circular(xl));
}
