class ValidationItem {
  final String title;
  final String description;
  final bool isValid;
  final String? errorMessage;
  final List<String>? details;

  const ValidationItem({
    required this.title,
    required this.description,
    required this.isValid,
    this.errorMessage,
    this.details,
  });
}