import 'package:flutter/material.dart';
import 'create_channel_screen.dart';
import 'create_channel_desktop_dialog.dart';

/// Helper to show create channel UI based on screen size
/// Automatically shows dialog on desktop, full screen on mobile
Future<bool?> showCreateChannelUI(
  BuildContext context,
  Map<String, dynamic> userProfile,
) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isDesktop = screenWidth >= 800;

  if (isDesktop) {
    // Desktop: Show dialog
    return showCreateChannelDesktopDialog(context, userProfile);
  } else {
    // Mobile: Navigate to full screen
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateChannelScreen(
          userProfile: userProfile,
        ),
      ),
    );
  }
}