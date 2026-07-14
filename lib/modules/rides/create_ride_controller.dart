import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/place_result.dart';
import '../../models/ride.dart';
import '../../services/geo_service.dart';
import '../../services/ride_service.dart';
import 'rides_shell_controller.dart';

class CreateRideController extends GetxController {
  final GeoService _geo = Get.find<GeoService>();
  final RideService _rides = Get.find<RideService>();

  final TextEditingController nameField = TextEditingController();
  final TextEditingController destField = TextEditingController();
  final RxList<PlaceResult> suggestions = <PlaceResult>[].obs;
  final Rxn<PlaceResult> chosen = Rxn<PlaceResult>();
  final RxBool searching = false.obs;
  final RxBool creating = false.obs;
  Timer? _debounce;
  bool _isDisposed = false;

  void onSearchChanged(String q) {
    chosen.value = null;
    _debounce?.cancel();
    if (q.trim().length < 3) {
      suggestions.clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 550), () async {
      searching.value = true;
      suggestions.value = await _geo.searchPlaces(q);
      searching.value = false;
    });
  }

  void choose(PlaceResult p) {
    chosen.value = p;
    destField.text = p.displayName;
    suggestions.clear();
  }

  Future<void> create() async {
    if (nameField.text.trim().isEmpty) {
      UiHelpers.error('Give your ride a name.');
      return;
    }
    creating.value = true;
    try {
      final RideDestination? dest = chosen.value == null
          ? null
          : RideDestination(
              lat: chosen.value!.lat,
              lng: chosen.value!.lng,
              label: chosen.value!.displayName,
            );
      final Ride ride =
          await _rides.createRide(name: nameField.text, destination: dest);
      _showCreated(ride);
      if (!_isDisposed) {
        nameField.clear();
        destField.clear();
        chosen.value = null;
        suggestions.clear();
        Get.find<RidesShellController>().tabIndex.value = 0;
      }
    } catch (e) {
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      creating.value = false;
    }
  }

  void _showCreated(Ride ride) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 44),
            const SizedBox(height: 12),
            const Text('Ride created!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            const Text('Share this code with your crew:'),
            const SizedBox(height: 12),
            SelectableText(
              ride.code,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Share.share(
                'Join my RideTogether ride "${ride.name}" with code: ${ride.code}',
              ),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share code'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Get.back(), child: const Text('Done')),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  void onClose() {
    _isDisposed = true;
    _debounce?.cancel();
    nameField.dispose();
    destField.dispose();
    super.onClose();
  }
}
