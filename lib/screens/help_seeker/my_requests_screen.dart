import 'package:flutter/material.dart';

import '../../models/emergency.dart';
import '../../services/api_client.dart';
import '../../widgets/emergency_card.dart';
import 'request_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final ApiClient _apiClient = ApiClient();

  // For now use the same dummy ID as in CreateRequestScreen
  final String _dummyHelpSeekerId = 'demo-user-1';

  List<Emergency> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMyRequests();
  }

  Future<void> _loadMyRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _apiClient.fetchMyRequests(_dummyHelpSeekerId);

      setState(() {
        _requests = items;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load your requests: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Help Requests'),
        actions: [
          TextButton(
            onPressed: _loadMyRequests,
            child: const Text(
              'Refresh',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _requests.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'You have not created any help requests yet.\n'
                          'Create a new request from the Home screen.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final e = _requests[index];
                        return EmergencyCard(
                          emergency: e,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RequestDetailScreen(emergency: e),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}