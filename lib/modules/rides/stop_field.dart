import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/place_result.dart';
import 'route_picker_view.dart';
import 'stops_route_controller.dart';

/// A search-and-pick text field for one stop (origin/waypoint/destination),
/// shared between the create-ride and edit-ride forms.
Widget stopField(
  BuildContext context,
  StopsRouteController c,
  StopEditor e, {
  required String label,
  required IconData icon,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return Obx(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: e.field,
          onChanged: (String q) => c.onSearchChanged(e, q),
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Search a place',
            prefixIcon: Icon(icon, size: 22),
            suffixIcon: e.searching.value
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : (e.chosen.value != null
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 26)
                    : null),
          ),
        ),
        ...e.suggestions.map(
          (PlaceResult p) => Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant
                    .withValues(alpha: isDark ? 0.35 : 0.2),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              leading: Icon(Icons.location_on_outlined,
                  size: 20, color: scheme.primary),
              title: Text(
                p.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
              onTap: () => c.choose(e, p),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shows the route-planning state right on a stops form: a spinner while the
/// auto-triggered fetch is running, then the inline map+cards from
/// [RoutePickerView] once alternatives come back — tap a polyline or a card
/// to select it directly, no separate screen or confirm step.
Widget routePreview(BuildContext context, StopsRouteController c) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return Obx(() {
    if (c.routing.value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Text(
              'Finding routes…',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    if (c.routeAlternatives.isEmpty) return const SizedBox.shrink();
    return RoutePickerView(
      c: c,
      routes: c.routeAlternatives,
      stops: c.orderedStopPoints,
    );
  });
}
