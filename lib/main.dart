import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'core/services/push_notification_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/discovery/providers/discovery_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/friends/providers/friends_provider.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase (required for FCM) ──────────────────────────────────────────
  await Firebase.initializeApp();

  // ── Supabase ─────────────────────────────────────────────────────────────
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // ── Push notifications ────────────────────────────────────────────────────
  // Background handler must be registered before runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.instance.initialize();

  runApp(const GeoChatApp());
}

// StatefulWidget so AuthProvider is created exactly ONCE and never rebuilt.
class GeoChatApp extends StatefulWidget {
  const GeoChatApp({super.key});

  @override
  State<GeoChatApp> createState() => _GeoChatAppState();
}

class _GeoChatAppState extends State<GeoChatApp> with WidgetsBindingObserver {
  late final AuthProvider _authProvider;
  late final GoRouterWrapper _routerWrapper;
  final _svc = SupabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider();
    _routerWrapper = GoRouterWrapper(authProvider: _authProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground → mark online
        _svc.updateOnlineStatus(userId: userId, isOnline: true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background or closed → mark offline
        _svc.updateOnlineStatus(userId: userId, isOnline: false);
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Mark offline on dispose
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _svc.updateOnlineStatus(userId: userId, isOnline: false);
    }
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => DiscoveryProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: _routerWrapper,
    );
  }
}

class GoRouterWrapper extends StatefulWidget {
  final AuthProvider authProvider;
  const GoRouterWrapper({super.key, required this.authProvider});

  @override
  State<GoRouterWrapper> createState() => _GoRouterWrapperState();
}

class _GoRouterWrapperState extends State<GoRouterWrapper> {
  late final router = createRouter(widget.authProvider);

  @override
  void initState() {
    super.initState();
    // Handle notification taps → navigate to the right screen
    PushNotificationService.instance.onMessageTap = _handleNotificationTap;
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    final refId = message.data['referenceId'] as String?;

    if (type == 'new_message' && refId != null) {
      router.push('/chat/$refId',
          extra: {'name': message.notification?.title ?? 'User', 'userId': ''});
    } else if (type == 'friend_request' || type == 'friend_accepted') {
      // Navigate to home and switch to Friends tab
      router.go('/home');
    } else {
      router.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GeoChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
