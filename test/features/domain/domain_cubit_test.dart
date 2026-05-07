// ignore_for_file: lines_longer_than_80_chars

/// Domain Management Tests — TC06 through TC10
///
/// Tests for DomainCubit (business-logic layer) and DomainEntity (data layer).
/// MockDomainRepository stubs Firestore so no live connection is needed.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project_lifestable/features/dashboard/domain/entities/domain_entity.dart';
import 'package:project_lifestable/features/dashboard/logic/domain_cubit.dart';

import '../../helpers/fixtures.dart';
import '../../mocks/mocks.dart';

void main() {
  late MockDomainRepository mockRepo;

  setUpAll(registerFallbacks);

  setUp(() {
    mockRepo = MockDomainRepository();
  });

  // TC06 ────────────────────────────────────────────────────────────────────
  group('TC06: create a new Domain', () {
    blocTest<DomainCubit, DomainState>(
      'addDomain delegates to repository and emits no error',
      build: () {
        when(() => mockRepo.createOrUpdateDomain(any()))
            .thenAnswer((_) async {});
        when(() => mockRepo.watchDomains()).thenAnswer((_) => const Stream.empty());
        return DomainCubit(mockRepo);
      },
      act: (cubit) => cubit.addDomain(
        Fixtures.domain(name: 'School', colorHex: '#FF5722'),
      ),
      expect: () => <DomainState>[],
      verify: (_) {
        verify(() => mockRepo.createOrUpdateDomain(any())).called(1);
      },
    );
  });

  // TC07 ────────────────────────────────────────────────────────────────────
  group('TC07: update domain name and color', () {
    blocTest<DomainCubit, DomainState>(
      'updateDomain calls repository with modified entity',
      build: () {
        when(() => mockRepo.createOrUpdateDomain(any()))
            .thenAnswer((_) async {});
        when(() => mockRepo.watchDomains()).thenAnswer((_) => const Stream.empty());
        return DomainCubit(mockRepo);
      },
      act: (cubit) => cubit.updateDomain(
        Fixtures.domain(name: 'Career', colorHex: '#00BCD4'),
      ),
      expect: () => <DomainState>[],
      verify: (_) {
        verify(() => mockRepo.createOrUpdateDomain(any())).called(1);
      },
    );
  });

  // TC08 ────────────────────────────────────────────────────────────────────
  group('TC08: delete a Domain', () {
    blocTest<DomainCubit, DomainState>(
      'deleteDomain calls repository with the correct id',
      build: () {
        when(() => mockRepo.deleteDomain(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchDomains()).thenAnswer((_) => const Stream.empty());
        return DomainCubit(mockRepo);
      },
      act: (cubit) => cubit.deleteDomain('domain-1'),
      expect: () => <DomainState>[],
      verify: (_) {
        verify(() => mockRepo.deleteDomain('domain-1')).called(1);
      },
    );
  });

  // TC09 ────────────────────────────────────────────────────────────────────
  group('TC09: DomainEntity copyWith — reorder via name/color update', () {
    test('copyWith updates name and colorHex while preserving other fields', () {
      final original = Fixtures.domain(
        id: 'dom-42',
        name: 'Health',
        colorHex: '#7C4DFF',
        iconCode: 0xe1af,
      );

      final reordered = original.copyWith(name: 'Fitness', colorHex: '#E91E63');

      expect(reordered.id, original.id,
          reason: 'id must be preserved during copyWith.');
      expect(reordered.name, 'Fitness');
      expect(reordered.colorHex, '#E91E63');
      expect(reordered.iconCode, original.iconCode,
          reason: 'iconCode must be unchanged.');
    });
  });

  // TC10 ────────────────────────────────────────────────────────────────────
  group('TC10: DomainLoaded state exposes correct data', () {
    blocTest<DomainCubit, DomainState>(
      'loadDomains emits DomainLoading then DomainLoaded with full list',
      build: () {
        when(() => mockRepo.watchDomains()).thenAnswer(
          (_) => Stream.value([
            Fixtures.domain(id: 'dom-1', name: 'Health'),
            Fixtures.domain(id: 'dom-2', name: 'Career'),
          ]),
        );
        return DomainCubit(mockRepo);
      },
      act: (cubit) => cubit.loadDomains(),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<DomainLoading>(),
        isA<DomainLoaded>().having(
          (s) => (s).domains.map((d) => d.name).toList(),
          'domain names',
          containsAll(['Health', 'Career']),
        ),
      ],
    );
  });
}
