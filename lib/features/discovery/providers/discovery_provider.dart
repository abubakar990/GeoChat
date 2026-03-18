import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../../models/user_profile.dart';
import '../../../core/constants/app_constants.dart';

class DiscoveryProvider extends ChangeNotifier {
  final _svc = SupabaseService();
  final _loc = LocationService();

  static const _kLocationSharing = 'location_sharing_enabled';
  static const _kRadius = 'discovery_radius';

  List<UserProfile> _nearbyUsers = [];
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  double _radius = AppConstants.defaultRadius;
  Timer? _timer;

  // ── Location sharing state ──────────────────────────────────────────────
  bool _isLocationSharing = false;
  bool _initialized = false;
  String _userId = '';

  List<UserProfile> get nearbyUsers => _nearbyUsers;
  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get radius => _radius;
  bool get isLocationSharing => _isLocationSharing;
  bool get initialized => _initialized;

  /// Called from the screen with the logged-in userId.
  void init(String userId) => initialize(userId);

  void initialize(String userId) {
    _userId = userId;

    // 1) Load cached state INSTANTLY from SharedPreferences (sync-like)
    SharedPreferences.getInstance().then((prefs) {
      final cachedSharing = prefs.getBool(_kLocationSharing);
      final cachedRadius = prefs.getDouble(_kRadius);

      if (cachedSharing != null) {
        _isLocationSharing = cachedSharing;
      }
      if (cachedRadius != null) {
        _radius = cachedRadius;
      }

      _initialized = true;
      notifyListeners();

      // If cached says sharing is on, start tracking immediately
      if (_isLocationSharing) _startTracking(userId);

      // 2) Then sync with the server (authoritative source)
      _svc.getProfile(userId).then((p) {
        if (p != null) {
          final serverValue = p.isLocationSharing;
          if (serverValue != _isLocationSharing) {
            _isLocationSharing = serverValue;
            // Update cache to match server
            prefs.setBool(_kLocationSharing, serverValue);
            notifyListeners();

            if (serverValue) {
              _startTracking(userId);
            } else {
              _loc.stopTracking();
              _nearbyUsers = [];
              _currentPosition = null;
              notifyListeners();
            }
          }
        }
      });
    });

    // Periodic refresh of nearby list (only if sharing is on).
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.locationFetchIntervalSeconds),
      (_) {
        if (_isLocationSharing) _fetch(userId);
      },
    );
  }

  void _startTracking(String userId) {
    _loc.startTracking(
      onUpdate: (pos) async {
        _currentPosition = pos;
        notifyListeners();
        if (_isLocationSharing) {
          await _svc.updateLocation(
            userId: userId,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
          await _fetch(userId);
        }
      },
    );

    _loc.getCurrentPosition().then((pos) {
      if (pos != null) {
        _currentPosition = pos;
        notifyListeners();
        _fetch(userId);
      }
    });
  }

  // ── Toggle location sharing ─────────────────────────────────────────────

  Future<void> toggleLocationSharing() async {
    final newValue = !_isLocationSharing;
    _isLocationSharing = newValue;
    notifyListeners();

    // Persist locally immediately so next app start shows correct state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationSharing, newValue);

    await _svc.updateLocationSharing(userId: _userId, enabled: newValue);

    if (newValue) {
      // User just turned sharing ON — start tracking and populate map.
      _startTracking(_userId);
    } else {
      // User turned sharing OFF — stop tracking and clear nearby list.
      _loc.stopTracking();
      _nearbyUsers = [];
      _currentPosition = null;
      notifyListeners();
    }
  }

  Future<void> _fetch(String userId) async {
    if (_currentPosition == null || !_isLocationSharing) return;
    _isLoading = true;
    notifyListeners();
    try {
      _nearbyUsers = await _svc.getNearbyUsers(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        currentUserId: userId,
        radius: _radius,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String userId) => _fetch(userId);

  void setRadius(double r, String userId) {
    _radius = r;
    notifyListeners();
    _fetch(userId);

    // Persist radius locally
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_kRadius, r);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
