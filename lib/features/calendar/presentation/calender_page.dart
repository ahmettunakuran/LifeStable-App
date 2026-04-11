import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/constants/app_colors.dart';
import '../data/calender_repository_impl.dart';
import '../domain/entities/calendar_event_entity.dart';
import '../logic/calender_cubit.dart';
import '../logic/ocr_service.dart';
import 'event_create_edit_page.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CalendarCubit(CalendarRepositoryImpl())..init(),
      child: const _CalendarView(),
    );
  }
}

// ─── Internal stateful view ───────────────────────────────────────────────────

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView>
    with SingleTickerProviderStateMixin {
  CalendarFormat _format = CalendarFormat.month;
  late TabController _tabController;

  // 0 = Month/Week calendar, 1 = Day timeline
  int _viewIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(
            () => setState(() => _viewIndex = _tabController.index));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D0D),
              Color(0xFF1A1200),
              Color(0xFF0D0D0D),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              _buildViewTabs(),
              Expanded(
                child: BlocBuilder<CalendarCubit, CalendarState>(
                  builder: (context, state) => switch (state) {
                    CalendarLoading() => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.gold, strokeWidth: 2)),
                    CalendarLoaded() => _viewIndex == 0
                        ? _buildCalendarView(context, state)
                        : _buildDayTimeline(context, state),
                    CalendarError(:final message) => _buildError(message),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(context),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border:
                Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.gold, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.goldLight, AppColors.gold],
            ).createShader(b),
            child: const Text(
              'CALENDAR',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          _buildImportButton(context),
          const SizedBox(width: 8),
          if (_viewIndex == 0)
            _FormatToggle(
              format: _format,
              onChanged: (f) => setState(() => _format = f),
            ),
        ],
      ),
    );
  }

  // ── View tabs (Calendar ↔ Day) ─────────────────────────────────────────────

  Widget _buildViewTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.12)),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
                colors: [AppColors.goldLight, AppColors.goldDark]),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'Month / Week'),
            Tab(text: 'Day View'),
          ],
        ),
      ),
    );
  }

  // ── Calendar + event list ─────────────────────────────────────────────────

  Widget _buildCalendarView(BuildContext context, CalendarLoaded state) {
    return Column(
      children: [
        _buildCalendar(context, state),
        _buildDivider(state),
        Expanded(child: _buildEventList(context, state)),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, CalendarLoaded state) {
    final cubit = context.read<CalendarCubit>();
    return TableCalendar<CalendarEventEntity>(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2040),
      focusedDay: state.focusedDay,
      selectedDayPredicate: (d) => isSameDay(d, state.selectedDay),
      calendarFormat: _format,
      eventLoader: (day) {
        final key = DateTime(day.year, day.month, day.day);
        return state.eventMap[key] ?? [];
      },
      onDaySelected: cubit.onDaySelected,
      onPageChanged: cubit.onPageChanged,
      onFormatChanged: (f) => setState(() => _format = f),
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
        weekendTextStyle: TextStyle(
            color: AppColors.gold.withValues(alpha: 0.7), fontSize: 13),
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        todayTextStyle: const TextStyle(
            color: AppColors.gold, fontWeight: FontWeight.w700),
        selectedDecoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: [AppColors.goldLight, AppColors.goldDark]),
        ),
        selectedTextStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 13),
        markerDecoration: const BoxDecoration(
            color: AppColors.gold, shape: BoxShape.circle),
        markerSize: 5,
        markersMaxCount: 3,
        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
        cellMargin: const EdgeInsets.all(4),
      ),
      calendarBuilders: CalendarBuilders(
        // Custom marker to show conflict indicator
        markerBuilder: (ctx, day, events) {
          if (events.isEmpty) return null;
          final dayKey = DateTime(day.year, day.month, day.day);
          final dayEvents = state.eventMap[dayKey] ?? [];
          final hasConflict =
          dayEvents.any((e) => state.hasConflict(e.id));
          final hasTeam =
          dayEvents.any((e) => e.eventType == CalendarEventType.team);

          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasConflict)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle),
                  ),
                if (hasTeam)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                        color: Color(0xFFBA68C8),
                        shape: BoxShape.circle),
                  ),
                if (!hasConflict && !hasTeam)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle),
                  ),
              ],
            ),
          );
        },
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
        leftChevronIcon: Icon(Icons.chevron_left,
            color: AppColors.gold.withValues(alpha: 0.8)),
        rightChevronIcon: Icon(Icons.chevron_right,
            color: AppColors.gold.withValues(alpha: 0.8)),
        headerPadding:
        const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: const BoxDecoration(color: Colors.transparent),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w600),
        weekendStyle: TextStyle(
            color: AppColors.gold.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Divider with summary ───────────────────────────────────────────────────

  Widget _buildDivider(CalendarLoaded state) {
    final count = state.selectedEvents.length;
    final teamCount = state.selectedEvents
        .where((e) => e.eventType == CalendarEventType.team)
        .length;
    final conflictCount =
        state.selectedEvents.where((e) => state.hasConflict(e.id)).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                if (count > 0)
                  _DotBadge(
                      label: '$count event${count > 1 ? 's' : ''}',
                      color: AppColors.gold),
                if (teamCount > 0) ...[
                  const SizedBox(width: 6),
                  _DotBadge(
                      label: '$teamCount team',
                      color: const Color(0xFFBA68C8)),
                ],
                if (conflictCount > 0) ...[
                  const SizedBox(width: 6),
                  _DotBadge(
                      label: '$conflictCount conflict',
                      color: Colors.orange),
                ],
              ],
            ),
          ),
          Expanded(
              child: Divider(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  thickness: 1)),
        ],
      ),
    );
  }

  // ── Event list ─────────────────────────────────────────────────────────────

  Widget _buildEventList(BuildContext context, CalendarLoaded state) {
    final events = state.selectedEvents;
    final dayLabel =
    DateFormat('EEEE, MMMM d').format(state.selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(dayLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              )),
        ),
        Expanded(
          child: events.isEmpty
              ? _buildEmptyDay()
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
            itemCount: events.length,
            itemBuilder: (_, i) => _EventCard(
              event: events[i],
              hasConflict: state.hasConflict(events[i].id),
              onTap: () => _openEdit(context, events[i]),
              onDelete: () =>
                  context.read<CalendarCubit>().deleteEvent(events[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Day timeline view ─────────────────────────────────────────────────────

  Widget _buildDayTimeline(BuildContext context, CalendarLoaded state) {
    final events = state.selectedEvents;
    final dayLabel =
    DateFormat('EEEE, MMMM d').format(state.selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(dayLabel,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
            itemCount: 24,
            itemBuilder: (_, hour) {
              final hourEvents = events
                  .where((e) => e.startAt.hour == hour)
                  .toList();
              return _TimelineHour(
                hour: hour,
                events: hourEvents,
                conflicts: state.conflicts,
                onEventTap: (e) => _openEdit(context, e),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDay() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_available_outlined,
            size: 44,
            color: AppColors.gold.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text('No events today',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14)),
      ],
    ),
  );

  Widget _buildError(String msg) => Center(
      child: Text(msg,
          style:
          TextStyle(color: Colors.white.withValues(alpha: 0.4))));

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFab(BuildContext context) {
    return BlocBuilder<CalendarCubit, CalendarState>(
      builder: (context, state) {
        final selected =
        state is CalendarLoaded ? state.selectedDay : DateTime.now();
        return GestureDetector(
          onTap: () => _openCreate(context, selected),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                  colors: [
                    AppColors.goldLight,
                    AppColors.gold,
                    AppColors.goldDark
                  ]),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.black, size: 20),
                SizedBox(width: 8),
                Text('New Event',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
            top: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navBtn(context, Icons.group_outlined, 'Team',
                AppRoutes.teamDashboard),
            _navBtn(
                context,
                Icons.calendar_month_outlined,
                'Calendar',
                AppRoutes.calendar,
                active: true),
            _navBtn(context, Icons.dashboard_outlined, 'Dashboard',
                AppRoutes.homeDashboard),
            _navBtn(
                context,
                Icons.local_fire_department_outlined,
                'Habit',
                AppRoutes.habitTracker),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(
      BuildContext context,
      IconData icon,
      String label,
      String route, {
        bool active = false,
      }) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active
                  ? AppColors.gold
                  : AppColors.gold.withValues(alpha: 0.45),
              size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: active
                      ? AppColors.gold
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  Widget _buildImportButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImportSourceSheet(context),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
        child: const Icon(Icons.document_scanner_outlined,
            color: AppColors.gold, size: 18),
      ),
    );
  }

  void _showImportSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Import Course Schedule',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.gold),
                title: const Text('Choose from Gallery',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcessImage(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.gold),
                title: const Text('Take a Photo',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcessImage(context, ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndProcessImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    // Emülatör uyumluluğu için resmi küçültüyoruz
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (pickedFile == null) return;

    final ocrService = OcrService();
    final cubit = context.read<CalendarCubit>();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.gold)),
    );

    try {
      final events = await ocrService.processScheduleFree(userId, pickedFile);
      if (!context.mounted) return;
      Navigator.pop(context); // Yükleme animasyonunu kapat.

      if (events.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No courses found in image.')),
        );
        return;
      }

      // Kullanıcıya bulunan dersleri onayla
      _showConfirmationDialog(context, events, (confirmedEvents) async {
        await ocrService.saveScheduleEvents(confirmedEvents, userId);
        cubit.init(); // Takvimi yenile.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${confirmedEvents.length} courses added to calendar!')),
          );
        }
      });
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showConfirmationDialog(
    BuildContext context,
    List<CalendarEventEntity> events,
    Function(List<CalendarEventEntity>) onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Confirm Schedule', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(events[i].title, style: const TextStyle(color: AppColors.gold)),
              subtitle: Text(
                '${DateFormat('EEEE HH:mm').format(events[i].startAt)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm(events);
            },
            child: const Text('Add to Calendar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _openCreate(BuildContext context, DateTime day) {
    final cubit = context.read<CalendarCubit>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventCreateEditPage(
          initialDate: day,
          cubit: cubit,
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, CalendarEventEntity event) {
    final cubit = context.read<CalendarCubit>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventCreateEditPage(
          initialDate: event.startAt,
          existingEvent: event,
          cubit: cubit,
        ),
      ),
    );
  }
}

// ─── Event card ───────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.hasConflict,
    required this.onTap,
    required this.onDelete,
  });

  final CalendarEventEntity event;
  final bool hasConflict;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final startFmt = DateFormat('HH:mm').format(event.startAt);
    final endFmt = DateFormat('HH:mm').format(event.endAt);
    final typeColor = _typeColor(event.eventType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: hasConflict
                ? Colors.orange.withValues(alpha: 0.5)
                : AppColors.gold.withValues(alpha: 0.1),
            width: hasConflict ? 1.5 : 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left colour bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasConflict) ...[
                            const Icon(Icons.warning_amber_rounded,
                                size: 14, color: Colors.orange),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(event.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                          _TypeChip(type: event.eventType),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _confirmDelete(context),
                            child: Icon(Icons.delete_outline,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.25)),
                          ),
                        ],
                      ),
                      // Team name badge
                      if (event.isTeamEvent &&
                          event.teamName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.groups_outlined,
                                size: 11,
                                color: const Color(0xFFBA68C8)
                                    .withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            Text(event.teamName!,
                                style: const TextStyle(
                                    color: Color(0xFFBA68C8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            if (event.assignedMemberIds.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· ${event.assignedMemberIds.length} member${event.assignedMemberIds.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (event.description != null &&
                          event.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_outlined,
                              size: 12,
                              color:
                              Colors.white.withValues(alpha: 0.35)),
                          const SizedBox(width: 4),
                          Text('$startFmt – $endFmt',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11)),
                          if (event.hasLinkedTask) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.check_box_outlined,
                                size: 12,
                                color: AppColors.gold.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                event.linkedTaskTitle ?? 'Linked task',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.gold.withValues(alpha: 0.7),
                                    fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(CalendarEventType t) => switch (t) {
    CalendarEventType.personal => AppColors.gold,
    CalendarEventType.task => const Color(0xFF4FC3F7),
    CalendarEventType.classSchedule => const Color(0xFF81C784),
    CalendarEventType.team => const Color(0xFFBA68C8),
  };

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete event?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Remove "${event.title}"?${event.isTeamEvent ? '\n\nThis is a team event — it will be removed for everyone.' : ''}',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5)))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline hour row ────────────────────────────────────────────────────────

class _TimelineHour extends StatelessWidget {
  const _TimelineHour({
    required this.hour,
    required this.events,
    required this.conflicts,
    required this.onEventTap,
  });

  final int hour;
  final List<CalendarEventEntity> events;
  final Set<String> conflicts;
  final void Function(CalendarEventEntity) onEventTap;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('HH:00').format(DateTime(2000, 1, 1, hour));
    final isCurrentHour = DateTime.now().hour == hour;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: TextStyle(
                color: isCurrentHour
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.25),
                fontSize: 11,
                fontWeight: isCurrentHour
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 1,
                  color: isCurrentHour
                      ? AppColors.gold.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                if (events.isEmpty)
                  const SizedBox(height: 40)
                else
                  Column(
                    children: events
                        .map((e) => _TimelineEventTile(
                      event: e,
                      hasConflict: conflicts.contains(e.id),
                      onTap: () => onEventTap(e),
                    ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({
    required this.event,
    required this.hasConflict,
    required this.onTap,
  });

  final CalendarEventEntity event;
  final bool hasConflict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (event.eventType) {
      CalendarEventType.personal => AppColors.gold,
      CalendarEventType.task => const Color(0xFF4FC3F7),
      CalendarEventType.classSchedule => const Color(0xFF81C784),
      CalendarEventType.team => const Color(0xFFBA68C8),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4, right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: typeColor.withValues(alpha: 0.12),
          border: Border(
            left: BorderSide(
              color: hasConflict ? Colors.orange : typeColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${DateFormat('HH:mm').format(event.startAt)} – '
                        '${DateFormat('HH:mm').format(event.endAt)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            if (event.isTeamEvent)
              Icon(Icons.groups_outlined,
                  size: 14,
                  color: const Color(0xFFBA68C8).withValues(alpha: 0.7)),
            if (hasConflict)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────

class _DotBadge extends StatelessWidget {
  const _DotBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 6,
            height: 6,
            decoration:
            BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final CalendarEventType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      CalendarEventType.personal => ('Personal', AppColors.gold),
      CalendarEventType.task => ('Task', const Color(0xFF4FC3F7)),
      CalendarEventType.classSchedule =>
      ('Class', const Color(0xFF81C784)),
      CalendarEventType.team => ('Team', const Color(0xFFBA68C8)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({required this.format, required this.onChanged});

  final CalendarFormat format;
  final ValueChanged<CalendarFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.05),
        border:
        Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn('M', CalendarFormat.month),
          _btn('W', CalendarFormat.week),
        ],
      ),
    );
  }

  Widget _btn(String label, CalendarFormat f) {
    final active = format == f;
    return GestureDetector(
      onTap: () => onChanged(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: active
              ? const LinearGradient(
              colors: [AppColors.goldLight, AppColors.goldDark])
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
            active ? Colors.black : Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}