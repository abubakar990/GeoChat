# ── Flutter & Dart ───────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# ── Firebase ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Google Maps ──────────────────────────────────────────────────────────────
-keep class com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.maps.**

# ── Supabase / OkHttp / Retrofit ─────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# ── Gson (if used) ───────────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*

# ── General ──────────────────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
