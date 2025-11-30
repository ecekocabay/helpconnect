import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final String roleLabel;

  const ProfileScreen({
    super.key,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Stage 2 mock data – later we’ll pull from Cognito
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
                // Replaced avatar+icon with a plain circle + initial letter
                const CircleAvatar(
                  radius: 36,
                  child: Text(
                    'D', // from "Demo User"
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),

                // Email
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),

                // Role chip (no icon)
                Chip(
                  label: Text('Role: $roleLabel'),
                ),
                const SizedBox(height: 24),

                const Divider(),
                const SizedBox(height: 16),

                // Account settings list tile without icons
                ListTile(
                  title: const Text('Account Settings'),
                  subtitle: const Text(
                    'Change password, notification preferences (later)',
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Account settings will be implemented later.'),
                      ),
                    );
                  },
                ),

                // Logout (text only)
                ListTile(
                  title: const Text('Log Out'),
                  onTap: () {
                    // Later: clear authentication state
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