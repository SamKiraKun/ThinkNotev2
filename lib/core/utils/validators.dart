class Validators {
  const Validators._();

  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  static String? validateFullName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Full name is required';
    }

    if (trimmed.length < 2) {
      return 'Enter your full name';
    }

    return null;
  }

  static String? validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Email is required';
    }

    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  static String? validatePassword(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Password is required';
    }

    if (trimmed.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  static String? validateConfirmPassword({
    required String password,
    required String confirmation,
  }) {
    final trimmed = confirmation.trim();
    if (trimmed.isEmpty) {
      return 'Confirm your password';
    }

    if (password != confirmation) {
      return 'Passwords do not match';
    }

    return null;
  }
}