import 'package:flutter/material.dart';
import '../../models/emergency.dart';
import '../../models/offer.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';

class RequestDetailScreen extends StatefulWidget {
  final Emergency emergency;
  final bool showVolunteerActions;

  const RequestDetailScreen({
    super.key,
    required this.emergency,
    this.showVolunteerActions = false,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final ApiClient _apiClient = ApiClient();

  Emergency? _currentEmergency;

  bool _isOfferingHelp = false;
  bool _isAccepting = false;
  bool _isClosing = false;

  String? _errorMessage;

  List<Offer> _offers = [];
  bool _isLoadingOffers = false;
  String? _offersError;

  String? _mySub;
  bool _loadingMe = true;

  // Images
  bool _loadingImages = false;
  String? _imagesError;
  List<String> _imageUrls = []; // presigned GET urls

  ButtonStyle get _blackElevatedButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black54,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  void initState() {
    super.initState();
    _currentEmergency = widget.emergency;
    _init();
  }

  Future<void> _init() async {
    setState(() => _loadingMe = true);

    try {
      final sub = await AuthService.instance.getUserSub();

      if (!mounted) return;
      setState(() {
        _mySub = sub;
        _loadingMe = false;
      });

      await _refreshRequest();
      await _loadOffers();
      await _loadImages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMe = false;
        _errorMessage = 'Failed to load session/user: $e';
      });

      await _loadOffers();
      await _loadImages();
    }
  }

  Emergency get _e => _currentEmergency ?? widget.emergency;

  bool get _isOwner {
    final helpSeekerId = _e.helpSeekerId;
    if (_mySub == null || helpSeekerId.isEmpty) return false;
    return _mySub == helpSeekerId;
  }

  String get _statusUpper => _e.status.trim().toUpperCase();
  bool get _requestIsOpen => _statusUpper == 'OPEN';
  bool get _requestIsInProgress => _statusUpper == 'IN_PROGRESS';
  bool get _requestIsClosed => _statusUpper == 'CLOSED';

