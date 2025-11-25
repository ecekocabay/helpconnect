class Emergency {
  final String id;
  final String title;
  final String description;
  final String category; // e.g. "Medical", "Missing Pet", "Environmental", "Daily Support"
  final String urgency;  // "Low", "Medium", "High"
  final String location; // simple text for now

  Emergency({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.location,
  });
}