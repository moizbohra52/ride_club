import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/ride.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'edit_ride_controller.dart';
import 'stop_field.dart';
import 'stops_route_controller.dart';

/// Edit an existing ride's name/stops/route. Only ever pushed for the host
/// (see the "Edit ride" button in [RideDetailView]); route selection reuses
/// the same inline map as create-ride via [StopsRouteController].
class EditRideView extends StatelessWidget {
  const EditRideView({super.key});

  @override
  Widget build(BuildContext context) {
    final Ride ride = Get.arguments as Ride;
    final EditRideController c = Get.put(EditRideController(ride));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit ride')),
      body: Obx(
        () => LoadingOverlay(
          isLoading: c.saving.value,
          message: 'Saving…',
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                    label: 'Save changes',
                    icon: Icons.check_rounded,
                    onPressed: c.save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
