import 'package:flutter/material.dart';
import '../models/emergency.dart';

class EmergencyCard extends StatelessWidget {
  final Emergency emergency;
  final VoidCallback? onTap;

  const EmergencyCard({
    super.key,
    required this.emergency,
    this.onTap,
  });

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Medical':
        return Icons.health_and_safety;
      case 'Missing Pet':
        return Icons.pets;
      case 'Environmental':
        return Icons.water_drop;
      case 'Daily Support':
      default:
        return Icons.handshake;
    }
  }

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(emergency.category),
                  size: 30,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 16),

              // Main Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Urgency Tag
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            emergency.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _urgencyColor(emergency.urgency).withOpacity(0.15),
                          ),
                          child: Text(
                            emergency.urgency,
                            style: TextStyle(
                              color: _urgencyColor(emergency.urgency),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Category & Location
                    Row(
                      children: [
                        Text(
                          emergency.category,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on, size: 14),
                        Text(
                          emergency.location,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Description
                    Text(
                      emergency.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}