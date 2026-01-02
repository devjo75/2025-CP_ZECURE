import 'package:flutter/material.dart';
import 'package:zecure/auth/register_screen.dart';
import 'package:zecure/auth/desktop_register_screen.dart';

class ResponsiveRegisterScreen extends StatelessWidget {
  const ResponsiveRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return const DesktopRegisterScreen();
            } else {
              return const RegisterScreen();
            }
          },
        );
      },
    );
  }
}