  Future<void> _refreshRequest() async {
    try {
      final updated = await _apiClient.getHelpRequest(_e.id);
      if (!mounted) return;
      setState(() => _currentEmergency = updated);
    } catch (_) {}
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoadingOffers = true;
      _offersError = null;
    });

    try {
      final items = await _apiClient.fetchOffersForRequest(_e.id);
      if (!mounted) return;
      setState(() => _offers = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _offersError = 'Failed to load offers: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOffers = false);
    }
  }

  Future<void> _loadImages() async {
    setState(() {
      _loadingImages = true;
      _imagesError = null;
      _imageUrls = [];
    });

    try {
      final items = await _apiClient.listRequestImages(requestId: _e.id);
      debugPrint('listRequestImages returned: $items');

      final urls = <String>[];
      for (final it in items) {
        final key = (it['imageKey'] ?? it['image_key']) as String?;
        if (key == null || key.isEmpty) continue;

        debugPrint('found imageKey: $key');

        final viewUrl = await _apiClient.getViewUrl(key: key);
        debugPrint('getViewUrl for key $key returned: $viewUrl');

        urls.add(viewUrl);
      }

      if (!mounted) return;
      setState(() => _imageUrls = urls);
    } catch (e) {
      if (mounted) setState(() => _imagesError = 'Failed to load images: $e');
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _handleOfferHelp() async {
    if (!_requestIsOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This request is not open anymore.')),
      );
      return;
    }

    setState(() {
      _isOfferingHelp = true;
      _errorMessage = null;
    });

    try {
      final data = await _showOfferDialog();
      if (data == null) return;

      await _apiClient.offerHelp(
        requestId: _e.id,
        note: data['note'] as String,
        estimatedArrivalMinutes: data['eta'] as int,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your offer to help has been sent.')),
      );

      await _refreshRequest();
      await _loadOffers();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to send offer: $e');
    } finally {
      if (mounted) setState(() => _isOfferingHelp = false);
    }
  }

  Future<Map<String, dynamic>?> _showOfferDialog() async {
    final noteCtrl = TextEditingController();
    final etaCtrl = TextEditingController(text: '15');

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Offer Help'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Write a short message...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: etaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ETA (minutes)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final note = noteCtrl.text.trim();
                final eta = int.tryParse(etaCtrl.text.trim()) ?? 15;
                Navigator.pop(ctx, {
                  'note': note.isEmpty ? 'I can help with this request.' : note,
                  'eta': eta,
                });
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAcceptOffer(Offer offer) async {
    if (!_requestIsOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This request is not OPEN anymore.')),
      );
      return;
    }

    setState(() {
      _isAccepting = true;
      _errorMessage = null;
    });

    try {
      await _apiClient.acceptOffer(
        requestId: _e.id,
        offerId: offer.offerId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer accepted. Request is now IN_PROGRESS.'),
        ),
      );

      await _refreshRequest();
      await _loadOffers();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to accept offer: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isAccepting = false);
    }
  }

  // ✅ CLOSE REQUEST (uses PATCH endpoint via ApiClient)
  Future<void> _handleCloseRequest() async {
    if (!_requestIsInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request can be closed only when IN_PROGRESS.'),
        ),
      );
      return;
    }

    setState(() {
      _isClosing = true;
      _errorMessage = null;
    });

    try {
      await _apiClient.closeRequest(requestId: _e.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request closed successfully.')),
      );

      await _refreshRequest();
      await _loadOffers();
      await _loadImages();

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to close request: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isClosing = false);
    }
  }

  Widget _buildImagesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Images',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_loadingImages)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_imagesError != null)
          Text(_imagesError!, style: const TextStyle(color: Colors.redAccent))
        else if (_imageUrls.isEmpty)
          const Text('No images attached.')
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final url = _imageUrls[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Text(
                            'Image failed to load',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                              child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOffersSection(ThemeData theme) {
    final canAccept =
        (widget.showVolunteerActions == false) && _isOwner && _requestIsOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Volunteer Offers',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
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
              style: const TextStyle(color: Colors.redAccent),
            ),
          )
        else if (_offers.isEmpty)
          const Text('No volunteers have offered help yet.')
        else
          Column(
            children: _offers.map((offer) {
              final isAccepted =
                  (offer.status ?? '').trim().toUpperCase() == 'ACCEPTED';

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
                      'Volunteer: ${offer.volunteerEmail ?? offer.volunteerId}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (offer.note != null && offer.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note: ${offer.note}'),
                    ],
                    if (offer.status != null) ...[
                      const SizedBox(height: 4),
                      Text('Status: ${offer.status}'),
                    ],
                    if (canAccept && !isAccepted) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: _blackElevatedButtonStyle,
                          onPressed: _isAccepting
                              ? null
                              : () => _handleAcceptOffer(offer),
                          child: _isAccepting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Accept this volunteer'),
                        ),
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
    final theme = Theme.of(context);
    final e = _e;

    final canClose =
        !widget.showVolunteerActions && _isOwner && _requestIsInProgress;

    return Scaffold(
      appBar: standardAppBar(
        title: 'Emergency Details',
        leadingWidth: 80,
        leading: appBarTextButton(
          label: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          appBarTextButton(
            label: 'Refresh',
            onPressed: () async {
              await _refreshRequest();
              await _loadOffers();
              await _loadImages();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            Text(
              e.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(e.category)),
                Chip(label: Text('Urgency: ${e.urgency}')),
                Chip(label: Text('Status: ${e.status}')),
              ],
            ),
            const SizedBox(height: 12),
            Text('Location:', style: theme.textTheme.titleMedium),
            Text(e.location),
            const SizedBox(height: 12),
            Text('Description:', style: theme.textTheme.titleMedium),
            Text(e.description),

            _buildImagesSection(theme),
            _buildOffersSection(theme),
            const SizedBox(height: 24),

            // Volunteer action
            if (widget.showVolunteerActions) ...[
              if (_requestIsOpen)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: _blackElevatedButtonStyle,
                    onPressed: _isOfferingHelp ? null : _handleOfferHelp,
                    child: _isOfferingHelp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('I want to help'),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    _requestIsClosed
                        ? 'This request is CLOSED. You can’t send a new offer.'
                        : 'This request is not OPEN anymore. You can’t send a new offer.',
                  ),
                ),
            ],

            // Close button (only owner + IN_PROGRESS)
            if (canClose) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: _blackElevatedButtonStyle,
                  onPressed: _isClosing ? null : _handleCloseRequest,
                  child: _isClosing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Close Request'),
                ),
              ),
            ],

            if (_loadingMe)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}