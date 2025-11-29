class Emergency {
  final String id;
  final String title;
  final String description;
  final String category;
  final String urgency;
  final String location;
  final String? status;
  final String? helpSeekerId;

  Emergency({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.location,
    this.status,
    this.helpSeekerId,
  });

  factory Emergency.fromJson(Map<String, dynamic> json) {
    return Emergency(
      id: json['request_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      urgency: json['urgency'] as String? ?? '',
      location: json['location'] as String? ?? '',
      status: json['status'] as String?,
      helpSeekerId: json['help_seeker_id'] as String?,
    );
  }
}