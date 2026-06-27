import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

final _localNotifications = FlutterLocalNotificationsPlugin();

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> _initNotifications() async {
  // Android channel
  const channel = AndroidNotificationChannel(
    'two_hearts_channel',
    'Two Hearts',
    description: 'Letters, messages and moments from your partner',
    importance: Importance.high,
  );

  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  // Request permission (iOS + Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // Show foreground notifications via local_notifications
  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp();
  // Disable disk cache so switching accounts never causes stale-permission errors.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  await _initNotifications();
  runApp(const ProviderScope(child: TwoHeartsApp()));
}

class TwoHeartsApp extends ConsumerStatefulWidget {
  const TwoHeartsApp({super.key});

  @override
  ConsumerState<TwoHeartsApp> createState() => _TwoHeartsAppState();
}

class _TwoHeartsAppState extends ConsumerState<TwoHeartsApp> {
  @override
  void initState() {
    super.initState();
    _saveFcmToken();
    // Refresh token if it rotates
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _saveFcmToken());
  }

  Future<void> _saveFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await ref.read(firestoreServiceProvider).saveFCMToken(token);
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Two Hearts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(accent),
      routerConfig: router,
    );
  }
}
