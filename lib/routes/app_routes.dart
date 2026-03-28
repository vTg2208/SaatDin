import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';
import '../screens/onboarding/platform_selection_screen.dart';
import '../screens/onboarding/plan_selection_screen.dart';
import '../screens/main_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const String welcome = '/welcome';
  static const String platformSelect = '/platform-select';
  static const String planSelect = '/plan-select';
  static const String home = '/home';

  static Map<String, WidgetBuilder> get routes {
    return {
      welcome: (context) => const WelcomeScreen(),
      platformSelect: (context) => const PlatformSelectionScreen(),
      planSelect: (context) => const PlanSelectionScreen(),
      home: (context) => const MainShell(),
    };
  }
}
