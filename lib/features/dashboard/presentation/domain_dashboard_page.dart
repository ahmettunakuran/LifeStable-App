import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/router/app_routes.dart';
import '../../../shared/constants/app_colors.dart';
import '../domain/entities/domain_entity.dart';
import '../logic/domain_cubit.dart';
import 'domain_kanban_view.dart';
import 'domain_edit_page.dart';

class DomainDashboardPage extends StatefulWidget {
  final int initialIndex;
  const DomainDashboardPage({super.key, this.initialIndex = 0});

  @override
  State<DomainDashboardPage> createState() => _DomainDashboardPageState();
}

class _DomainDashboardPageState extends State<DomainDashboardPage> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: _currentPage);
    context.read<DomainCubit>().loadDomains();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DomainCubit, DomainState>(
      builder: (context, state) {
        if (state is DomainLoading) {
          return const Scaffold(
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
          final totalPages = domains.length + 1;

          // If initialIndex is out of bounds, reset (e.g. after a deletion)
          if (_currentPage >= totalPages) {
            _currentPage = 0;
            _pageController = PageController(initialPage: 0);
          }

          return Scaffold(
            backgroundColor: AppColors.black,
            appBar: _buildAppBar(domains),
            body: Container(
              decoration: const BoxDecoration(
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
        return const Scaffold(backgroundColor: AppColors.black);
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
        icon: const Icon(Icons.arrow_back, color: AppColors.gold),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentPage > 0)
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 28, color: AppColors.gold),
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
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
          ),
          if (_currentPage < domains.length)
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 28, color: AppColors.gold),
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
            _navBtn(Icons.group_outlined, 'Team', AppRoutes.teamDashboard),
            _navBtn(Icons.calendar_month_outlined, 'Calendar', AppRoutes.calendar),
            _navBtn(Icons.dashboard_outlined, 'Dashboard', AppRoutes.homeDashboard),
            _navBtn(Icons.local_fire_department_outlined, 'Habit', AppRoutes.habitTracker),
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