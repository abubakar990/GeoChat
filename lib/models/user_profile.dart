class UserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;
  final bool isOnline;
  final double? distanceMeters;
  final bool isLocationSharing;
  final String? accountNumber;

  const UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.latitude,
    this.longitude,
    this.lastSeen,
    this.isOnline = false,
    this.distanceMeters,
    this.isLocationSharing = false,
    this.accountNumber,
  });

  String get name => displayName ?? username;
  double? get distance => distanceMeters;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final lastSeen = map['last_seen'] != null
        ? DateTime.tryParse(map['last_seen'] as String)
        : null;
    var isOnline = map['is_online'] as bool? ?? false;

    // Staleness check: if last_seen is more than 2 minutes old,
    // treat the user as offline even if is_online flag is true.
    // Handles cases where the app crashed without sending the offline update.
    if (isOnline && lastSeen != null) {
      final age = DateTime.now().toUtc().difference(lastSeen.toUtc());
      if (age.inMinutes > 2) {
        isOnline = false;
      }
    }

    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String? ?? 'User',
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      latitude:
          map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      lastSeen: lastSeen,
      isOnline: isOnline,
      distanceMeters: map['distance_meters'] != null
          ? (map['distance_meters'] as num).toDouble()
          : null,
      isLocationSharing: map['is_location_sharing'] as bool? ?? false,
      accountNumber: map['account_number'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_online': isOnline,
      };

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    double? latitude,
    double? longitude,
    bool? isOnline,
    double? distanceMeters,
  }) =>
      UserProfile(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        lastSeen: lastSeen,
        isOnline: isOnline ?? this.isOnline,
        distanceMeters: distanceMeters ?? this.distanceMeters,
      );
}
