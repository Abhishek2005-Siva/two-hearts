import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class FcmService {
  static const _projectId = 'two-hearts-fee27';
  static const _fcmUrl =
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
  static const _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging'
  ];

  /// Sends a hybrid notification+data push to [recipientToken].
  /// Silent no-op if token is null or empty.
  static Future<void> send({
    required String? recipientToken,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    if (recipientToken == null || recipientToken.isEmpty) return;
    try {
      final credentials = await _loadCredentials();
      final client = http.Client();
      try {
        final authClient = await clientViaServiceAccount(
          credentials,
          _scopes,
          baseClient: client,
        );
        final response = await authClient.post(
          Uri.parse(_fcmUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': {
              'token': recipientToken,
              'notification': {'title': title, 'body': body},
              'data': data,
              'android': {'priority': 'high'},
              'apns': {
                'payload': {
                  'aps': {'sound': 'default', 'badge': 1}
                }
              },
            }
          }),
        );
        if (response.statusCode != 200) {
          // ignore silently in production — partner may have uninstalled app
          assert(() {
            // ignore: avoid_print
            print('FCM error ${response.statusCode}: ${response.body}');
            return true;
          }());
        }
        authClient.close();
      } finally {
        client.close();
      }
    } catch (_) {
      // Never crash the sender's app because of a notification failure
    }
  }

  static Future<ServiceAccountCredentials> _loadCredentials() async {
    final json = await rootBundle
        .loadString('assets/config/service_account.json');
    return ServiceAccountCredentials.fromJson(jsonDecode(json));
  }
}
