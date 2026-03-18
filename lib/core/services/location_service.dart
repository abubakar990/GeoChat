import 'dart:async';
import 'package:geolocator/geolocator.dart';
// distanceFilter is hardcoded to 100 m (battery-efficient significant-change mode)

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _sub;
  final _controller = StreamController<Position>.broadcast();

  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;
  Stream<Position> get stream => _controller.stream;

  Future<LocationPermissionStatus> requestPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return LocationPermissionStatus.denied;
    }
    if (perm == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }
    return LocationPermissionStatus.granted;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      // ignore: deprecated_member_use
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lastPosition = pos;
      return pos;
    } catch (_) {
      return null;
    }
  }

  void startTracking({required void Function(Position) onUpdate}) {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium, // geolocator: medium ≈ balanced
        distanceFilter: 100, // 100 m significant-change filter
      ),
    ).listen(
      (pos) {
        _lastPosition = pos;
        _controller.add(pos);
        onUpdate(pos);
      },
      onError: (e) {
        print('[LocationService Tracking Error]: $e');
      },
    );
  }

  void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) =>
      Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void dispose() {
    stopTracking();
    _controller.close();
  }
}

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}
