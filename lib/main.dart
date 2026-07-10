import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/globals.dart';
import 'core/providers/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

final _localNotifications = FlutterLocalNotificationsPlugin();

// Only this account gets "a new build is ready" pings from CI — not the
// partner's, who has nothing to do with builds.
const _devEmail = 'abhishek2005.siva@gmail.com';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> _initNotifications() async {
  final prefs = await SharedPreferences.getInstance();
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

  // Android channel — always create so the channel exists even if disabled
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

  if (!notificationsEnabled) return;

  // Request permission (iOS + Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // Foreground messages are handled in-app (SnackBar/overlay in room_screen).
  // We intentionally do NOT show a system notification when the app is active.
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

    // Deep-link when the user taps a push notification: calls land on
    // /chat (the incoming-call dialog takes over), movie nights on /cinema.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _handleNotificationTap(m));
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data['type'] == 'build_ready') {
      final url = message.data['apkUrl'];
      if (url is String) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return;
    }
    final route = message.data['route'];
    if (route is String && route.startsWith('/')) {
      ref.read(routerProvider).go(route);
    }
  }

  Future<void> _saveFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await ref.read(firestoreServiceProvider).saveFCMToken(token);

    // "New build ready" pings from CI go to this one topic — only
    // subscribe the developer's own account to it, not the partner's.
    if (FirebaseAuth.instance.currentUser?.email == _devEmail) {
      FirebaseMessaging.instance.subscribeToTopic('dev_builds').ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Two Hearts',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.build(accent),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
