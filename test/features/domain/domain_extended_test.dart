// ignore_for_file: lines_longer_than_80_chars

/// Domain Management Extended Tests — TC106 through TC115
///
/// Additional pure-Dart tests for DomainEntity: copyWith field updates,
/// sorting, Firestore serialization defaults, and structural invariants.
/// No Firebase connection required.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/dashboard/domain/entities/domain_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC106 ───────────────────────────────────────────────────────────────────
  group('TC106: DomainEntity copyWith updates name', () {
    test('new name is stored while all other fields remain unchanged', () {
      final original = Fixtures.domain(name: 'Health');
      final renamed = original.copyWith(name: 'Wellness');

      expect(renamed.name, 'Wellness');
      expect(renamed.id, original.id);
      expect(renamed.colorHex, original.colorHex);
      expect(renamed.iconCode, original.iconCode);
    });
  });

  // TC107 ───────────────────────────────────────────────────────────────────
  group('TC107: DomainEntity copyWith updates colorHex', () {
    test('new colorHex is reflected without affecting other fields', () {
      final original = Fixtures.domain(colorHex: '#7C4DFF');
      final recolored = original.copyWith(colorHex: '#E91E63');

      expect(recolored.colorHex, '#E91E63');
      expect(recolored.name, original.name);
      expect(recolored.id, original.id);
    });
  });

  // TC108 ───────────────────────────────────────────────────────────────────
  group('TC108: DomainEntity copyWith updates iconCode', () {
    test('new iconCode is stored correctly', () {
      final original = Fixtures.domain(iconCode: 0xe1af);
      final updated = original.copyWith(iconCode: 0xe52f);

      expect(updated.iconCode, 0xe52f);
      expect(updated.name, original.name);
    });
  });

  // TC109 ───────────────────────────────────────────────────────────────────
  group('TC109: DomainEntity copyWith updates description', () {
    test('description can be set on a domain that had none', () {
      final original = Fixtures.domain(description: null);
      final described = original.copyWith(description: 'Tracks health habits');

      expect(described.description, 'Tracks health habits');
      expect(original.description, isNull,
          reason: 'Original entity must not be mutated.');
    });
  });

  // TC110 ───────────────────────────────────────────────────────────────────
  group('TC110: domains sorted alphabetically by name', () {
    test('ascending sort puts domains in A-Z order', () {
      final domains = [
        Fixtures.domain(id: '3', name: 'Fitness'),
        Fixtures.domain(id: '1', name: 'Career'),
        Fixtures.domain(id: '2', name: 'Education'),
      ];

      final sorted = domains..sort((a, b) => a.name.compareTo(b.name));

      expect(sorted.map((d) => d.name).toList(), ['Career', 'Education', 'Fitness'],
          reason: 'Domains must be ordered alphabetically for dashboard display.');
    });
  });

  // TC111 ───────────────────────────────────────────────────────────────────
  group('TC111: domain with description includes it in toFirestore', () {
    test('description key appears in map with correct value', () {
      final domain = Fixtures.domain(description: 'Personal wellness tracking');
      final map = domain.toFirestore();

      expect(map.containsKey('description'), isTrue);
      expect(map['description'], 'Personal wellness tracking');
    });
  });

  // TC112 ───────────────────────────────────────────────────────────────────
  group('TC112: domain without description serializes description as null', () {
    test('null description is present in map but null-valued', () {
      final domain = Fixtures.domain(description: null);
      final map = domain.toFirestore();

      // toFirestore always includes 'description', even when null.
      expect(map.containsKey('description'), isTrue);
      expect(map['description'], isNull);
    });
  });

  // TC113 ───────────────────────────────────────────────────────────────────
  group('TC113: DomainEntity fromFirestore uses default iconCode when missing', () {
    test('missing iconCode field defaults to 0xe1af', () {
      final entity = DomainEntity.fromFirestore('dom-default', {
        'name': 'Default Icon Domain',
        'colorHex': '#7C4DFF',
        // 'iconCode' intentionally omitted
      });

      expect(entity.iconCode, 0xe1af,
          reason: 'Default iconCode must match the Flutter icon for the default domain icon.');
    });
  });

  // TC114 ───────────────────────────────────────────────────────────────────
  group('TC114: DomainEntity fromFirestore uses default colorHex when missing', () {
    test('missing colorHex defaults to purple (#7C4DFF)', () {
      final entity = DomainEntity.fromFirestore('dom-no-color', {
        'name': 'No Color Domain',
        'iconCode': 0xe1af,
        // 'colorHex' intentionally omitted
      });

      expect(entity.colorHex, '#7C4DFF',
          reason: 'Domains without a stored color must fall back to the brand purple.');
    });
  });

  // TC115 ───────────────────────────────────────────────────────────────────
  group('TC115: multiple domains with the same colorHex can coexist', () {
    test('two domains sharing a colorHex are distinct entities via their id', () {
      final d1 = Fixtures.domain(id: 'dom-a', name: 'Health', colorHex: '#E91E63');
      final d2 = Fixtures.domain(id: 'dom-b', name: 'Fitness', colorHex: '#E91E63');

      expect(d1.id, isNot(equals(d2.id)),
          reason: 'Sharing a color does not make two domains the same entity.');
      expect(d1.colorHex, d2.colorHex);
      expect(d1.name, isNot(equals(d2.name)));
    });
  });
}
