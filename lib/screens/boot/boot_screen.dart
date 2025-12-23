import 'package:flutter/material.dart';
import 'package:helpconnect/route_names.dart';
import 'package:helpconnect/services/auth_service.dart';
import 'package:helpconnect/services/role_manager.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    // Defer navigation and configuration until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    try {
      final signedIn = await AuthService.instance.isSignedIn();

      if (!mounted) return;

      if (!signedIn) {
        Navigator.pushReplacementNamed(context, RouteNames.login);
        return;
      }

      final role = await RoleManager.getRole();

      if (!mounted) return;

      if (role == 'help_seeker') {
        Navigator.pushReplacementNamed(context, RouteNames.helpSeekerHome);
      } else if (role == 'volunteer') {
        Navigator.pushReplacementNamed(context, RouteNames.volunteerHome);
      } else {
        // signed in but no role saved yet
        Navigator.pushReplacementNamed(context, RouteNames.roleSelection);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}