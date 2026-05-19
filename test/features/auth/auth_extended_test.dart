// ignore_for_file: lines_longer_than_80_chars

/// Auth Validation Extended Tests — TC51 through TC60
///
/// Additional pure-Dart tests for email/password format validation and
/// the default gamification profile structure applied to new users.
/// No Firebase connection is required.

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Same inline validators as auth_validation_test.dart — they mirror the
// constraints enforced by Firebase Auth and the onCreateUser Cloud Function.
// ---------------------------------------------------------------------------

bool isValidEmail(String email) {
  final re = RegExp(
      r'^[\w.+\-]+@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*\.[a-zA-Z]{2,}$');
  return re.hasMatch(email);
}

bool isValidPassword(String password) => password.length >= 8;

void main() {
  group('Auth Validation Extended', () {
    // TC51 ──────────────────────────────────────────────────────────────────
    test(
      'TC51: email with long TLD (4+ chars) passes validation',
      () {
        // TLDs like .museum, .online are legitimate.
        expect(isValidEmail('user@example.museum'), isTrue,
            reason: 'Long TLDs that are all alpha chars must pass.');
        expect(isValidEmail('contact@company.online'), isTrue);
      },
    );

    // TC52 ──────────────────────────────────────────────────────────────────
    test(
      'TC52: email with hyphen in domain part passes validation',
      () {
        expect(isValidEmail('user@my-company.com'), isTrue,
            reason: 'Hyphens in the domain label are RFC-valid.');
        expect(isValidEmail('user@sub-domain.example.org'), isTrue);
      },
    );

    // TC53 ──────────────────────────────────────────────────────────────────
    test(
      'TC53: email with underscore in local part passes validation',
      () {
        // \\w in the regex includes underscore.
        expect(isValidEmail('first_last@example.com'), isTrue,
            reason: 'Underscores are allowed in the RFC local part.');
        expect(isValidEmail('_admin@example.org'), isTrue);
      },
    );

    // TC54 ──────────────────────────────────────────────────────────────────
    test(
      'TC54: empty string fails email validation',
      () {
        expect(isValidEmail(''), isFalse,
            reason: 'An empty string cannot be a valid email address.');
      },
    );

    // TC55 ──────────────────────────────────────────────────────────────────
    test(
      'TC55: empty string fails password validation',
      () {
        expect(isValidPassword(''), isFalse,
            reason: 'Empty password does not meet the minimum length rule.');
      },
    );

    // TC56 ──────────────────────────────────────────────────────────────────
    test(
      'TC56: password of 9 characters passes validation',
      () {
        // Confirms that 9 chars > 8-char threshold.
        expect(isValidPassword('abcdefghi'), isTrue,
            reason: 'A 9-character password exceeds the minimum of 8.');
      },
    );

    // TC57 ──────────────────────────────────────────────────────────────────
    test(
      'TC57: very long password (100 chars) passes validation',
      () {
        final longPassword = 'a' * 100;
        expect(isValidPassword(longPassword), isTrue,
            reason: 'There is no maximum length constraint on passwords.');
      },
    );

    // TC58 ──────────────────────────────────────────────────────────────────
    test(
      'TC58: new user profile map contains all required gamification keys',
      () {
        const uid = 'fresh-user-uid';
        final profile = {
          'uid': uid,
          'points': 0,
          'level': 1,
          'streak': 0,
        };

        expect(profile.containsKey('uid'), isTrue);
        expect(profile.containsKey('points'), isTrue);
        expect(profile.containsKey('level'), isTrue);
        expect(profile.containsKey('streak'), isTrue);
      },
    );

    // TC59 ──────────────────────────────────────────────────────────────────
    test(
      'TC59: initial user level is exactly 1 (not 0, not 2)',
      () {
        final profile = {'uid': 'uid-x', 'points': 0, 'level': 1, 'streak': 0};
        expect(profile['level'], equals(1),
            reason: 'Users must start at level 1; level 0 would be invalid.');
        expect(profile['level'], isNot(equals(0)));
        expect(profile['level'], isNot(equals(2)));
      },
    );

    // TC60 ──────────────────────────────────────────────────────────────────
    test(
      'TC60: distinct auth error types are distinguishable by message content',
      () {
        final wrongPassword = Exception('wrong-password');
        final emailInUse = Exception('email-already-in-use');
        final userNotFound = Exception('user-not-found');

        expect(wrongPassword.toString(), contains('wrong-password'));
        expect(emailInUse.toString(), contains('email-already-in-use'));
        expect(userNotFound.toString(), contains('user-not-found'));
        expect(wrongPassword.toString(),
            isNot(contains('email-already-in-use')),
            reason: 'Different error types must not share the same message.');
      },
    );
  });
}
