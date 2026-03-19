import 'package:flutter/material.dart';

import '../../features/alerts/presentation/alerts_page.dart';
import '../../features/assistant/presentation/assistant_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/dashboard/domain/entities/domain_entity.dart';
import '../../features/dashboard/presentation/home_dashboard_page.dart';
import '../../features/dashboard/presentation/domain_dashboard_page.dart';
import '../../features/dashboard/presentation/domain_edit_page.dart';
import '../../features/habits/presentation/habit_tracker_page.dart';
import '../../features/map/presentation/map_page.dart';
import '../../features/notes/presentation/notes_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/tasks/presentation/task_detail_page.dart';
import '../../features/tasks/presentation/task_edit_page.dart';
import '../../features/tasks/presentation/tasks_kanban_page.dart';
import '../../features/teams/presentation/team_dashboard_page.dart';
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
        return _buildRoute(const DomainDashboardPage(), settings);
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
      case AppRoutes.alerts:
        return _buildRoute(const AlertsPage(), settings);
      case AppRoutes.map:
        return _buildRoute(const MapPage(), settings);
      case AppRoutes.calendar:
        return _buildRoute(const CalendarPage(), settings);
      case AppRoutes.aiAssistant:
        return _buildRoute(const AssistantPage(), settings);
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
