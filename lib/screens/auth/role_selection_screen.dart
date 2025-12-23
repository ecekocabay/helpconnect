import 'package:flutter/material.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';

import 'package:helpconnect/widgets/app_bar_buttons.dart';
import '../../services/role_manager.dart'; // ✅ NEW
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _loading = true;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdminFlag();
  }

  Future<void> _loadAdminFlag() async {
    try {
      final isAdmin = await AuthService.instance.isAdmin();
      if (!mounted) return;

      setState(() {
        _isAdmin = isAdmin;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _goToHelpSeeker() async {
  await RoleManager.setRole('help_seeker');
  if (!mounted) return;
  Navigator.pushReplacementNamed(context, AppRoutes.helpSeekerHome);
}

Future<void> _goToVolunteer() async {
  await RoleManager.setRole('volunteer');
  if (!mounted) return;
  Navigator.pushReplacementNamed(context, AppRoutes.volunteerHome);
}

  void _goToAdmin() =>
      Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);

  Future<void> _logout() async {
  await AuthService.instance.signOut();
  await RoleManager.clearRole(); // ✅ NEW
  if (!mounted) return;
  Navigator.pushReplacementNamed(context, AppRoutes.login);
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: standardAppBar(
        title: 'Select Your Role',
        actions: [
          appBarTextButton(label: 'Logout', onPressed: _logout),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Text(
                        'Failed to load role info: $_error',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('I am a...', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _goToHelpSeeker,
                              child: const Text('Help Seeker'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _goToVolunteer,
                              child: const Text('Volunteer'),
                            ),
                          ),
                          if (_isAdmin) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _goToAdmin,
                                child: const Text('Admin'),
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}