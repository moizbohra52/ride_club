import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'create_ride_controller.dart';
import 'stop_field.dart';

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
                stopField(context, c, c.origin,
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
                              child: stopField(context, c, e,
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
                stopField(context, c, c.destination,
                    label: 'Destination (optional)', icon: Icons.flag_outlined),
                const SizedBox(height: 16),
                routePreview(context, c),
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
}
