/// Form validators for LendLoop.

class AppValidators {
  AppValidators._();

  static const List<String> _allowedDomains = ['vit.ac.in', 'vitstudent.ac.in'];

  /// Validates that an email belongs to VIT domains.
  static String? validateVITEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    final domain = value.split('@').last.toLowerCase();
    if (!_allowedDomains.contains(domain)) {
      return 'Only @vit.ac.in or @vitstudent.ac.in emails are allowed';
    }
    return null;
  }

  static String? validateRequired(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? validateMinLength(String? value, int min, [String field = 'This field']) {
    if (value == null || value.length < min) return '$field must be at least $min characters';
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final phoneRegex = RegExp(r'^\+?[1-9]\d{9,14}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? validateRating(int? rating) {
    if (rating == null || rating < 1 || rating > 5) return 'Rating must be between 1 and 5';
    return null;
  }

  static String? validateDateRange(DateTime? start, DateTime? end) {
    if (start == null) return 'Start date is required';
    if (end == null) return 'End date is required';
    if (end.isBefore(start)) return 'End date must be after start date';
    final diff = end.difference(start).inDays;
    if (diff > 90) return 'Borrow period cannot exceed 90 days';
    return null;
  }
}
