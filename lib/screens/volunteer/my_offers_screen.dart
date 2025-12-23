import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../models/offer.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';
import '../help_seeker/request_detail_screen.dart';

class MyOffersScreen extends StatefulWidget {
  const MyOffersScreen({super.key});

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen> {
  final ApiClient _apiClient = ApiClient();
  List<Offer> _offers = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _apiClient.fetchMyOffers();
      if (!mounted) return;
      setState(() => _offers = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load offers: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openRequest(String requestId) async {
    try {
      final request = await _apiClient.getHelpRequest(requestId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(emergency: request),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar(
        title: 'My Offers',
        leadingWidth: 80,
        leading: appBarTextButton(
          label: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          appBarTextButton(
            label: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _offers.isEmpty
                  ? const Center(child: Text('You have not offered help yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _offers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final o = _offers[i];

                        // ✅ Prefer email if available, fallback to volunteerId
                        final volunteerLabel = (o.volunteerEmail != null &&
                                o.volunteerEmail!.trim().isNotEmpty)
                            ? o.volunteerEmail!
                            : o.volunteerId;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request: ${o.requestId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 6),
                              Text('Volunteer: $volunteerLabel'),

                              if (o.note != null && o.note!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('Note: ${o.note}'),
                              ],

                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _openRequest(o.requestId),
                                    child: const Text('View Request'),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    o.status ?? '',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}