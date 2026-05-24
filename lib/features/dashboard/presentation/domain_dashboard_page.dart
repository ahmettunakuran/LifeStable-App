import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/constants/app_colors.dart';
import '../domain/entities/domain_entity.dart';
import '../logic/domain_cubit.dart';
import 'domain_kanban_view.dart';
import 'domain_edit_page.dart';

class DomainDashboardPage extends StatefulWidget {
  final int initialIndex;
  final String? targetDomainId;
  const DomainDashboardPage({super.key, this.initialIndex = 0, this.targetDomainId});

  @override
  State<DomainDashboardPage> createState() => _DomainDashboardPageState();
}

class _DomainDashboardPageState extends State<DomainDashboardPage> {
  late PageController _pageController;
  late int _currentPage;
  int _lastDomainCount = 0;
  bool _navigatedToTarget = false;

  @override
  void initState() {
    super.initState();
    // If a targetDomainId is provided, try to resolve it to a page index
    // from the already-loaded DomainCubit state so we can set the PageController
    // initial page directly — avoiding a visible jump after the first frame.
    int startPage = widget.initialIndex;
    if (widget.targetDomainId != null) {
      final currentState = context.read<DomainCubit>().state;
      if (currentState is DomainLoaded) {
        final idx = currentState.domains
            .indexWhere((d) => d.id == widget.targetDomainId);
        if (idx >= 0) {
          startPage = idx;
          _navigatedToTarget = true;
        }
      }
    }
    _currentPage = startPage;
    _pageController = PageController(initialPage: startPage);
    // Only call loadDomains if not already loaded — avoids the DomainLoading
    // flash that makes the kanban view disappear briefly.
    final cubit = context.read<DomainCubit>();
    if (cubit.state is! DomainLoaded) {
      cubit.loadDomains();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _maybeNavigateToTarget(List<DomainEntity> domains) {
    if (_navigatedToTarget || widget.targetDomainId == null) return;
    final idx = domains.indexWhere((d) => d.id == widget.targetDomainId);
    if (idx < 0) return;
    _navigatedToTarget = true;
    _currentPage = idx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(idx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return BlocBuilder<DomainCubit, DomainState>(
          builder: (context, state) {
            if (state is DomainLoading) {
              return Scaffold(
                backgroundColor: AppColors.black,
                body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
              );
            } else if (state is DomainError) {
              return Scaffold(
                backgroundColor: AppColors.black,
                appBar: _buildAppBar(const []),
                body: Center(child: Text('${S.of('generic_error')}: ${state.message}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5)))),
              );
            } else if (state is DomainLoaded) {
              final domains = state.domains;
              final totalPages = domains.length + 1;
    return BlocBuilder<DomainCubit, DomainState>(
      builder: (context, state) {
        if (state is DomainLoading) {
          return Scaffold(
            backgroundColor: AppColors.black,
            body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
          );
        } else if (state is DomainError) {
          return Scaffold(
            backgroundColor: AppColors.black,
            appBar: _buildAppBar(const []),
            body: Center(child: Text('Error: ${state.message}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5)))),
          );
        } else if (state is DomainLoaded) {
          final domains = state.domains;
          _maybeNavigateToTarget(domains);
          final totalPages = domains.length + 1;

              // Keep the viewed page valid when the domain list changes
              // (e.g. after a domain is deleted).
              final domainsShrank = domains.length < _lastDomainCount;
              _lastDomainCount = domains.length;

              var desired = _currentPage;
              if (desired >= totalPages) desired = totalPages - 1;
              if (desired < 0) desired = 0;
              // If the viewed domain was just deleted, land on the last
              // remaining domain rather than the trailing "+ New" page.
              if (domainsShrank && domains.isNotEmpty && desired >= domains.length) {
                desired = domains.length - 1;
              }
              if (desired != _currentPage) {
                _currentPage = desired;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pageController.hasClients) {
                    _pageController.jumpToPage(desired);
                  }
                });
              }

              return Scaffold(
                backgroundColor: AppColors.black,
                appBar: _buildAppBar(domains),
                body: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)],
                    ),
                  ),
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: totalPages,
                    itemBuilder: (context, index) {
                      if (index < domains.length) {
                        return DomainKanbanView(domain: domains[index]);
                      } else {
                        return const DomainEditPage();
                      }
                    },
                  ),
                ),
                floatingActionButton: _currentPage < domains.length
                    ? _buildFab(domains[_currentPage])
                    : null,
                bottomNavigationBar: _buildBottomNav(context),
              );
            }
            return Scaffold(backgroundColor: AppColors.black);
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(List<DomainEntity> domains) {
    final isLastPage = _currentPage >= domains.length;
    final currentDomain = isLastPage ? null : domains[_currentPage];
    final title = isLastPage ? 'NEW DOMAIN' : currentDomain!.name.toUpperCase();

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.gold),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentPage > 0)
            IconButton(
              icon: Icon(Icons.chevron_left, size: 28, color: AppColors.gold),
              onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            )
          else
            const SizedBox(width: 48),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentDomain != null && currentDomain.isTeamMirror)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.group, size: 16, color: AppColors.gold.withValues(alpha: 0.7)),
                  ),
                Flexible(
                  child: Text(title, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
          ),
          if (_currentPage < domains.length)
            IconButton(
              icon: Icon(Icons.chevron_right, size: 28, color: AppColors.gold),
              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
      centerTitle: true,
      actions: [
        if (currentDomain != null && !currentDomain.isTeamMirror)
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppColors.gold.withValues(alpha: 0.7)),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.domainEdit, arguments: currentDomain),
          ),
        if (currentDomain != null && currentDomain.isTeamMirror)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(message: 'Synced from team', child: Icon(Icons.sync, size: 18, color: AppColors.gold.withValues(alpha: 0.5))),
          ),
      ],
    );
  }

  Widget _buildFab(DomainEntity domain) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.taskEdit, arguments: {'domainId': domain.id}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark]),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.black, size: 20),
            SizedBox(width: 8),
            Text('Add Task', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navBtn(Icons.group_outlined, S.of('nav_team'), AppRoutes.teamDashboard),
            _navBtn(Icons.calendar_month_outlined, S.of('nav_calendar'), AppRoutes.calendar),
            _navBtn(Icons.dashboard_outlined, S.of('nav_dashboard'), AppRoutes.homeDashboard),
            _navBtn(Icons.local_fire_department_outlined, S.of('nav_habit'), AppRoutes.habitTracker),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold.withValues(alpha: 0.6), size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}