import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/dashboard/data/repositories/domain_repository_impl.dart';
import '../features/dashboard/domain/repositories/domain_repository.dart';
import '../features/dashboard/logic/domain_cubit.dart';
import '../features/tasks/data/task_repository_impl.dart';
import '../features/tasks/domain/repositories/task_repository.dart';
import '../features/tasks/presentation/bloc/tasks_bloc.dart';
import '../features/tasks/presentation/bloc/tasks_event.dart';
import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

class LifeStableApp extends StatelessWidget {
  const LifeStableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DomainRepository>(
          create: (context) => DomainRepositoryImpl(
            FirebaseFirestore.instance,
            FirebaseAuth.instance,
          ),
        ),
        RepositoryProvider<TaskRepository>(
          create: (context) => TaskRepositoryImpl(
            FirebaseFirestore.instance,
            FirebaseAuth.instance,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => TasksBloc(
              context.read<TaskRepository>(),
            )..add(LoadTasks()),
          ),
          BlocProvider(
            create: (context) => DomainCubit(
              context.read<DomainRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'LifeStable',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
  }
}
