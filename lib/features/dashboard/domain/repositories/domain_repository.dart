import '../entities/domain_entity.dart';

abstract class DomainRepository {
  Future<List<DomainEntity>> fetchDomains();
  Future<void> createOrUpdateDomain(DomainEntity domain);
  Future<void> deleteDomain(String domainId);
  Stream<List<DomainEntity>> watchDomains();
}
