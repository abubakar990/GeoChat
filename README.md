# GeoMessage 🗺️💬

**Real-Time Proximity-Based Messaging App**

Built with Flutter · Supabase · PostGIS · Google Maps

---

## 🚀 Quick Setup

### 1. Supabase Project

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **Database → Extensions** and enable **PostGIS**
3. Open **SQL Editor** and paste the entire contents of [`supabase/schema.sql`](supabase/schema.sql) — then run it
4. In **Storage**, create two buckets:
   - `avatars` (public)
   - `message-media` (private)
5. Enable **Realtime** for the `messages` table:
   `Database → Replication → Tables → messages ✓`

### 2. Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Enable **Maps SDK for Android** and **Maps SDK for iOS**
3. Create an API key

### 3. Configure the App

Open `lib/core/constants/app_constants.dart` and replace the placeholder values:

```dart
static const String supabaseUrl    = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_KEY';
```

Also update `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_GOOGLE_MAPS_KEY" />
```

### 4. Run

```bash
flutter pub get
flutter run
```

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/        # Colors, theme, app-wide constants
│   └── services/         # Supabase, location, encryption, broadcast
├── features/
│   ├── auth/             # Login, Signup screens + AuthProvider
│   ├── discovery/        # Map screen + DiscoveryProvider
│   ├── chat/             # Chat screen, bubbles, input + ChatProvider
│   └── alerts/           # System Alert overlay widget
├── models/               # UserProfile, Message, Conversation
├── router/               # GoRouter config with auth guard
└── main.dart             # Entry point, MultiProvider, MaterialApp
supabase/
└── schema.sql            # PostGIS tables, RPC, RLS, realtime
```

---

## 🏗️ Architecture

| Layer | Technology |
|-------|-----------|
| State Management | `provider` (ChangeNotifier) |
| Navigation | `go_router` with auth redirect guard |
| Backend | Supabase (Auth, PostgreSQL, Realtime, Storage) |
| Spatial Queries | PostGIS `ST_DWithin` RPC → `get_nearby_users` |
| Realtime Chat | Supabase Realtime (Postgres Changes) |
| System Alerts | Supabase Realtime (Broadcast) |
| Encryption | AES-256-GCM via `cryptography` package |
| Key Storage | OS Keychain via `flutter_secure_storage` |
| Location | `geolocator` — 100 m significant-change filter |
| Maps | `google_maps_flutter` with custom dark style |

---

## 🔐 Security

- **E2EE**: Every conversation has a unique AES-256-GCM key generated on first message
- **Key Storage**: Keys are stored in the OS keychain, never in plaintext
- **RLS**: Supabase Row Level Security ensures users can only read their own conversations and messages
- **Background Location**: Only updates Supabase when the user moves >100 m (battery-friendly)

---

## 🗄️ Database Schema (PostGIS)

```sql
profiles (id, username, latitude, longitude, last_known_location GEOGRAPHY(POINT))
conversations (id, participant_ids UUID[])
messages (id, conversation_id, sender_id, type, content, is_encrypted)

-- Spatial RPC
get_nearby_users(lat, long, radius, current_user_id)
  → uses ST_DWithin for radius search
  → returns distance_meters for sorting
```

---

## ⚠️ Important Notes

- Replace all `YOUR_*` placeholders before running
- For iOS, add location usage descriptions to `ios/Runner/Info.plist` (see below)
- The `global_announcements` Supabase Broadcast channel is used for system alerts — you can trigger them from the Supabase Dashboard

### iOS Info.plist (add to ios/Runner/Info.plist)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>GeoMessage uses your location to find nearby users to chat with.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>GeoMessage uses your location in the background to keep your position updated so nearby users can find you.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>GeoMessage needs background location to update your position.</string>
```
