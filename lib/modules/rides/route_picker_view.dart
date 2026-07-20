import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/route_result.dart';
import 'stops_route_controller.dart';

/// Inline route preview embedded right in the create/edit-ride form: every
/// OSRM alternative for the current stops as a polyline (selected = blue,
/// others = gray), tappable on the map or via the card below it — no
/// separate screen, no confirm step; tapping just updates [c.selectedRouteIndex].
class RoutePickerView extends StatefulWidget {
  final StopsRouteController c;
  final List<RouteResult> routes;
  final List<LatLng> stops;
  const RoutePickerView({
    super.key,
    required this.c,
    required this.routes,
    required this.stops,
  });

  @override
  State<RoutePickerView> createState() => _RoutePickerViewState();
}

class _RoutePickerViewState extends State<RoutePickerView> {
  final MapController _map = MapController();
  final LayerHitNotifier<int> _hitNotifier = ValueNotifier<LayerHitResult<int>?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    _hitNotifier.addListener(_onPolylineHit);
  }

  @override
  void dispose() {
    _hitNotifier.removeListener(_onPolylineHit);
    _hitNotifier.dispose();
    super.dispose();
  }

  void _onPolylineHit() {
    final List<int>? hits = _hitNotifier.value?.hitValues;
    if (hits == null || hits.isEmpty) return;
    widget.c.selectRoute(hits.first);
  }

  @override
  void didUpdateWidget(RoutePickerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routes != widget.routes) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  void _fitBounds() {
    if (!mounted) return;
    final List<LatLng> all =
        widget.routes.expand((RouteResult r) => r.points).toList();
    if (all.isEmpty) return;
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: all,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: Obx(() {
              final int selected = widget.c.selectedRouteIndex.value;
              return FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: widget.stops.first,
                  initialZoom: 12,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: Theme.of(context).brightness == Brightness.dark
                        ? AppConstants.osmTileUrlDark
                        : AppConstants.osmTileUrl,
                    userAgentPackageName: AppConstants.userAgentPackageName,
                  ),
                  PolylineLayer<int>(
                    hitNotifier: _hitNotifier,
                    polylines: <Polyline<int>>[
                      // Unselected routes drawn first (underneath), gray;
                      // each still carries its own hitValue so tapping any
                      // of them on the map selects it.
                      for (int i = 0; i < widget.routes.length; i++)
                        if (i != selected)
                          Polyline<int>(
                            points: widget.routes[i].points,
                            strokeWidth: 5,
                            color: Colors.grey.withValues(alpha: 0.6),
                            hitValue: i,
                          ),
                      Polyline<int>(
                        points: widget.routes[selected].points,
                        strokeWidth: 6,
                        color: Colors.blue,
                        hitValue: selected,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: widget.stops.first,
                        width: 26,
                        height: 26,
                        child: const Icon(Icons.trip_origin,
                            color: AppColors.success, size: 22),
                      ),
                      Marker(
                        point: widget.stops.last,
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.flag_rounded,
                            color: AppColors.sos, size: 26),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
        if (widget.routes.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          Obx(
            () => Column(
              children: <Widget>[
                for (int i = 0; i < widget.routes.length; i++)
                  _routeCard(context, i, scheme, widget.c.selectedRouteIndex.value),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _routeCard(
    BuildContext context,
    int i,
    ColorScheme scheme,
    int selectedIndex,
  ) {
    final RouteResult r = widget.routes[i];
    final bool selected = i == selectedIndex;
    final Color color = selected ? Colors.blue : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.c.selectRoute(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.blue.withValues(alpha: 0.12)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.blue : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Route ${i + 1}${i == 0 ? ' (fastest)' : ''}',
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                '${r.distanceText} · ${r.etaText}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
