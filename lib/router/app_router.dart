import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/home/home_shell.dart';
import '../features/chat/screens/chat_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuth = authProvider.isAuthenticated;
      final needsVerify = authProvider.needsEmailVerification;
      final loc = state.matchedLocation;

      final isAuthRoute = loc == '/login' || loc == '/signup';

      // If awaiting email verification, stay on signup (VerifyEmailScreen renders there)
      if (needsVerify) {
        return loc == '/signup' ? null : '/signup';
      }

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      // Main app shell (has bottom nav: map / chats / + / friends / profile)
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
      // Deep-link into a specific chat conversation
      GoRoute(
        path: '/chat/:conversationId',
        builder: (_, state) {
          final convId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, String>?;
          return ChatScreen(
            conversationId: convId,
            otherUserName: extra?['name'] ?? 'User',
            otherUserId: extra?['userId'] ?? '',
            otherUserAvatar: extra?['avatar'],
          );
        },
      ),
    ],
  );
}
