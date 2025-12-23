import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_client.dart';
import 'package:helpconnect/widgets/app_bar_buttons.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = 'Medical';
  String _selectedUrgency = 'High';

  bool _isSubmitting = false;
  String? _errorMessage;

  final ApiClient _apiClient = ApiClient();
  final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;

  double? _lat;
  double? _lng;
  String? _locationStatus;

  static const List<String> _categories = [
    'Medical',
    'Missing Pet',
    'Environmental',
    'Daily Support',
  ];

  static const List<String> _urgencies = [
    'High',
    'Medium',
    'Low',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _goBack() => Navigator.pop(context);
  void _cancel() => Navigator.pop(context, false);

  Future<void> _pickImage() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted) return;
      setState(() => _pickedImage = img);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Image selection failed: $e');
    }
  }

  void _removeImage() {
    setState(() => _pickedImage = null);
  }

  Future<void> _useMyLocation() async {
    try {
      setState(() => _locationStatus = 'Getting location...');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationStatus = 'Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationStatus = 'Location permission denied.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationStatus = 'Location saved.';
      });
    } catch (e) {
      setState(() => _locationStatus = 'Failed to get location: $e');
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // 1) Create request
      final requestId = await _apiClient.createHelpRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        urgency: _selectedUrgency,
        location: _locationController.text.trim(),
        latitude: _lat,
        longitude: _lng,
      );

      // 2) If user selected an image -> upload + attach
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();

        final nameLower = _pickedImage!.name.toLowerCase();
        final contentType =
            nameLower.endsWith('.png') ? 'image/png' : 'image/jpeg';

        final presign = await _apiClient.getUploadUrl(
          requestId: requestId,
          contentType: contentType,
        );

        // Debug: log presign response to help diagnose attachment problems
        debugPrint('getUploadUrl response: $presign');

        final uploadUrl = presign['uploadUrl'] as String?;
        final imageKey = presign['imageKey'] as String?;
        final imageId = (presign['image_id'] ?? presign['imageId']) as String?;

        if (uploadUrl == null || imageKey == null || imageId == null) {
          throw Exception('UploadUrl response missing fields: $presign');
        }

        await _apiClient.uploadToS3Presigned(
          uploadUrl: uploadUrl,
          bytes: bytes,
          contentType: contentType,
        );

        await _apiClient.attachImageToRequest(
          requestId: requestId,
          imageKey: imageKey,
          imageId: imageId,
        );

        // Debug: confirm attach succeeded (no exception thrown means HTTP 200/201)
        debugPrint('attachImageToRequest called for request=$requestId imageKey=$imageKey imageId=$imageId');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar(
        title: 'New Help Request',
        leadingWidth: 90,
        leading: appBarTextButton(
          label: 'Back',
          onPressed: _isSubmitting ? null : _goBack,
        ),
        actions: [
          appBarTextButton(
            label: 'Cancel',
            onPressed: _isSubmitting ? null : _cancel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField(
                value: _selectedCategory,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
                decoration: const InputDecoration(labelText: 'Category'),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField(
                value: _selectedUrgency,
                items: _urgencies
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUrgency = v!),
                decoration: const InputDecoration(labelText: 'Urgency'),
              ),

              const SizedBox(height: 18),

              // Image upload area (labels only, clearer instructions)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Attach Image (optional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    if (_pickedImage == null) ...[
                      const Text(
                        'No image selected. Tap the button below to choose an image to attach to this request. Accepted: JPG, PNG.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : _pickImage,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Select Image', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Selected file: ${_pickedImage!.name}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : _pickImage,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Change Image', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _isSubmitting ? null : _removeImage,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Remove Image', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // GPS location block (labels only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('GPS Location (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _useMyLocation,
                      child: const Text('Use My Current Location'),
                    ),
                    const SizedBox(height: 8),
                    if (_lat != null && _lng != null)
                      Text('Saved: $_lat, $_lng')
                    else
                      const Text('No location saved.', style: TextStyle(color: Colors.black54)),
                    if (_locationStatus != null) ...[
                      const SizedBox(height: 6),
                      Text(_locationStatus!, style: const TextStyle(color: Colors.black54)),
                    ],
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                                _lat = null;
                                _lng = null;
                                _locationStatus = null;
                              }),
                      child: const Text('Clear Location'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}