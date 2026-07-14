import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import '../models/ride_position.dart';

enum LocationPermissionResult { granted, serviceDisabled, denied, deniedForever }

/// GPS + battery + compass wrapper.
///
/// Emits [RidePosition]s on a battery-adaptive interval (2.5s normal, 9s when
/// battery < 20%). Uses a periodic poll rather than geolocator's fixed-filter
/// stream so the interval can change at runtime. The Android foreground-service
/// settings (persistent notification) are exposed for the always-on stream
/// used in Phase 7.
class LocationService extends GetxService {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  double _heading = 0;
  StreamSubscription<CompassEvent>? _compassSub;

  bool get isLowBattery => _batteryLevel < 20;
  int get batteryLevel => _batteryLevel;

  @override
  void onInit() {
    super.onInit();
    _refreshBattery();
    _compassSub = FlutterCompass.events?.listen((CompassEvent e) {
      if (e.heading != null) _heading = e.heading!;
    });
  }

  @override
  void onClose() {
    _compassSub?.cancel();
    super.onClose();
  }

  Future<void> _refreshBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
    } catch (_) {
      // Some emulators/devices don't report battery; keep last value.
    }
  }

  Future<LocationPermissionResult> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionResult.serviceDisabled;
    }
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      return LocationPermissionResult.deniedForever;
    }
    if (p == LocationPermission.denied) {
      return LocationPermissionResult.denied;
    }
    return LocationPermissionResult.granted;
  }

  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e, s) {
      Log.e('currentPosition failed', error: e, stack: s);
      return null;
    }
  }

  /// Battery-adaptive position stream. Re-reads battery each tick and delays
  /// 2.5s (normal) or 9s (low battery) between fixes.
  Stream<RidePosition> positionStream() async* {
    while (true) {
      await _refreshBattery();
      final Duration interval = isLowBattery
          ? const Duration(seconds: 9)
          : const Duration(milliseconds: 2500);
      try {
        final Position pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        yield RidePosition(
          lat: pos.latitude,
          lng: pos.longitude,
          speed: pos.speed < 0 ? 0 : pos.speed,
          heading: _heading != 0 ? _heading : pos.heading,
          battery: _batteryLevel,
        );
      } catch (e, s) {
        Log.e('position tick failed', error: e, stack: s);
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Android foreground-location settings with a persistent notification, so
  /// tracking survives backgrounding. Kept for the always-on stream in Phase 7.
  AndroidSettings androidForegroundSettings() => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'RideTogether',
          notificationText: 'Sharing your live location with your ride',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
}
