import 'package:flutter/material.dart';
import '../../routes.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _goToHelpSeeker(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.helpSeekerHome);
  }

  void _goToVolunteer(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.volunteerHome);
  }

  void _goToAdmin(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Role')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'I am a...',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _goToHelpSeeker(context),
                    icon: const Icon(Icons.person),
                    label: const Text('Help Seeker'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _goToVolunteer(context),
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text('Volunteer'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _goToAdmin(context),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}