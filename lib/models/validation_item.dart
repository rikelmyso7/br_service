class ValidationItem {
  final String title;
  final String description;
  final bool isValid;
  final String? errorMessage;

  const ValidationItem({
    required this.title,
    required this.description,
    required this.isValid,
    this.errorMessage,
  });
}