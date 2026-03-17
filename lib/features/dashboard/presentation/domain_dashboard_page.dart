import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/router/app_routes.dart';
import '../domain/entities/domain_entity.dart';
import '../logic/domain_cubit.dart';
import 'domain_kanban_view.dart';
import 'domain_edit_page.dart';

class DomainDashboardPage extends StatefulWidget {
  const DomainDashboardPage({super.key});

  @override
  State<DomainDashboardPage> createState() => _DomainDashboardPageState();
}

class _DomainDashboardPageState extends State<DomainDashboardPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
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
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (state is DomainError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${state.message}')),
          );
        } else if (state is DomainLoaded) {
          final domains = state.domains;
          final totalPages = domains.length + 1; // +1 for the "Add New Domain" page at the end

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: _buildAppBarTitle(domains),
              centerTitle: true,
              actions: [
                if (_currentPage < domains.length)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.domainEdit,
                      arguments: domains[_currentPage],
                    ),
                  ),
              ],
            ),
            body: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: totalPages,
              itemBuilder: (context, index) {
                if (index < domains.length) {
                  return DomainKanbanView(domain: domains[index]);
                } else {
                  return const DomainEditPage(); // Always show Add Domain page at the end
                }
              },
            ),
            floatingActionButton: _currentPage < domains.length
                ? FloatingActionButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.taskEdit,
                      arguments: {'domainId': domains[_currentPage].id},
                    ),
                    backgroundColor: const Color(0xFFD4AF37),
                    child: const Icon(Icons.add, color: Colors.white),
                  )
                : null,
            bottomNavigationBar: _buildBottomNav(context),
          );
        }
        return const Scaffold();
      },
    );
  }

  Widget _buildAppBarTitle(List<DomainEntity> domains) {
    final isLastPage = _currentPage == domains.length;
    final title = isLastPage ? 'NEW DOMAIN' : domains[_currentPage].name.toUpperCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left Arrow (only if not on the first page)
        if (_currentPage > 0)
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          )
        else
          const SizedBox(width: 48),

        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),

        // Right Arrow (only if not on the last page)
        if (_currentPage < domains.length)
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavButton(label: 'Team', icon: Icons.group_outlined, route: AppRoutes.teamDashboard),
          _NavButton(label: 'Calendar', icon: Icons.calendar_month_outlined, route: AppRoutes.calendar),
          _NavButton(label: 'Dashboard', icon: Icons.dashboard_outlined, route: AppRoutes.homeDashboard),
          _NavButton(label: 'Habit', icon: Icons.refresh_outlined, route: AppRoutes.habitTracker),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: () => Navigator.pushReplacementNamed(context, route),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
