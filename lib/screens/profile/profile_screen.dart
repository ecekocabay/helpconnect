import 'package:flutter/material.dart';
import '../../routes.dart';
import 'package:helpconnect/services/auth_service.dart';
import 'package:helpconnect/services/api_client.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';

class ProfileScreen extends StatefulWidget {
  final String roleLabel;
  const ProfileScreen({super.key, this.roleLabel = 'Unknown'});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<void> _loadFuture;

  Map<String, String> _attrs = {};
  bool _notifyEnabled = true;

  bool _savingNotif = false;
  String? _errorMessage;

  final ApiClient _apiClient = ApiClient();

  ButtonStyle get _blackButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black54,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      );

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _errorMessage = null);

    final attrs = await AuthService.instance.getUserAttributes();

    bool notifyEnabled = true;
    try {
      notifyEnabled = await _apiClient.getNotificationEnabled();
    } catch (e) {
      // If this fails, we still show the profile and default to ON.
      // Keep a message to help debugging.
      _errorMessage = 'Notification setting could not be loaded: $e';
    }

    if (!mounted) return;
    setState(() {
      _attrs = attrs;
      _notifyEnabled = notifyEnabled;
    });
  }

  Future<void> _logout() async {
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  String _initialFrom(String nameOrEmail) {
    final s = nameOrEmail.trim();
    if (s.isEmpty) return '?';
    return s[0].toUpperCase();
  }

  Future<void> _toggleNotifications(bool value) async {
    if (_savingNotif) return;

    setState(() {
      _savingNotif = true;
      _errorMessage = null;
      _notifyEnabled = value; // optimistic UI
    });

    try {
      await _apiClient.setNotificationEnabled(value);
    } catch (e) {
      // rollback if failed
      if (!mounted) return;
      setState(() {
        _notifyEnabled = !value;
        _errorMessage = 'Failed to update notification setting: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() => _savingNotif = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar(
        title: 'Your Profile',
        leadingWidth: 80,
        leading: appBarTextButton(
          label: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          appBarTextButton(
            label: 'Refresh',
            onPressed: () => setState(() => _loadFuture = _loadAll()),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: FutureBuilder<void>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final email = (_attrs['email'] ?? '').trim();
                final name = (_attrs['name'] ??
                        _attrs['given_name'] ??
                        _attrs['preferred_username'] ??
                        email)
                    .trim();

                final initial = _initialFrom(name.isNotEmpty ? name : email);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12),
                    ],

                    CircleAvatar(
                      radius: 36,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      name.isEmpty ? 'Unknown User' : name,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),

                    Text(
                      email.isEmpty ? '-' : email,
                      style: TextStyle(color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'Role: ${widget.roleLabel}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),

                    const SizedBox(height: 28),

                    // ✅ Notifications toggle (labels only)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Switch(
                            value: _notifyEnabled,
                            onChanged: _savingNotif ? null : _toggleNotifications,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: _blackButtonStyle,
                        onPressed: _logout,
                        child: const Text('Logout'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}