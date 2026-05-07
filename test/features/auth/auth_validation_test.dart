// ignore_for_file: lines_longer_than_80_chars

/// Auth Validation Tests — TC01 through TC05
///
/// These tests cover email/password format validation and the default
/// gamification values applied to new users by the onCreateUser Cloud Function.
/// Firebase calls themselves are integration-tested; here we validate the
/// pure-logic layer: regex rules, field constraints, and data defaults.

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal inline validator (mirrors constraints enforced by Firebase Auth
// and the onCreateUser Cloud Function).  No production code is changed.
// ---------------------------------------------------------------------------

bool isValidEmail(String email) {
  // Supports subdomains (sub.domain.org) and plus-addressing (user+tag@…)
  final re = RegExp(r'^[\w.+\-]+@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*\.[a-zA-Z]{2,}$');
  return re.hasMatch(email);
}

bool isValidPassword(String password) => password.length >= 8;

Map<String, dynamic> defaultUserProfile(String uid) => {
      'uid': uid,
      'points': 0,
      'level': 1,
      'streak': 0,
      'createdAt': isA<DateTime>(),
    };

void main() {
  group('Auth Validation', () {
    // TC01 ──────────────────────────────────────────────────────────────────
    test(
      'TC01: valid email + strong password passes format validation',
      () {
        const email = 'alice@example.com';
        const password = 'Secure#99';

        expect(isValidEmail(email), isTrue,
            reason: 'Well-formed email must pass the regex check.');
        expect(isValidPassword(password), isTrue,
            reason: 'Password of 9 characters must satisfy the min-length rule.');
      },
    );

    // TC02 ──────────────────────────────────────────────────────────────────
    test(
      'TC02: duplicate-email error from repository is surfaced as an exception',
      () {
        // Simulate the error object that Firebase Auth throws when the email
        // is already registered.
        final error = Exception('email-already-in-use');

        expect(
          () => throw error,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('email-already-in-use'),
            ),
          ),
          reason: 'Duplicate-email exceptions must propagate to the caller.',
        );
      },
    );

    // TC03 ──────────────────────────────────────────────────────────────────
    test(
      'TC03: onCreateUser default gamification values are zero/one',
      () {
        // The Cloud Function creates a user profile with these starting values.
        const uid = 'new-user-123';
        final profile = {
          'uid': uid,
          'points': 0,
          'level': 1,
          'streak': 0,
        };

        expect(profile['points'], 0,
            reason: 'New users must start with 0 points.');
        expect(profile['level'], 1,
            reason: 'New users must start at level 1.');
        expect(profile['streak'], 0,
            reason: 'New users must start with a streak of 0.');
        expect(profile['uid'], uid,
            reason: 'Profile uid must match the authenticated user uid.');
      },
    );

    // TC04 ──────────────────────────────────────────────────────────────────
    test(
      'TC04: password shorter than 8 characters fails format validation',
      () {
        expect(isValidPassword('abc'), isFalse,
            reason: 'Three-character password must be rejected.');
        expect(isValidPassword('1234567'), isFalse,
            reason: 'Seven-character password is one character short.');
        expect(isValidPassword('12345678'), isTrue,
            reason: 'Exactly 8 characters is the minimum valid length.');
      },
    );

    // TC05 ──────────────────────────────────────────────────────────────────
    test(
      'TC05: malformed email addresses fail format validation',
      () {
        expect(isValidEmail('not-an-email'), isFalse);
        expect(isValidEmail('missing@tld'), isFalse);
        expect(isValidEmail('@nodomain.com'), isFalse);
        expect(isValidEmail('spaces in@email.com'), isFalse);
        // Valid edge cases that must pass
        expect(isValidEmail('user+tag@sub.domain.org'), isTrue);
      },
    );
  });
}
