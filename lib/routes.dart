import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/help_seeker/help_seeker_home_screen.dart';
import 'screens/volunteer/volunteer_home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/help_seeker/my_requests_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const helpSeekerHome = '/help-seeker/home';
  static const volunteerHome = '/volunteer/home';
  static const adminDashboard = '/admin';
  static const roleSelection = '/role-selection';
  static const myRequests = '/my-requests';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case helpSeekerHome:
        return MaterialPageRoute(builder: (_) => const HelpSeekerHomeScreen());
      case volunteerHome:
        return MaterialPageRoute(builder: (_) => const VolunteerHomeScreen());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());
      case myRequests:
        return MaterialPageRoute(builder: (_) => const MyRequestsScreen());
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}