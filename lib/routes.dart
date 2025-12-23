import 'package:flutter/material.dart';

// AUTH
import 'package:helpconnect/screens/auth/login_screen.dart';
import 'package:helpconnect/screens/auth/register_screen.dart';
import 'package:helpconnect/screens/auth/confirm_code_screen.dart';
import 'package:helpconnect/screens/auth/role_selection_screen.dart';

// BOOT
import 'package:helpconnect/screens/boot/boot_screen.dart';

// HELP SEEKER
import 'package:helpconnect/screens/help_seeker/help_seeker_home_screen.dart';
import 'package:helpconnect/screens/help_seeker/my_requests_screen.dart';
import 'package:helpconnect/screens/help_seeker/create_request_screen.dart';

// VOLUNTEER
import 'package:helpconnect/screens/volunteer/volunteer_home_screen.dart';

// ADMIN
import 'package:helpconnect/screens/admin/admin_screen.dart';

class AppRoutes {
  static const boot = '/';

  static const login = '/login';
  static const register = '/register';
  static const confirmCode = '/confirm-code';
  static const roleSelection = '/role-selection';

  static const helpSeekerHome = '/help-seeker/home';
  static const createRequest = '/help-seeker/create-request';
  static const myRequests = '/help-seeker/my-requests';

  static const volunteerHome = '/volunteer/home';
  static const adminDashboard = '/admin';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    debugPrint('onGenerateRoute called with: ${settings.name}');

    switch (settings.name) {
      case boot:
        return MaterialPageRoute(builder: (_) => const BootScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case confirmCode:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => ConfirmCodeScreen(email: email));

      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());

      case helpSeekerHome:
        return MaterialPageRoute(builder: (_) => const HelpSeekerHomeScreen());

      case createRequest:
        return MaterialPageRoute(builder: (_) => const CreateRequestScreen());

      case myRequests:
        return MaterialPageRoute(builder: (_) => const MyRequestsScreen());

      case volunteerHome:
        return MaterialPageRoute(builder: (_) => const VolunteerHomeScreen());

      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Unknown route')),
            body: Center(child: Text('Unknown route: ${settings.name}')),
          ),
        );
    }
  }
}