import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

/// Top-level function for background message handling
/// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
    print('Background message received: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
  }
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Callback for navigation - set this from your main screen
  Function(String hotspotId, LatLng location)? onNotificationTap;

  /// Initialize Firebase and notifications
  Future<void> initialize() async {
    // Skip Firebase initialization on web - push notifications not supported
    if (kIsWeb) {
      print('⚠️ Firebase push notifications not supported on web platform');
      return;
    }
    
    try {
      // Initialize Firebase (mobile only)
      await Firebase.initializeApp();
      print('✅ Firebase initialized');

      // Configure background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getFCMToken();

      // Setup message listeners
      _setupMessageListeners();

      print('✅ Firebase Service fully initialized');
    } catch (e) {
      print('❌ Error initializing Firebase: $e');
    }
  }

  /// Request notification permissions (iOS/Android 13+)
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('Notification permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('✅ User granted provisional notification permission');
    } else {
      print('❌ User declined notification permission');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    // ✅ Channel 1: Crime Alerts (for all users)
    const crimeAlertsChannel = AndroidNotificationChannel(
      'crime_alerts', // id
      'Crime Alerts', // name
      description: 'Notifications for new crime reports in your area',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 0, 0), // Red LED
    );

    // ✅ Channel 2: Admin Alerts (for admin/officers only)
    const adminAlertsChannel = AndroidNotificationChannel(
      'admin_alerts', // id
      'Admin Alerts', // name
      description: 'Notifications for pending reports requiring review',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 165, 0), // Orange LED
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(crimeAlertsChannel);
      await androidPlugin.createNotificationChannel(adminAlertsChannel);
      print('✅ Notification channels created');
    }
  }

  /// Get FCM token and save to Supabase
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      
      if (_fcmToken != null) {
        print('📱 FCM Token: $_fcmToken');
        await _saveFCMTokenToDatabase(_fcmToken!);
      } else {
        print('❌ Failed to get FCM token');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('🔄 FCM Token refreshed: $newToken');
        _saveFCMTokenToDatabase(newToken);
      });
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  /// Save FCM token to Supabase for the current user
  Future<void> _saveFCMTokenToDatabase(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, cannot save FCM token');
        return;
      }

      // Update or insert FCM token in users table
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token, 'updated_at': DateTime.now().toIso8601String()})
          .eq('email', user.email!);

      print('✅ FCM token saved to database');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Setup message listeners for foreground, background, and terminated states
  void _setupMessageListeners() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Foreground message received');
      print('Notification type: ${message.data['notification_type'] ?? 'crime_alert'}');
      _handleMessage(message, isForeground: true);
    });

    // Handle background messages (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📬 Background message opened');
      print('Notification type: ${message.data['notification_type'] ?? 'crime_alert'}');
      _handleMessage(message, isForeground: false);
      _navigateToHotspot(message.data);
    });

    // Handle terminated state (app opened from notification when closed)
    _handleTerminatedMessage();
  }

  /// Handle messages from terminated state
  Future<void> _handleTerminatedMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('📭 Terminated message received');
      print('Notification type: ${initialMessage.data['notification_type'] ?? 'crime_alert'}');
      _handleMessage(initialMessage, isForeground: false);
      // Navigate after a slight delay to ensure app is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToHotspot(initialMessage.data);
      });
    }
  }

  /// Process incoming messages
  void _handleMessage(RemoteMessage message, {required bool isForeground}) {
    final notification = message.notification;
    final data = message.data;

    print('Message data: $data');

    if (notification != null && isForeground) {
      // Encode data as JSON string for payload
      final payloadMap = {
        'hotspot_id': data['hotspot_id']?.toString() ?? '',
        'latitude': data['latitude']?.toString() ?? '',
        'longitude': data['longitude']?.toString() ?? '',
        'notification_type': data['notification_type']?.toString() ?? 'crime_alert',
        'status': data['status']?.toString() ?? 'active',
      };
      
      final payload = payloadMap.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');

      // ✅ Determine which channel to use based on notification type
      final notificationType = data['notification_type']?.toString() ?? 'crime_alert';
      final channelId = notificationType == 'pending_report' ? 'admin_alerts' : 'crime_alerts';
      final channelName = notificationType == 'pending_report' ? 'Admin Alerts' : 'Crime Alerts';

      _showLocalNotification(
        title: notification.title ?? 'New Alert',
        body: notification.body ?? '',
        payload: payload,
        channelId: channelId,
        channelName: channelName,
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'crime_alerts',
    String channelName = 'Crime Alerts',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelId == 'admin_alerts' 
          ? 'Notifications for pending reports requiring review'
          : 'Notifications for new crime reports in your area',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: channelId == 'admin_alerts' 
          ? const Color.fromARGB(255, 255, 165, 0) // Orange for admin
          : const Color.fromARGB(255, 255, 0, 0), // Red for crime alerts
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Handle notification tap - parse payload and navigate
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped with payload: ${response.payload}');
    
    if (response.payload != null) {
      // Parse payload (format: "hotspot_id=123&latitude=6.9214&longitude=122.0790&notification_type=crime_alert")
      final params = Uri.splitQueryString(response.payload!);
      print('Parsed params: $params');
      
      // Check notification type
      final notificationType = params['notification_type'] ?? 'crime_alert';
      final status = params['status'] ?? 'active';
      
      print('Opening notification - Type: $notificationType, Status: $status');
      
      _navigateToHotspot(params);
    }
  }

  /// Navigate to hotspot location
  void _navigateToHotspot(Map<String, dynamic> data) {
    final hotspotId = data['hotspot_id']?.toString();
    final latStr = data['latitude']?.toString();
    final lonStr = data['longitude']?.toString();
    final notificationType = data['notification_type']?.toString() ?? 'crime_alert';
    final status = data['status']?.toString() ?? 'active';

    print('🗺️ Navigating to hotspot: $hotspotId at ($latStr, $lonStr)');
    print('   Type: $notificationType, Status: $status');

    if (hotspotId != null && latStr != null && lonStr != null) {
      try {
        final lat = double.parse(latStr);
        final lon = double.parse(lonStr);
        final location = LatLng(lat, lon);

        // Call the navigation callback
        if (onNotificationTap != null) {
          onNotificationTap!(hotspotId, location);
        } else {
          print('⚠️ Navigation callback not set');
        }
      } catch (e) {
        print('❌ Error parsing coordinates: $e');
      }
    }
  }

  /// Clear FCM token on logout
  Future<void> clearToken() async {
    if (kIsWeb) return; // Skip on web
    
    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      print('✅ FCM token cleared');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }

  /// Subscribe to topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return; // Skip on web
    
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return; // Skip on web
    
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic: $e');
    }
  }
}