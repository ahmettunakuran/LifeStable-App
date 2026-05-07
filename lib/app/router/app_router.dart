import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/alerts/domain/repositories/location_repository.dart';
import '../../features/alerts/logic/location_cubit.dart';
import '../../features/alerts/presentation/alerts_page.dart';
import '../../features/alerts/presentation/battery_report_screen.dart';
import '../../features/alerts/presentation/geofence_debug_screen.dart';
import '../../features/alerts/presentation/map_screen.dart';
import '../../features/assistant/presentation/assistant_page.dart';
import '../../features/app_assistant/presentation/app_assistant_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/calendar/presentation/calender_page.dart';
import '../../features/dashboard/domain/entities/domain_entity.dart';
import '../../features/dashboard/presentation/home_dashboard_page.dart';
import '../../features/dashboard/presentation/domain_dashboard_page.dart';
import '../../features/dashboard/presentation/domain_edit_page.dart';
import '../../features/habits/presentation/habit_tracker_page.dart';
import '../../features/notes/presentation/notes_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/tasks/presentation/task_detail_page.dart';
import '../../features/tasks/presentation/task_edit_page.dart';
import '../../features/tasks/presentation/tasks_kanban_page.dart';
import '../../features/teams/presentation/team_dashboard_page.dart';
import '../../features/teams/presentation/join_team_screen.dart';
import '../../features/teams/presentation/team_detail_screen.dart';
import 'app_routes.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _buildRoute(const SplashPage(), settings);
      case AppRoutes.onboarding:
        return _buildRoute(const OnboardingPage(), settings);
      case AppRoutes.login:
        return _buildRoute(const LoginPage(), settings);
      case AppRoutes.register:
        return _buildRoute(const RegisterPage(), settings);
      case AppRoutes.forgotPassword:
        return _buildRoute(const ForgotPasswordPage(), settings);
      case AppRoutes.homeDashboard:
        return _buildRoute(const HomeDashboardPage(), settings);
      case AppRoutes.domainDashboard:
        final initialIndex = settings.arguments as int? ?? 0;
        return _buildRoute(DomainDashboardPage(initialIndex: initialIndex), settings);
      case AppRoutes.domainEdit:
        final domain = settings.arguments as DomainEntity?;
        return _buildRoute(DomainEditPage(domain: domain), settings);
      case AppRoutes.tasksKanban:
        return _buildRoute(const TasksKanbanPage(), settings);
      case AppRoutes.taskDetails:
        return _buildRoute(const TaskDetailPage(), settings);
      case AppRoutes.taskEdit:
        return _buildRoute(const TaskEditPage(), settings);
      case AppRoutes.notes:
        return _buildRoute(const NotesPage(), settings);
      case AppRoutes.habitTracker:
        return _buildRoute(const HabitTrackerPage(), settings);
      case AppRoutes.teamDashboard:
        return _buildRoute(const TeamDashboardPage(), settings);
      case AppRoutes.teamJoin:
        return _buildRoute(const JoinTeamScreen(), settings);
      case AppRoutes.teamDetail:
        final args = settings.arguments as Map<String, String>;
        return _buildRoute(
          TeamDetailScreen(
            teamId: args['teamId']!,
            teamName: args['teamName']!,
          ),
          settings,
        );
      case AppRoutes.alerts:
        return _buildRoute(const AlertsPage(), settings);
      case AppRoutes.map:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => BlocProvider(
            create: (_) => LocationCubit(context.read<LocationRepository>()),
            child: const MapScreen(),
          ),
        );
      case AppRoutes.geofenceDebug:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => BlocProvider(
            create: (_) => LocationCubit(context.read<LocationRepository>()),
            child: const GeofenceDebugScreen(),
          ),
        );
      case AppRoutes.batteryReport:
        return _buildRoute(const BatteryReportScreen(), settings);
      case AppRoutes.calendar:
        return _buildRoute(const CalendarPage(), settings);
      case AppRoutes.aiAssistant:
        return _buildRoute(const AssistantPage(), settings);
      case AppRoutes.appAssistant:
        return _buildRoute(const AppAssistantPage(), settings);
      case AppRoutes.settings:
        return _buildRoute(const SettingsPage(), settings);
      default:
        return _buildRoute(const SplashPage(), settings);
    }
  }

  static MaterialPageRoute<T> _buildRoute<T>(
      Widget child,
      RouteSettings settings,
      ) {
    return MaterialPageRoute<T>(
      builder: (_) => child,
      settings: settings,
    );
  }
}
