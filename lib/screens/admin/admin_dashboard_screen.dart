import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock stats – later will come from backend
    const int totalRequests = 25;
    const int openRequests = 10;
    const int inProgressRequests = 7;
    const int fulfilledRequests = 8;

    final List<Map<String, String>> recentRequests = [
      {
        'id': 'REQ-001',
        'title': 'Urgent Blood Donation Needed',
        'category': 'Medical',
        'status': 'Open',
      },
      {
        'id': 'REQ-002',
        'title': 'Missing Dog in Neighborhood',
        'category': 'Missing Pet',
        'status': 'In Progress',
      },
      {
        'id': 'REQ-003',
        'title': 'Flooded Basement Help',
        'category': 'Environmental',
        'status': 'Open',
      },
      {
        'id': 'REQ-004',
        'title': 'Help with Groceries',
        'category': 'Daily Support',
        'status': 'Fulfilled',
      },
    ];

    Color statusColor(String status) {
      switch (status) {
        case 'Open':
          return Colors.redAccent;
        case 'In Progress':
          return Colors.orange;
        case 'Fulfilled':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Overview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                // Top stats cards
                Row(
                  children: [
                    _DashboardStatCard(
                      label: 'Total Requests',
                      value: totalRequests.toString(),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _DashboardStatCard(
                      label: 'Open',
                      value: openRequests.toString(),
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 12),
                    _DashboardStatCard(
                      label: 'In Progress',
                      value: inProgressRequests.toString(),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _DashboardStatCard(
                      label: 'Fulfilled',
                      value: fulfilledRequests.toString(),
                      color: Colors.green,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Text(
                  'Recent Requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Title')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: recentRequests.map((req) {
                      final status = req['status'] ?? '';
                      return DataRow(
                        cells: [
                          DataCell(Text(req['id'] ?? '')),
                          DataCell(Text(req['title'] ?? '')),
                          DataCell(Text(req['category'] ?? '')),
                          DataCell(
                            Text(
                              status,
                              style: TextStyle(
                                color: statusColor(status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
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

class _DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashboardStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}