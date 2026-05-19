import '../../../core/localization/app_localizations.dart';

/// Pure validation helpers for the email/password auth flows.
///
/// Each returns `null` when the value is acceptable, or a localized message
/// describing what's wrong. Callers display the message via a SnackBar and
/// stop submission.
class AuthValidators {
  const AuthValidators._();

  static const int passwordMinLength = 6;
  static const int passwordMaxLength = 64;
  static const int nameMinLength = 2;

  // Pragmatic email regex: requires `local@domain.tld` shape with at least
  // one dot in the domain. Not RFC-perfect, but rejects the cases users
  // typically fat-finger (no @, no TLD, trailing spaces).
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );

  static String? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return S.of('email_required_field');
    if (!_emailRegex.hasMatch(trimmed)) return S.of('email_invalid');
    return null;
  }

  /// Lenient password check — only enforces non-empty. Used on the sign-in
  /// screen so legacy accounts whose password predates current rules can
  /// still log in; the server is the source of truth there.
  static String? passwordForSignIn(String value) {
    if (value.isEmpty) return S.of('password_required_field');
    return null;
  }

  /// Strict password check for account creation. Must be at least
  /// [passwordMinLength] chars, under [passwordMaxLength], and contain at
  /// least one letter and one digit. Whitespace-only is rejected.
  static String? passwordForRegister(String value) {
    if (value.isEmpty) return S.of('password_required_field');
    if (value.trim().length != value.length) {
      return S.of('password_no_whitespace');
    }
    if (value.length < passwordMinLength) return S.of('password_min_length');
    if (value.length > passwordMaxLength) return S.of('password_max_length');
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasDigit) return S.of('password_needs_letter_number');
    return null;
  }

  static String? confirmPassword(String password, String confirmation) {
    if (confirmation.isEmpty) return S.of('password_required_field');
    if (password != confirmation) return S.of('passwords_no_match');
    return null;
  }

  static String? displayName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return S.of('name_required');
    if (trimmed.length < nameMinLength) return S.of('name_min_length');
    return null;
  }
}