import 'dart.io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _selectedCategory = 'Medical';
  String _selectedUrgency = 'Medium';

  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // later: send _selectedImage + form data to backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Help Request submitted (mock).')),
    );

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Help Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Short summary (e.g., "Urgent blood needed")',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Describe what kind of help is needed, when, where, etc.',
                    ),
                    maxLines: 4,
                    validator: (v) => v == null || v.length < 10
                        ? 'Please provide at least 10 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Medical',
                        child: Text('Medical (e.g., blood donation)'),
                      ),
                      DropdownMenuItem(
                        value: 'Missing Pet',
                        child: Text('Missing Pet / Missing Person'),
                      ),
                      DropdownMenuItem(
                        value: 'Environmental',
                        child: Text('Environmental (flood, fire, etc.)'),
                      ),
                      DropdownMenuItem(
                        value: 'Daily Support',
                        child: Text('Daily Support (groceries, transport, etc.)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedUrgency,
                    decoration: const InputDecoration(
                      labelText: 'Urgency',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Low',
                        child: Text('Low'),
                      ),
                      DropdownMenuItem(
                        value: 'Medium',
                        child: Text('Medium'),
                      ),
                      DropdownMenuItem(
                        value: 'High',
                        child: Text('High'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedUrgency = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Image picker + preview
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Attach Image (optional)'),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedImage != null)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        // ignore: unnecessary_non_null_assertion
                        // we know it's non-null due to the if above
                        File(_selectedImage!.path),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onSubmit,
                      child: const Text('Submit Help Request'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}