import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final String roleLabel;

  const ProfileScreen({
    super.key,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    // For Stage 2 this is mock data – later we’ll fill from Cognito
    const String name = 'Demo User';
    const String email = 'demo.user@example.com';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Chip(
                  avatar: const Icon(Icons.badge, size: 18),
                  label: Text('Role: $roleLabel'),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Account Settings'),
                  subtitle:
                      const Text('Change password, notification preferences (later)'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account settings will be implemented later.'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  onTap: () {
                    // For now just pop, later we’ll clear auth and go to login
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}