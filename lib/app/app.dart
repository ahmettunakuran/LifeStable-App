import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/tasks/presentation/bloc/tasks_bloc.dart';
import '../features/tasks/presentation/bloc/tasks_event.dart';
import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

class LifeStableApp extends StatelessWidget {
  const LifeStableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TasksBloc()..add(LoadTasks()),
      child: MaterialApp(
        title: 'LifeStable',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
