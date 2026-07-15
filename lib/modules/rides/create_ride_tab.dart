import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/place_result.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'create_ride_controller.dart';

class CreateRideTab extends StatelessWidget {
  const CreateRideTab({super.key});

  @override
  Widget build(BuildContext context) {
    final CreateRideController c = Get.put(CreateRideController());
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Obx(
      () => LoadingOverlay(
        isLoading: c.creating.value,
        message: 'Creating ride…',
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.add_road_rounded,
                          size: 20, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'New ride details',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: c.nameField,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ride name',
                    hintText: 'Weekend to Lonavala',
                    prefixIcon: Icon(Icons.edit_road_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                _stopField(context, c, c.origin,
                    label: 'Origin (optional)', icon: Icons.trip_origin),
                const SizedBox(height: 12),
                // Waypoints (reorderable).
                Obx(
                  () => ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: c.waypoints.length,
                    onReorder: c.reorderWaypoints,
                    itemBuilder: (BuildContext ctx, int i) {
                      final StopEditor e = c.waypoints[i];
                      return Padding(
                        key: ValueKey<StopEditor>(e),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: <Widget>[
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                            Expanded(
                              child: _stopField(context, c, e,
                                  label: 'Stop ${i + 1}',
                                  icon: Icons.place_outlined),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => c.removeWaypoint(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: c.addWaypoint,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add stop'),
                  ),
                ),
                const SizedBox(height: 12),
                _stopField(context, c, c.destination,
                    label: 'Destination (optional)', icon: Icons.flag_outlined),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Create ride',
                  icon: Icons.add_road_rounded,
                  onPressed: c.create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stopField(
    BuildContext context,
    CreateRideController c,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
}
