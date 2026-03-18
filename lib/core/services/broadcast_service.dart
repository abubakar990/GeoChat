import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SystemAlert {
  final String title;
  final String message;
  final String type; // 'info' | 'warning' | 'critical'
  final DateTime timestamp;

  const SystemAlert({
    required this.title,
    required this.message,
    this.type = 'info',
    required this.timestamp,
  });

  factory SystemAlert.fromPayload(Map<String, dynamic> payload) => SystemAlert(
    title: payload['title'] as String? ?? 'System Alert',
    message: payload['message'] as String? ?? '',
    type: payload['type'] as String? ?? 'info',
    timestamp: DateTime.now(),
  );
}

class BroadcastService {
  static final BroadcastService _instance = BroadcastService._internal();
  factory BroadcastService() => _instance;
  BroadcastService._internal();

  RealtimeChannel? _channel;

  void listen({required void Function(SystemAlert) onAlert}) {
    final client = Supabase.instance.client;
    _channel = client
        .channel(AppConstants.globalAnnouncementsChannel)
        .onBroadcast(
          event: 'alert',
          callback: (payload) => onAlert(SystemAlert.fromPayload(payload)),
        )
        .subscribe();
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
  }
}
