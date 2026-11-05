import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'firebase_options.dart';
import 'theme.dart';

/// Shows in-app banners for pushes that arrive while Voltra is open (Android only shows
/// notifications in the tray while the app is in the background).
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Push notifications through Firebase Cloud Messaging. Every call is a no-op when Firebase isn't
/// configured (see firebase_options.dart) or can't start, so the app always works without it.
class Push {
  /// Completes with true once Firebase is up. Started by [init]; nothing on screen ever waits for it.
  static Future<bool> _ready = Future.value(false);
  static final Set<int> _users = {}; // every user who signed in on this phone this run

  /// Starts push setup in the background. It never blocks the first frame: Firebase or the
  /// notification-permission prompt can take seconds, and a blank screen on stage is worse than no push.
  static void init() => _ready = _setUp();

  static Future<bool> _setUp() async {
    final options = voltraFirebaseOptions;
    if (options == null || kIsWeb) return false;
    try {
      await Firebase.initializeApp(options: options);
      // The Android 13+ "Allow notifications" prompt. Not awaited: tokens work before it's answered.
      unawaited(_askPermission());
      FirebaseMessaging.onMessage.listen(_showBanner);
      // getToken/onTokenRefresh are deprecated in favour of register()/onRegistered, which hand out a
      // Firebase Installation ID. The server sends through the FCM v1 API, which targets the classic
      // registration token these still return, so they stay until the server moves over.
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        for (final id in _users) {
          unawaited(_register(id, token));
        }
      });
      return true;
    } catch (e) {
      debugPrint('Push notifications off: $e');
      return false;
    }
  }

  static Future<void> _askPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('Notification permission not requested: $e');
    }
  }

  /// Called on login: the server sends this user's notifications to this phone from now on.
  static Future<void> signedIn(int userId) async {
    if (!await _ready) return;
    _users.add(userId);
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(userId, token);
    } catch (e) {
      debugPrint('Push token unavailable: $e');
    }
  }

  static Future<void> _register(int userId, String token) async {
    try {
      await api.registerDeviceToken(userId, token);
    } on ApiException catch (e) {
      debugPrint('Push token not registered: ${e.message}');
    }
  }

  static void _showBanner(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        backgroundColor: VoltraColors.navy,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications_active, color: VoltraColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    n.title ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (n.body != null) Text(n.body!, style: const TextStyle(color: Color(0xFFB8C4D0))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
