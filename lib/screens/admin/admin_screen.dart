import 'dart:convert';
import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';

import 'package:helpconnect/screens/auth/role_selection_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiClient _api = ApiClient();

  bool _busy = false;
  String? _error;
  String? _resultText;

  // Modify form - updated to match Lambda API
  String _selectedTable = 'HelpRequests';
  final _requestIdCtrl = TextEditingController();
  final _offerIdCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  String _selectedField = 'status';
  final _valueCtrl = TextEditingController();

  bool _isAdmin = false;
  bool _loadingRole = true;

  // Tables and their allowed fields
  static const Map<String, List<String>> _tableFields = {
    'HelpRequests': ['status', 'title', 'description', 'urgency', 'category', 'location'],
    'HelpOffers': ['status', 'note', 'estimated_arrival_minutes'],
    'NotificationSettings': ['notify_enabled', 'email'],
  };

  @override
  void initState() {
    super.initState();
    _loadAdminClaim();
  }

  @override
  void dispose() {
    _requestIdCtrl.dispose();
    _offerIdCtrl.dispose();
    _userIdCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminClaim() async {
    try {
      final isAdmin = await AuthService.instance.isAdmin();

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _loadingRole = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _loadingRole = false;
      });
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _resultText = null;
    });

    try {
      final res = await fn();
      if (!mounted) return;
      setState(() => _resultText = const JsonEncoder.withIndent('  ').convert(res));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ButtonStyle get _blackBtn => ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black54,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  void _goToRoleSelection() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  void _onTableChanged(String? table) {
    if (table == null) return;
    setState(() {
      _selectedTable = table;
      // Reset field to first available for this table
      _selectedField = _tableFields[table]!.first;
    });
  }

  Map<String, dynamic> _buildModifyBody() {
    // Build key based on selected table
    Map<String, dynamic> key;
    if (_selectedTable == 'HelpRequests') {
      key = {'request_id': _requestIdCtrl.text.trim()};
    } else if (_selectedTable == 'HelpOffers') {
      key = {
        'request_id': _requestIdCtrl.text.trim(),
        'offer_id': _offerIdCtrl.text.trim(),
      };
    } else {
      key = {'user_id': _userIdCtrl.text.trim()};
    }

    // Parse value (handle booleans and numbers)
    dynamic value = _valueCtrl.text.trim();
    if (_selectedField == 'notify_enabled') {
      value = value.toLowerCase() == 'true';
    } else if (_selectedField == 'estimated_arrival_minutes') {
      value = int.tryParse(value) ?? 0;
    }

    return {
      'table': _selectedTable,
      'key': key,
      'updates': {_selectedField: value},
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentFields = _tableFields[_selectedTable] ?? [];

    return Scaffold(
      appBar: standardAppBar(
        title: 'Admin Panel',
        leadingWidth: 80,
        leading: appBarTextButton(
          label: 'Back',
          onPressed: _goToRoleSelection,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _loadingRole
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isAdmin)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Text(
                        'You are NOT an admin (Cognito group: Admin).\nIf you try actions you will get 403.',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),

                  const SizedBox(height: 12),

                  _adminButton(
                    label: 'Initialize DB',
                    onPressed: () => _run(() => _api.adminInitialize()),
                  ),
                  const SizedBox(height: 10),
                  _adminButton(
                    label: 'Reset DB',
                    onPressed: () => _run(() => _api.adminReset()),
                  ),
                  const SizedBox(height: 10),
                  _adminButton(
                    label: 'Backup DB',
                    onPressed: () => _run(() => _api.adminBackup()),
                  ),
                  const SizedBox(height: 10),
                  _adminButton(
                    label: 'View DB Summary',
                    onPressed: () => _run(() => _api.adminView()),
                  ),

                  const SizedBox(height: 22),
                  const Text(
                    'Modify Record',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  // Table dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedTable,
                    decoration: const InputDecoration(labelText: 'Table'),
                    items: _tableFields.keys
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: _onTableChanged,
                  ),
                  const SizedBox(height: 10),

                  // Key fields based on table
                  if (_selectedTable == 'HelpRequests') ...[
                    TextField(
                      controller: _requestIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'request_id',
                        hintText: 'UUID of the request',
                      ),
                    ),
                  ] else if (_selectedTable == 'HelpOffers') ...[
                    TextField(
                      controller: _requestIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'request_id',
                        hintText: 'UUID of the request',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _offerIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'offer_id',
                        hintText: 'UUID of the offer',
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _userIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'user_id',
                        hintText: 'Cognito sub of user',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Field to update dropdown
                  DropdownButtonFormField<String>(
                    value: currentFields.contains(_selectedField)
                        ? _selectedField
                        : currentFields.first,
                    decoration: const InputDecoration(labelText: 'Field to Update'),
                    items: currentFields
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedField = v ?? currentFields.first),
                  ),
                  const SizedBox(height: 10),

                  // New value
                  TextField(
                    controller: _valueCtrl,
                    decoration: InputDecoration(
                      labelText: 'New Value',
                      hintText: _selectedField == 'notify_enabled'
                          ? 'true or false'
                          : _selectedField == 'status'
                              ? 'OPEN, IN_PROGRESS, or CLOSED'
                              : 'Enter new value',
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: _blackBtn,
                      onPressed: _busy
                          ? null
                          : () {
                              final body = _buildModifyBody();
                              _run(() => _api.adminModify(body));
                            },
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Run Modify'),
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_resultText != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(_resultText!),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _adminButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: _blackBtn,
        onPressed: _busy ? null : onPressed,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}