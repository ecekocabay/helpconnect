import 'package:flutter/material.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // If already signed in, sign out first
      final signedIn = await AuthService.instance.isSignedIn();
      if (signedIn) {
        await AuthService.instance.signOut();
      }

      await AuthService.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      // Force token fetch once (helps avoid stale session issues)
      await AuthService.instance.getAccessToken();

      // ✅ Admin users go directly to Admin panel
      final isAdmin = await AuthService.instance.isAdmin(groupName: 'Admin');

      if (!mounted) return;

      if (isAdmin) {
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar(
        title: 'Login',
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: "Email"),
                    validator: (v) =>
                        v != null && v.contains("@") ? null : "Invalid email",
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password"),
                    validator: (v) =>
                        (v != null && v.isNotEmpty) ? null : "Required",
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _onLogin,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Login"),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.pushNamed(
                              context,
                              AppRoutes.register,
                            ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      disabledForegroundColor: Colors.black54,
                    ),
                    child: const Text("Create a new account"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}