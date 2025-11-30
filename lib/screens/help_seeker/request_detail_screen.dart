import 'package:flutter/material.dart';

import '../../models/emergency.dart';
import '../../models/offer.dart';
import '../../services/api_client.dart';

class RequestDetailScreen extends StatefulWidget {
  final Emergency emergency;

  /// If true, show "I want to help" (Volunteer view).
  /// If false, only show details (Help Seeker view) + offers list.
  final bool showVolunteerActions;

  const RequestDetailScreen({
    super.key,
    required this.emergency,
    this.showVolunteerActions = false, // default: help seeker view
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final ApiClient _apiClient = ApiClient();

  // TODO: later replace with real volunteer id from Cognito/auth
  final String _dummyVolunteerId = 'demo-volunteer-1';

  bool _isOfferingHelp = false;
  String? _errorMessage;

  // ---- NEW: offers for this request ----
  List<Offer> _offers = [];
  bool _isLoadingOffers = false;
  String? _offersError;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoadingOffers = true;
      _offersError = null;
    });

    try {
      final items =
          await _apiClient.fetchOffersForRequest(widget.emergency.id);
      setState(() {
        _offers = items;
      });
    } catch (e) {
      setState(() {
        _offersError = 'Failed to load offers: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingOffers = false;
      });
    }
  }

  Future<void> _handleOfferHelp() async {
    setState(() {
      _isOfferingHelp = true;
      _errorMessage = null;
    });

    try {
      await _apiClient.offerHelp(
        requestId: widget.emergency.id,
        volunteerId: _dummyVolunteerId,
        note: 'I can help with this request.',
        estimatedArrivalMinutes: 15,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your offer to help has been sent.'),
        ),
      );

      // After sending an offer, refresh the offers list
      await _loadOffers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to send offer: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isOfferingHelp = false;
      });
    }
  }

  Widget _buildOffersSection(ThemeData theme) {
    // We always show the offers section for transparency (both roles),
    // but it is mainly for the Help Seeker.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Volunteer Offers',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        if (_isLoadingOffers)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_offersError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _offersError!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.redAccent),
            ),
          )
        else if (_offers.isEmpty)
          Text(
            'No volunteers have offered help yet.',
            style: theme.textTheme.bodyMedium,
          )
        else
          Column(
            children: _offers.map((offer) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volunteer: ${offer.volunteerId}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (offer.note != null &&
                        offer.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${offer.note}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (offer.estimatedArrivalMinutes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Estimated arrival: ${offer.estimatedArrivalMinutes} minutes',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (offer.status != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${offer.status}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (offer.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Sent at: ${offer.createdAt}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.emergency;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error from "offer help" action
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.redAccent),
                ),
              ),
            ],

            // Title
            Text(
              e.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Chips (text only)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(e.category),
                ),
                Chip(
                  label: Text('Urgency: ${e.urgency}'),
                ),
                if (e.status != null)
                  Chip(
                    label: Text('Status: ${e.status}'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Location
            Text(
              'Location:',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              e.location,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Description',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              e.description,
              style: theme.textTheme.bodyMedium,
            ),

            // Volunteer offers list (both roles can see)
            _buildOffersSection(theme),

            const SizedBox(height: 24),

            // Volunteer actions (only for volunteers)
            if (widget.showVolunteerActions) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isOfferingHelp ? null : _handleOfferHelp,
                  child: _isOfferingHelp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I want to help'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}