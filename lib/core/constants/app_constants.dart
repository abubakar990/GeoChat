class AppConstants {
  // ── Supabase ──────────────────────────────────────────────────────────────
  // Keys are injected via --dart-define at build time for production.
  // Fallback values are used for local development only.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // ── Google Maps ───────────────────────────────────────────────────────────
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  // ── Database Tables ───────────────────────────────────────────────────────
  static const String profilesTable = 'profiles';
  static const String messagesTable = 'messages';
  static const String conversationsTable = 'conversations';
  static const String friendRequestsTable = 'friend_requests';

  // ── Storage Buckets ───────────────────────────────────────────────────────
  static const String avatarsBucket = 'avatars';
  static const String messageMediaBucket = 'message-media';

  // ── Proximity ─────────────────────────────────────────────────────────────
  static const double defaultRadius = 5000.0; // 5 km in meters
  static const double locationUpdateThreshold = 100.0; // 100 m significant move
  static const int locationFetchIntervalSeconds = 30;

  // ── Realtime ──────────────────────────────────────────────────────────────
  static const String globalAnnouncementsChannel = 'global_announcements';

  // ── Encryption ────────────────────────────────────────────────────────────
  static const String encryptionKeyPrefix = 'e2ee_key_';

  // ── Map ───────────────────────────────────────────────────────────────────
  static const double defaultMapZoom = 14.0;
}
