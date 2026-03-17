import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/domain_entity.dart';
import '../domain/repositories/domain_repository.dart';

abstract class DomainState {}

class DomainInitial extends DomainState {}
class DomainLoading extends DomainState {}
class DomainLoaded extends DomainState {
  DomainLoaded(this.domains);
  final List<DomainEntity> domains;
}
class DomainError extends DomainState {
  DomainError(this.message);
  final String message;
}

class DomainCubit extends Cubit<DomainState> {
  DomainCubit(this._repository) : super(DomainInitial());

  final DomainRepository _repository;
  StreamSubscription? _subscription;

  void loadDomains() {
    emit(DomainLoading());
    _subscription?.cancel();
    _subscription = _repository.watchDomains().listen(
      (domains) => emit(DomainLoaded(domains)),
      onError: (e) => emit(DomainError(e.toString())),
    );
  }

  Future<void> addDomain(DomainEntity domain) async {
    try {
      await _repository.createOrUpdateDomain(domain);
    } catch (e) {
      emit(DomainError(e.toString()));
    }
  }

  Future<void> updateDomain(DomainEntity domain) async {
    try {
      await _repository.createOrUpdateDomain(domain);
    } catch (e) {
      emit(DomainError(e.toString()));
    }
  }

  Future<void> deleteDomain(String id) async {
    try {
      await _repository.deleteDomain(id);
    } catch (e) {
      emit(DomainError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
