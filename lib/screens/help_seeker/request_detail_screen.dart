import 'package:flutter/material.dart';
import '../../models/emergency.dart';

class RequestDetailScreen extends StatelessWidget {
  final Emergency emergency;

  const RequestDetailScreen({
    super.key,
    required this.emergency,
  });

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orange;
      case 'Low':
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(emergency.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emergency.category,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Urgency: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      emergency.urgency,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _urgencyColor(emergency.urgency),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 18),
                    const SizedBox(width: 4),
                    Text(emergency.location),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  emergency.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                // Placeholder: later we can show attached images, map, etc.
                const Text(
                  'Additional details, images, and volunteer actions will appear here.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}