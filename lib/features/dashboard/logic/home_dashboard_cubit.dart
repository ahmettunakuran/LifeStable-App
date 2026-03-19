import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logger/app_logger.dart';

sealed class HomeDashboardState {
  const HomeDashboardState();
}

class HomeDashboardInitial extends HomeDashboardState {
  const HomeDashboardInitial();
}

class HomeDashboardLoading extends HomeDashboardState {
  const HomeDashboardLoading();
}

class HomeDashboardLoaded extends HomeDashboardState {
  const HomeDashboardLoaded(this.summary);

  final String summary;
}

class HomeDashboardCubit extends Cubit<HomeDashboardState> {
  HomeDashboardCubit() : super(const HomeDashboardInitial());

  Future<void> loadOverview() async {
    emit(const HomeDashboardLoading());
    await Future.delayed(const Duration(milliseconds: 400));
    const summary =
        'Today: example tasks, habits, and calendar events will appear here.';
    AppLogger.debug('Home overview loaded');
    emit(const HomeDashboardLoaded(summary));
  }
}

