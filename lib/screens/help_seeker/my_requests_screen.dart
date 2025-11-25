import 'package:flutter/material.dart';
import '../../models/emergency.dart';
import '../../widgets/emergency_card.dart';
import 'request_detail_screen.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  // Mock "my" requests (later: fetch by userId)
  List<Emergency> get _myRequests => [
        Emergency(
          id: '1',
          title: 'Need O+ Blood Urgently',
          description: 'Scheduled surgery at 18:00, donor required urgently.',
          category: 'Medical',
          urgency: 'High',
          location: 'City Hospital',
        ),
        Emergency(
          id: '4',
          title: 'Help with Carrying Boxes',
          description: 'Need assistance carrying moving boxes to 3rd floor.',
          category: 'Daily Support',
          urgency: 'Low',
          location: 'Block A Apartments',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final requests = _myRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
      ),
      body: requests.isEmpty
          ? const Center(
              child: Text(
                'You have not created any requests yet.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final e = requests[index];
                return EmergencyCard(
                  emergency: e,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestDetailScreen(emergency: e),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}